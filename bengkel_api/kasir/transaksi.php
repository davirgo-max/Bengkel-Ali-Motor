<?php
// kasir/transaksi.php
// GET               → riwayat transaksi hari ini
// GET ?id=X         → detail transaksi + nota
// POST              → proses pembayaran baru

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../middleware/auth.php';
require_once __DIR__ . '/../config/fcm_helper.php';

setCORSHeaders();
$auth    = requireRole('kasir', 'owner');
$kasirId = $auth['user_id'];
$db      = getDB();

// ── POST: upload bukti transfer ───────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_GET['upload_bukti'])) {
    $transaksiId = (int)($_POST['transaksi_id'] ?? 0);
    if ($transaksiId <= 0) responseError('transaksi_id tidak valid');
    if (empty($_FILES['bukti_bayar'])) responseError('File bukti tidak ditemukan');

    $file     = $_FILES['bukti_bayar'];
    $ext      = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
    $allowed  = ['jpg', 'jpeg', 'png', 'webp'];
    if (!in_array($ext, $allowed)) responseError('Format file tidak didukung');
    if ($file['size'] > 5 * 1024 * 1024) responseError('Ukuran file maksimal 5MB');

    $uploadDir = __DIR__ . '/../uploads/bukti_bayar/';
    if (!is_dir($uploadDir)) mkdir($uploadDir, 0755, true);

    $filename  = 'bukti_' . $transaksiId . '_' . time() . '.' . $ext;
    $destPath  = $uploadDir . $filename;

    if (!move_uploaded_file($file['tmp_name'], $destPath))
        responseError('Gagal menyimpan file', 500);

    // Simpan path ke DB (kolom bukti_bayar di tabel transaksi)
    $stmt = $db->prepare("UPDATE transaksi SET bukti_bayar = ? WHERE id = ?");
    $stmt->bind_param('si', $filename, $transaksiId);
    $stmt->execute(); $stmt->close();
    $db->close();

    responseOk('Bukti pembayaran berhasil diunggah', ['filename' => $filename]);
}

// ── GET ───────────────────────────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'GET') {

    // Detail 1 transaksi berdasarkan servis_id (untuk tombol "Lihat Nota" dari detail servis)
    if (isset($_GET['servis_id'])) {
        try {
            $servisId = (int)$_GET['servis_id'];
            $stmt = $db->prepare("SELECT id, no_nota, metode_bayar, grand_total, jumlah_bayar, kembalian FROM transaksi WHERE servis_id = ? LIMIT 1");
            $stmt->bind_param('i', $servisId);
            $stmt->execute();
            $row = $stmt->get_result()->fetch_assoc();
            $stmt->close();
            if (!$row) responseError('Transaksi tidak ditemukan untuk servis ini', 404);
            responseOk('OK', $row);
        } catch (Throwable $e) {
            responseError('Gagal memuat transaksi: ' . $e->getMessage(), 500);
        }
    }

    // Detail 1 transaksi (untuk cetak nota)
    if (isset($_GET['id'])) {
        // Dibungkus try/catch: kalau ada error SQL apa pun di sini, PHP 8.1+
        // akan melempar mysqli_sql_exception yang -- kalau tidak ditangkap --
        // menghasilkan fatal error tercampur ke output JSON (persis pola bug
        // "FormatException" yang pernah terjadi di booking.php / Masalah 1).
        // Dengan try/catch, response tetap JSON valid dan pesan error asli
        // ikut terkirim supaya gampang didiagnosis dari Flutter.
        try {
            $id   = (int)$_GET['id'];
            $stmt = $db->prepare("
                SELECT t.*,
                       u.nama AS nama_kasir,
                       p.nama AS nama_pelanggan, p.no_hp,
                       s.id   AS servis_id, s.diagnosa, s.waktu_mulai, s.waktu_selesai,
                       b.no_booking, b.tanggal_servis,
                       k.merk, k.model, k.no_polisi,
                       js.nama AS jenis_servis,
                       m.nama AS nama_mekanik
                FROM transaksi t
                LEFT JOIN users u     ON u.id = t.kasir_id
                LEFT JOIN pelanggan p ON p.id = t.pelanggan_id
                LEFT JOIN servis s    ON s.id = t.servis_id
                LEFT JOIN booking b   ON b.id = s.booking_id
                LEFT JOIN kendaraan k ON k.id = b.kendaraan_id
                LEFT JOIN jenis_servis js ON js.id = b.jenis_servis_id
                LEFT JOIN mekanik m   ON m.id = s.mekanik_id
                WHERE t.id = ? LIMIT 1
            ");
            $stmt->bind_param('i', $id);
            $stmt->execute();
            $trx = $stmt->get_result()->fetch_assoc();
            $stmt->close();
            if (!$trx) responseError('Transaksi tidak ditemukan', 404);

            // Ambil detail item sparepart jika ada
            $items = [];
            if ($trx['servis_id']) {
                $stmt = $db->prepare("
                    SELECT ss.jumlah, ss.harga_jual, ss.subtotal, sp.nama, sp.satuan
                    FROM servis_sparepart ss
                    JOIN sparepart sp ON sp.id = ss.sparepart_id
                    WHERE ss.servis_id = ?
                ");
                $stmt->bind_param('i', $trx['servis_id']);
                $stmt->execute();
                // PENTING: get_result() hanya boleh dipanggil SEKALI setelah execute().
                // Memanggilnya lagi di setiap iterasi while (seperti sebelumnya) membuat
                // driver mysqli kehilangan sinkronisasi dengan hasil query sebelumnya,
                // sehingga query berikutnya gagal dengan error
                // "Commands out of sync; you can't run this command now".
                $result = $stmt->get_result();
                while ($r = $result->fetch_assoc()) $items[] = $r;
                $stmt->close();
            } else {
                $stmt = $db->prepare("
                    SELECT tsl.jumlah, tsl.harga_jual, tsl.subtotal, sp.nama, sp.satuan
                    FROM transaksi_sparepart_langsung tsl
                    JOIN sparepart sp ON sp.id = tsl.sparepart_id
                    WHERE tsl.transaksi_id = ?
                ");
                $stmt->bind_param('i', $id);
                $stmt->execute();
                $result = $stmt->get_result();
                while ($r = $result->fetch_assoc()) $items[] = $r;
                $stmt->close();
            }

            // Ambil info bengkel untuk nota (guard: jangan panggil fetch_assoc()
            // di atas hasil query yang gagal / false, itu memicu fatal error)
            $bengkelResult = $db->query("SELECT * FROM pengaturan_bengkel WHERE id=1 LIMIT 1");
            $bengkel = $bengkelResult ? ($bengkelResult->fetch_assoc() ?: []) : [];

            responseOk('OK', [
                'transaksi' => $trx,
                'items'     => $items,
                'bengkel'   => $bengkel,
            ]);
        } catch (Throwable $e) {
            responseError('Gagal memuat detail nota: ' . $e->getMessage(), 500);
        }
    }

    // Riwayat transaksi per tanggal
    $tanggal = $_GET['tanggal'] ?? date('Y-m-d');
    $stmt = $db->prepare("
        SELECT t.id, t.no_nota, t.tipe, t.total_jasa,
               t.total_sparepart, t.diskon, t.grand_total,
               t.metode_bayar, t.status, t.tanggal,
               u.nama AS nama_kasir,
               p.nama AS nama_pelanggan,
               b.no_booking, k.merk, k.model, k.no_polisi
        FROM transaksi t
        JOIN users u          ON u.id = t.kasir_id
        LEFT JOIN pelanggan p ON p.id = t.pelanggan_id
        LEFT JOIN servis s    ON s.id = t.servis_id
        LEFT JOIN booking b   ON b.id = s.booking_id
        LEFT JOIN kendaraan k ON k.id = b.kendaraan_id
        WHERE DATE(t.tanggal) = ?
        ORDER BY t.tanggal DESC
    ");
    if (!$stmt) {
        responseError('Query error: ' . $db->error, 500);
    }
    $stmt->bind_param('s', $tanggal);
    $stmt->execute();
    $result = $stmt->get_result();   // ← simpan result sekali
    $rows = [];
    while ($r = $result->fetch_assoc()) $rows[] = $r;
    $result->free();                 // ← free result
    $stmt->close();

    // Rekap total hari ini
    $stmt = $db->prepare("
        SELECT
            COALESCE(SUM(grand_total), 0)                                          AS total,
            COALESCE(SUM(CASE WHEN metode_bayar='cash'     THEN grand_total END), 0) AS cash,
            COALESCE(SUM(CASE WHEN metode_bayar='transfer' THEN grand_total END), 0) AS transfer,
            COUNT(*) AS jumlah
        FROM transaksi WHERE DATE(tanggal) = ?
    ");
    $stmt->bind_param('s', $tanggal);
    $stmt->execute();
    $rekap = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    responseOk('OK', [
        'transaksi' => $rows,
        'rekap'     => $rekap,
        'tanggal'   => $tanggal,
    ]);
}

// ── POST: proses pembayaran ───────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $body        = getRequestBody();
    $servisId    = !empty($body['servis_id'])    ? (int)$body['servis_id']    : null;
    $pelangganId = !empty($body['pelanggan_id']) ? (int)$body['pelanggan_id'] : null;
    $tipe        = trim($body['tipe']            ?? 'servis');
    $metodeBayar = trim($body['metode_bayar']    ?? 'cash');
    $jumlahBayar = (float)($body['jumlah_bayar'] ?? 0);
    $diskon      = (float)($body['diskon']        ?? 0);

    if (!in_array($metodeBayar, ['cash','transfer']))
        responseError('Metode bayar tidak valid');

    // Kas harian tidak lagi digunakan — validasi dihapus

    // ── TAMBAHKAN INI: cek servis sudah dibayar ──────────────
    if ($servisId) {
        $cekStmt = $db->prepare("SELECT id FROM transaksi WHERE servis_id = ? LIMIT 1");
        $cekStmt->bind_param('i', $servisId);
        $cekStmt->execute();
        $cekStmt->store_result();
        if ($cekStmt->num_rows > 0) {
            $cekStmt->close();
            responseError('Servis ini sudah pernah dibayar sebelumnya.', 400);
        }
        $cekStmt->close();
    }

    // ── Hitung total dari servis ─────────────────────────
    $totalJasa      = 0.0;
    $totalSparepart = 0.0;

    if ($servisId) {
        // Ambil harga jasa dari jenis servis
        $stmt = $db->prepare("
            SELECT js.harga_jasa
            FROM servis s
            JOIN booking b    ON b.id = s.booking_id
            LEFT JOIN jenis_servis js ON js.id = b.jenis_servis_id
            WHERE s.id = ? LIMIT 1
        ");
        $stmt->bind_param('i', $servisId);
        $stmt->execute();
        $row = $stmt->get_result()->fetch_assoc();
        $stmt->close();
        $totalJasa = (float)($row['harga_jasa'] ?? 0);

        // Total sparepart
        $stmt = $db->prepare("
            SELECT COALESCE(SUM(subtotal), 0) AS total
            FROM servis_sparepart
            WHERE servis_id = ? AND status_persetujuan = 'disetujui'
        ");
        $stmt->bind_param('i', $servisId);
        $stmt->execute();
        $totalSparepart = (float)$stmt->get_result()->fetch_assoc()['total'];
        $stmt->close();

        // Ambil pelanggan_id dari servis
        if (!$pelangganId) {
            $stmt = $db->prepare("
                SELECT b.pelanggan_id FROM servis s
                JOIN booking b ON b.id = s.booking_id
                WHERE s.id = ? LIMIT 1
            ");
            $stmt->bind_param('i', $servisId);
            $stmt->execute();
            $pelangganId = (int)$stmt->get_result()->fetch_assoc()['pelanggan_id'];
            $stmt->close();
        }
    }

    // Override jika dikirim manual (penjualan sparepart langsung)
    if (!empty($body['total_jasa']))      $totalJasa      = (float)$body['total_jasa'];
    if (!empty($body['total_sparepart'])) $totalSparepart = (float)$body['total_sparepart'];

    $grandTotal = $totalJasa + $totalSparepart - $diskon;
    $kembalian  = max(0, $jumlahBayar - $grandTotal);

    if ($metodeBayar === 'cash' && $jumlahBayar < $grandTotal) {
        responseError('Jumlah bayar kurang dari total tagihan');
    }

    // Generate no_nota: NT-YYYYMMDD-XXX
    $count    = $db->query("SELECT COUNT(*) AS c FROM transaksi WHERE DATE(tanggal)=CURDATE()")
                   ->fetch_assoc()['c'] + 1;
    $noNota   = 'NT-' . date('Ymd') . '-' . str_pad($count, 3, '0', STR_PAD_LEFT);

    // Simpan transaksi
    $stmt = $db->prepare("
        INSERT INTO transaksi
          (no_nota, servis_id, kasir_id, pelanggan_id, tipe,
           total_jasa, total_sparepart, diskon, grand_total,
           metode_bayar, jumlah_bayar, kembalian, status, tanggal)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'lunas', NOW())
    ");
    $stmt->bind_param('siiisddddsdd',
        $noNota, $servisId, $kasirId, $pelangganId, $tipe,
        $totalJasa, $totalSparepart, $diskon, $grandTotal,
        $metodeBayar, $jumlahBayar, $kembalian
    );
    if (!$stmt->execute()) responseError('Gagal menyimpan transaksi', 500);
    $trxId = $stmt->insert_id;
    $stmt->close();

    // Update status servis → selesai
    if ($servisId) {
        $stmt = $db->prepare("UPDATE servis SET status='selesai' WHERE id=?");
        $stmt->bind_param('i', $servisId);
        $stmt->execute(); $stmt->close();

        // Update status booking → selesai
        $stmt = $db->prepare("
            UPDATE booking SET status='selesai'
            WHERE id=(SELECT booking_id FROM servis WHERE id=?)
        ");
        $stmt->bind_param('i', $servisId);
        $stmt->execute(); $stmt->close();
    }

    // Kas harian tidak lagi digunakan — update kas dihapus

    // ── Notifikasi FCM: pembayaran berhasil ───────────────
    if ($pelangganId && $servisId) {
        // Ambil no_booking untuk isi pesan
        $stmtD = $db->prepare("
            SELECT b.no_booking, k.merk, k.model, k.no_polisi
            FROM   servis s
            JOIN   booking b   ON b.id = s.booking_id
            JOIN   kendaraan k ON k.id = b.kendaraan_id
            WHERE  s.id = ?
            LIMIT  1
        ");
        $stmtD->bind_param('i', $servisId);
        $stmtD->execute();
        $tDetail = $stmtD->get_result()->fetch_assoc();
        $stmtD->close();

        if ($tDetail) {
            $grandTotalFmt = 'Rp ' . number_format($grandTotal, 0, ',', '.');
            $kendaraan     = "{$tDetail['merk']} {$tDetail['model']} ({$tDetail['no_polisi']})";
            // Ambil booking_id untuk FK notifikasi
            $stmtB = $db->prepare("SELECT booking_id FROM servis WHERE id=? LIMIT 1");
            $stmtB->bind_param('i', $servisId);
            $stmtB->execute();
            $bRow = $stmtB->get_result()->fetch_assoc();
            $stmtB->close();
            $bId = $bRow ? (int)$bRow['booking_id'] : null;

            kirimNotifikasi(
                $db,
                $pelangganId,
                'servis_selesai',
                'Pembayaran Berhasil 💳',
                "Pembayaran servis kendaraan $kendaraan sebesar $grandTotalFmt ({$metodeBayar}) berhasil. Terima kasih telah mempercayakan kendaraan Anda!",
                $bId,
                $servisId
            );
        }
    }
    // ─────────────────────────────────────────────────────

    $db->close();

    responseOk('Pembayaran berhasil', [
        'transaksi_id' => $trxId,
        'no_nota'      => $noNota,
        'grand_total'  => $grandTotal,
        'kembalian'    => $kembalian,
        'metode_bayar' => $metodeBayar,
    ]);
}

responseError('Method tidak diizinkan', 405);