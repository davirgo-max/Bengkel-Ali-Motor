<?php
// kasir/servis.php
// GET              → list servis aktif
// GET ?id=X        → detail servis lengkap + sparepart + mekanik list
// PUT ?id=X        → update info / status / selesai diagnosa
// POST             → tambah sparepart ke servis
// DELETE ?part_id=X→ hapus sparepart dari servis

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../middleware/auth.php';
require_once __DIR__ . '/../config/fcm_helper.php';

setCORSHeaders();
$auth    = requireRole('kasir', 'owner');
$kasirId = $auth['user_id'];
$db      = getDB();

// ── GET ───────────────────────────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'GET') {

    // Detail servis
    if (isset($_GET['id'])) {
        $id   = (int)$_GET['id'];
        $stmt = $db->prepare("
            SELECT s.id, s.diagnosa, s.catatan_mekanik, s.catatan_pelanggan,
                   s.status, s.waktu_mulai, s.waktu_diagnosa, s.waktu_selesai,
                   s.kasir_id,
                   b.id AS booking_id, b.no_booking, b.tanggal_servis,
                   b.keluhan, b.tipe,
                   p.id AS pelanggan_id, p.nama AS nama_pelanggan, p.no_hp,
                   k.merk, k.model, k.no_polisi, k.warna, k.tahun,
                   js.id AS jenis_servis_id, js.nama AS jenis_servis,
                   js.harga_jasa,
                   sw.label AS slot_label,
                   m.id AS mekanik_id, m.nama AS nama_mekanik,
                   u.nama AS nama_kasir
            FROM servis s
            JOIN booking b    ON b.id = s.booking_id
            JOIN pelanggan p  ON p.id = b.pelanggan_id
            JOIN kendaraan k  ON k.id = b.kendaraan_id
            LEFT JOIN jenis_servis js ON js.id = b.jenis_servis_id
            LEFT JOIN slot_waktu sw   ON sw.id = b.slot_id
            LEFT JOIN mekanik m       ON m.id  = s.mekanik_id
            LEFT JOIN users u         ON u.id  = s.kasir_id
            WHERE s.id = ? LIMIT 1
        ");
        $stmt->bind_param('i', $id);
        $stmt->execute();
        $servis = $stmt->get_result()->fetch_assoc();
        $stmt->close();
        if (!$servis) responseError('Servis tidak ditemukan', 404);

        // Sparepart digunakan (include sumber & status_persetujuan)
        $stmt = $db->prepare("
            SELECT ss.id, ss.jumlah, ss.harga_jual, ss.subtotal,
                   ss.sumber, ss.status_persetujuan,
                   sp.id AS sparepart_id, sp.nama, sp.satuan, sp.stok
            FROM servis_sparepart ss
            JOIN sparepart sp ON sp.id = ss.sparepart_id
            WHERE ss.servis_id = ?
            ORDER BY ss.sumber ASC, sp.nama ASC
        ");
        $stmt->bind_param('i', $id);
        $stmt->execute();
        $res   = $stmt->get_result();
        $parts = [];
        $totalPart = 0;
        while ($r = $res->fetch_assoc()) {
            // Hitung total hanya dari sparepart yang disetujui
            if ($r['status_persetujuan'] === 'disetujui') {
                $totalPart += (float)$r['subtotal'];
            }
            $parts[] = $r;
        }
        $stmt->close();

        // Cek apakah ada sparepart menunggu persetujuan pelanggan
        $adaMenunggu = count(array_filter($parts, fn($p) =>
            $p['status_persetujuan'] === 'menunggu')) > 0;

        // List mekanik aktif
        $res     = $db->query("SELECT id, nama, spesialisasi FROM mekanik WHERE is_aktif=1 ORDER BY nama");
        $mekanik = [];
        while ($r = $res->fetch_assoc()) $mekanik[] = $r;

        $totalJasa = (float)($servis['harga_jasa'] ?? 0);

        responseOk('OK', [
            'servis'          => $servis,
            'sparepart'       => $parts,
            'mekanik_list'    => $mekanik,
            'total_jasa'      => $totalJasa,
            'total_part'      => $totalPart,
            'grand_total'     => $totalJasa + $totalPart,
            'ada_menunggu_persetujuan' => $adaMenunggu,
        ]);
    }

    // List servis aktif
    $tanggal = $_GET['tanggal'] ?? date('Y-m-d');
    $stmt = $db->prepare("
        SELECT s.id, s.status, s.waktu_mulai,
               b.no_booking, b.tanggal_servis, b.tipe,
               p.nama AS nama_pelanggan, p.no_hp,
               k.merk, k.model, k.no_polisi,
               js.nama AS jenis_servis,
               m.nama AS nama_mekanik
        FROM servis s
        JOIN booking b    ON b.id = s.booking_id
        JOIN pelanggan p  ON p.id = b.pelanggan_id
        JOIN kendaraan k  ON k.id = b.kendaraan_id
        LEFT JOIN jenis_servis js ON js.id = b.jenis_servis_id
        LEFT JOIN mekanik m       ON m.id  = s.mekanik_id
        WHERE b.tanggal_servis = ?
        AND s.status NOT IN ('selesai')
        ORDER BY
            FIELD(s.status,'dikerjakan','diagnosa','menunggu_part','antrian','selesai_servis'),
            s.waktu_mulai ASC
    ");
    $stmt->bind_param('s', $tanggal);
    $stmt->execute();
    $rows = [];
    $result = $stmt->get_result();
    while ($r = $result->fetch_assoc()) $rows[] = $r;
    $stmt->close();
    responseOk('OK', $rows);
}

// ── PUT: update servis ────────────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'PUT') {
    $id     = (int)($_GET['id'] ?? 0);
    $body   = getRequestBody();
    $action = trim($body['action'] ?? 'update_info');
    if (!$id) responseError('ID servis wajib diisi');

    // ── Update status ─────────────────────────────────
    if ($action === 'update_status') {
        $status = trim($body['status'] ?? '');
        $valid  = ['antrian','diagnosa','menunggu_part','dikerjakan','selesai_servis','selesai'];
        if (!in_array($status, $valid)) responseError('Status tidak valid');

        $now = date('Y-m-d H:i:s');
        if ($status === 'diagnosa') {
            // Mulai diagnosa: catat waktu_mulai jika belum ada
            $stmt = $db->prepare("
                UPDATE servis
                SET status=?, waktu_mulai=COALESCE(waktu_mulai,?)
                WHERE id=?
            ");
            $stmt->bind_param('ssi', $status, $now, $id);
        } elseif ($status === 'dikerjakan') {
            $stmt = $db->prepare("UPDATE servis SET status=? WHERE id=?");
            $stmt->bind_param('si', $status, $id);
        } elseif ($status === 'selesai_servis') {
            $stmt = $db->prepare("UPDATE servis SET status=?, waktu_selesai=? WHERE id=?");
            $stmt->bind_param('ssi', $status, $now, $id);
        } else {
            $stmt = $db->prepare("UPDATE servis SET status=? WHERE id=?");
            $stmt->bind_param('si', $status, $id);
        }
        $stmt->execute(); $stmt->close();

        // Jika selesai_servis → update booking
        if ($status === 'selesai_servis') {
            $stmt = $db->prepare("
                UPDATE booking SET status='aktif'
                WHERE id=(SELECT booking_id FROM servis WHERE id=?)
            ");
            $stmt->bind_param('i', $id);
            $stmt->execute(); $stmt->close();
        }

        // ── Notifikasi FCM berdasarkan status ─────────────
        // Ambil pelanggan_id + no_booking via join
        $stmtD = $db->prepare("
            SELECT b.pelanggan_id, b.id AS booking_id, b.no_booking,
                   k.merk, k.model, k.no_polisi
            FROM   servis s
            JOIN   booking b  ON b.id = s.booking_id
            JOIN   kendaraan k ON k.id = b.kendaraan_id
            WHERE  s.id = ?
            LIMIT  1
        ");
        $stmtD->bind_param('i', $id);
        $stmtD->execute();
        $sDetail = $stmtD->get_result()->fetch_assoc();
        $stmtD->close();

        if ($sDetail) {
            $pelId     = (int)$sDetail['pelanggan_id'];
            $bId       = (int)$sDetail['booking_id'];
            $kendaraan = "{$sDetail['merk']} {$sDetail['model']} ({$sDetail['no_polisi']})";

            if ($status === 'diagnosa') {
                kirimNotifikasi(
                    $db, $pelId,
                    'servis_mulai',
                    'Kendaraan Sedang Didiagnosa 🔍',
                    "Kendaraan $kendaraan sedang dalam proses diagnosa oleh mekanik kami.",
                    $bId, $id
                );
            } elseif ($status === 'selesai_servis') {
                kirimNotifikasi(
                    $db, $pelId,
                    'servis_selesai',
                    'Servis Selesai! Kendaraan Siap Diambil ✅',
                    "Kendaraan $kendaraan sudah selesai diservis. Silakan datang untuk mengambil dan melakukan pembayaran.",
                    $bId, $id
                );
            }
        }
        // ─────────────────────────────────────────────────

        $db->close();
        responseOk('Status servis diperbarui ke: ' . $status);
    }

    // ── Update info (diagnosa, mekanik, catatan) ──────
    if ($action === 'update_info') {
        $diagnosa  = trim($body['diagnosa']        ?? '') ?: null;
        $catatan   = trim($body['catatan_mekanik'] ?? '') ?: null;
        $mekanikId = !empty($body['mekanik_id']) ? (int)$body['mekanik_id'] : null;

        $stmt = $db->prepare("
            UPDATE servis SET diagnosa=?, catatan_mekanik=?, mekanik_id=? WHERE id=?
        ");
        $stmt->bind_param('ssii', $diagnosa, $catatan, $mekanikId, $id);
        $stmt->execute(); $stmt->close();
        $db->close();
        responseOk('Data servis diperbarui');
    }

    // ── Selesai diagnosa: import request + tentukan percabangan ──
    // POST body: {
    //   action: 'selesai_diagnosa',
    //   import_request: true|false,  // pakai request pelanggan?
    //   lanjut_ke: 'dikerjakan'|'menunggu_part'
    // }
    if ($action === 'selesai_diagnosa') {
        $importRequest = !empty($body['import_request']);
        $lanjutKe      = trim($body['lanjut_ke'] ?? '');

        if (!in_array($lanjutKe, ['dikerjakan', 'menunggu_part'])) {
            responseError('lanjut_ke harus dikerjakan atau menunggu_part');
        }

        // Ambil booking_id dari servis ini
        $stmt = $db->prepare("SELECT booking_id FROM servis WHERE id=? LIMIT 1");
        $stmt->bind_param('i', $id);
        $stmt->execute();
        $row = $stmt->get_result()->fetch_assoc();
        $stmt->close();
        if (!$row) responseError('Servis tidak ditemukan', 404);
        $bookingId = (int)$row['booking_id'];

        // Import sparepart request dari booking jika diminta
        if ($importRequest) {
            // Ambil request yang belum ditolak dari booking ini
            $stmt = $db->prepare("
                SELECT bsr.sparepart_id, bsr.jumlah, bsr.harga_jual, bsr.subtotal
                FROM booking_sparepart_request bsr
                WHERE bsr.booking_id = ?
                AND bsr.status NOT IN ('ditolak')
            ");
            $stmt->bind_param('i', $bookingId);
            $stmt->execute();
            $requests = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
            $stmt->close();

            foreach ($requests as $req) {
                // Cek apakah sudah ada di servis_sparepart (hindari duplikat)
                $stmt = $db->prepare("
                    SELECT id FROM servis_sparepart
                    WHERE servis_id=? AND sparepart_id=? AND sumber='request'
                    LIMIT 1
                ");
                $stmt->bind_param('ii', $id, $req['sparepart_id']);
                $stmt->execute();
                $existing = $stmt->get_result()->fetch_assoc();
                $stmt->close();
                if ($existing) continue;

                // status_persetujuan: jika lanjut ke dikerjakan = disetujui,
                // jika menunggu_part = menunggu (perlu konfirmasi pelanggan lagi)
                $statusPersetujuan = ($lanjutKe === 'dikerjakan') ? 'disetujui' : 'menunggu';

                $stmt = $db->prepare("
                    INSERT INTO servis_sparepart
                      (servis_id, sparepart_id, jumlah, harga_jual, subtotal,
                       sumber, status_persetujuan)
                    VALUES (?, ?, ?, ?, ?, 'request', ?)
                ");
                $stmt->bind_param(
                    'iiidds',
                    $id,
                    $req['sparepart_id'],
                    $req['jumlah'],
                    $req['harga_jual'],
                    $req['subtotal'],
                    $statusPersetujuan
                );
                $stmt->execute();
                $stmt->close();
            }
        }

        // Update status servis
        $now = date('Y-m-d H:i:s');
        $stmt = $db->prepare("
            UPDATE servis SET status=?, waktu_diagnosa=? WHERE id=?
        ");
        $stmt->bind_param('ssi', $lanjutKe, $now, $id);
        $stmt->execute(); $stmt->close();

        // ── Notifikasi FCM: sparepart perlu persetujuan ───
        if ($lanjutKe === 'menunggu_part' && $importRequest) {
            $stmtD = $db->prepare("
                SELECT b.pelanggan_id, b.no_booking, k.merk, k.model, k.no_polisi,
                       COUNT(bsr.id) AS jml_part
                FROM   servis s
                JOIN   booking b   ON b.id = s.booking_id
                JOIN   kendaraan k ON k.id = b.kendaraan_id
                JOIN   booking_sparepart_request bsr ON bsr.booking_id = b.id AND bsr.status = 'menunggu'
                WHERE  s.id = ?
                GROUP  BY b.pelanggan_id, b.no_booking, k.merk, k.model, k.no_polisi
                LIMIT  1
            ");
            $stmtD->bind_param('i', $id);
            $stmtD->execute();
            $sDetail = $stmtD->get_result()->fetch_assoc();
            $stmtD->close();
            if ($sDetail && (int)$sDetail['jml_part'] > 0) {
                $jml       = (int)$sDetail['jml_part'];
                $kendaraan = "{$sDetail['merk']} {$sDetail['model']} ({$sDetail['no_polisi']})";
                kirimNotifikasi(
                    $db,
                    (int)$sDetail['pelanggan_id'],
                    'servis_sparepart',
                    'Konfirmasi Sparepart Diperlukan 🔧',
                    "Ada $jml sparepart yang diusulkan untuk kendaraan $kendaraan. Buka aplikasi untuk menyetujui atau menolak.",
                    $bookingId, $id
                );
            }
        }
        // ─────────────────────────────────────────────────

        $db->close();

        $pesan = $lanjutKe === 'dikerjakan'
            ? 'Diagnosa selesai, servis langsung dikerjakan'
            : 'Diagnosa selesai, menunggu persetujuan sparepart dari pelanggan';

        responseOk($pesan, ['status_baru' => $lanjutKe]);
    }

    responseError('Action tidak valid');
}

// ── POST: tambah sparepart ────────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $body        = getRequestBody();
    $servisId    = (int)($body['servis_id']    ?? 0);
    $sparepartId = (int)($body['sparepart_id'] ?? 0);
    $jumlah      = (int)($body['jumlah']       ?? 1);
    $sumber      = in_array($body['sumber'] ?? '', ['request','rekomendasi','manual'])
                     ? $body['sumber']
                     : 'manual';
    // rekomendasi kasir = menunggu persetujuan, manual = langsung disetujui
    $statusPersetujuan = ($sumber === 'rekomendasi') ? 'menunggu' : 'disetujui';

    if (!$servisId || !$sparepartId || $jumlah < 1)
        responseError('Data tidak lengkap');

    // Cek stok
    $stmt = $db->prepare("SELECT nama, harga_jual, stok FROM sparepart WHERE id=? AND is_aktif=1 LIMIT 1");
    $stmt->bind_param('i', $sparepartId);
    $stmt->execute();
    $sp = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$sp) responseError('Sparepart tidak ditemukan', 404);
    if ($sp['stok'] < $jumlah)
        responseError("Stok {$sp['nama']} tidak cukup (tersisa {$sp['stok']})");

    $harga    = (float)$sp['harga_jual'];
    $subtotal = $harga * $jumlah;

    $stmt = $db->prepare("
        INSERT INTO servis_sparepart
          (servis_id, sparepart_id, jumlah, harga_jual, subtotal, sumber, status_persetujuan)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ");
    $stmt->bind_param('iiiidss', $servisId, $sparepartId, $jumlah, $harga, $subtotal, $sumber, $statusPersetujuan);
    if (!$stmt->execute()) responseError('Gagal menambah sparepart', 500);
    $newId = $stmt->insert_id;
    $stmt->close();
    $db->close();

    responseOk('Sparepart ditambahkan', [
        'id'                  => $newId,
        'subtotal'            => $subtotal,
        'sumber'              => $sumber,
        'status_persetujuan'  => $statusPersetujuan,
    ]);
}

// ── DELETE: hapus sparepart ───────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'DELETE') {
    $partId = (int)($_GET['part_id'] ?? 0);
    if (!$partId) responseError('part_id wajib diisi');

    $stmt = $db->prepare("DELETE FROM servis_sparepart WHERE id=?");
    $stmt->bind_param('i', $partId);
    $stmt->execute();
    $affected = $stmt->affected_rows;
    $stmt->close();
    $db->close();

    if ($affected === 0) responseError('Item tidak ditemukan', 404);
    responseOk('Sparepart dihapus dari servis');
}

responseError('Method tidak diizinkan', 405);