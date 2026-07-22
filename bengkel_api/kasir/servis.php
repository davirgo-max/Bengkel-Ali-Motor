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

        // Request sparepart pelanggan yang BELUM diimpor ke servis ini --
        // dipakai popup "Tentukan Sparepart" supaya kasir bisa pilih
        // per-item (bukan cuma toggle impor semua-atau-tidak).
        $stmt = $db->prepare("
            SELECT bsr.sparepart_id, bsr.jumlah, bsr.harga_jual, bsr.subtotal,
                   sp.nama, sp.satuan, sp.stok
            FROM booking_sparepart_request bsr
            JOIN sparepart sp ON sp.id = bsr.sparepart_id
            WHERE bsr.booking_id = ?
            AND bsr.status NOT IN ('ditolak')
            AND NOT EXISTS (
                SELECT 1 FROM servis_sparepart ss
                WHERE ss.servis_id = ? AND ss.sparepart_id = bsr.sparepart_id
            )
        ");
        $stmt->bind_param('ii', $servis['booking_id'], $id);
        $stmt->execute();
        $res = $stmt->get_result();
        $requestPending = [];
        while ($r = $res->fetch_assoc()) $requestPending[] = $r;
        $stmt->close();

        // List mekanik aktif
        $res     = $db->query("SELECT id, nama, spesialisasi FROM mekanik WHERE is_aktif=1 ORDER BY nama");
        $mekanik = [];
        while ($r = $res->fetch_assoc()) $mekanik[] = $r;

        // List jenis servis aktif (untuk dropdown kasir saat diagnosa)
        $resJs      = $db->query("SELECT id, nama, harga_jasa, estimasi_menit FROM jenis_servis WHERE is_aktif=1 ORDER BY nama");
        $jenisList  = [];
        while ($r = $resJs->fetch_assoc()) $jenisList[] = $r;

        $totalJasa = (float)($servis['harga_jasa'] ?? 0);

        responseOk('OK', [
            'servis'                   => $servis,
            'sparepart'                => $parts,
            'mekanik_list'             => $mekanik,
            'jenis_servis_list'        => $jenisList,
            'total_jasa'               => $totalJasa,
            'total_part'               => $totalPart,
            'grand_total'              => $totalJasa + $totalPart,
            'ada_menunggu_persetujuan' => $adaMenunggu,
            'sparepart_request_pending' => $requestPending,
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

    // ── Update jenis servis (kasir bisa ubah/isi saat diagnosa) ──
    if ($action === 'update_jenis_servis') {
        $jenisServisId = !empty($body['jenis_servis_id']) ? (int)$body['jenis_servis_id'] : null;

        // Update di tabel booking karena jenis_servis_id ada di sana
        $stmt = $db->prepare("
            UPDATE booking SET jenis_servis_id=?
            WHERE id=(SELECT booking_id FROM servis WHERE id=? LIMIT 1)
        ");
        $stmt->bind_param('ii', $jenisServisId, $id);
        $stmt->execute(); $stmt->close();
        $db->close();
        responseOk('Jenis servis diperbarui');
    }

    // ── Selesai diagnosa: import request + tentukan percabangan ──
    // POST body: {
    //   action: 'selesai_diagnosa',
    //   import_sparepart_ids: [1,2,3],   // sparepart_id request pelanggan yang DIPILIH kasir untuk diimpor (per-item)
    //   import_request: true|false,      // cara lama: impor SEMUA request (dipakai kalau import_sparepart_ids tidak dikirim)
    //   konfirmasi_luar_aplikasi: true|false, // kasir sudah konfirmasi sparepart manual/rekomendasi ke pelanggan di luar app
    //   lanjut_ke: 'dikerjakan'|'menunggu_part'
    // }
    if ($action === 'selesai_diagnosa') {
        $importIds = isset($body['import_sparepart_ids']) && is_array($body['import_sparepart_ids'])
            ? array_map('intval', $body['import_sparepart_ids'])
            : null;
        // Kompatibilitas mundur: kalau frontend lama masih kirim
        // import_request boolean tanpa daftar spesifik, artinya impor semua.
        $importAllLegacy         = $importIds === null && !empty($body['import_request']);
        $konfirmasiLuarAplikasi  = !empty($body['konfirmasi_luar_aplikasi']);
        $lanjutKe                = trim($body['lanjut_ke'] ?? '');

        if (!in_array($lanjutKe, ['dikerjakan', 'menunggu_part'])) {
            responseError('lanjut_ke harus dikerjakan atau menunggu_part');
        }

        // Ambil booking_id dari servis ini
        $stmt = $db->prepare("
            SELECT s.booking_id, s.diagnosa, s.mekanik_id, b.jenis_servis_id
            FROM servis s
            JOIN booking b ON b.id = s.booking_id
            WHERE s.id=? LIMIT 1
        ");
        $stmt->bind_param('i', $id);
        $stmt->execute();
        $row = $stmt->get_result()->fetch_assoc();
        $stmt->close();
        if (!$row) responseError('Servis tidak ditemukan', 404);
        $bookingId = (int)$row['booking_id'];

        // Validasi: diagnosa, mekanik, dan jenis servis wajib diisi sebelum
        // servis boleh dilanjutkan ke tahap berikutnya. Dicek di sini juga
        // (bukan cuma di Flutter) supaya tidak bisa dilewati lewat panggilan
        // API langsung.
        if (trim((string)($row['diagnosa'] ?? '')) === '') {
            responseError('Diagnosa wajib diisi sebelum melanjutkan servis');
        }
        if (empty($row['mekanik_id'])) {
            responseError('Mekanik wajib dipilih sebelum melanjutkan servis');
        }
        if (empty($row['jenis_servis_id'])) {
            responseError('Jenis servis wajib ditentukan sebelum melanjutkan servis');
        }

        // Import sparepart request dari booking jika diminta -- baik per-item
        // (import_sparepart_ids) maupun cara lama (import semua)
        if ($importIds !== null || $importAllLegacy) {
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
                // Kalau kasir kirim daftar spesifik, hanya impor sparepart
                // yang benar-benar dicentang -- request lain yang tidak
                // dicentang dilewati (tidak ikut masuk ke servis).
                if ($importIds !== null && !in_array((int)$req['sparepart_id'], $importIds, true)) {
                    continue;
                }
                // Cek apakah sparepart ini SUDAH ada di servis, dari sumber
                // MANA PUN (request maupun ditambah manual kasir lewat
                // tombol "+"). Sebelumnya pengecekan ini dibatasi
                // `AND sumber='request'`, jadi kalau kasir sudah menambah
                // manual sparepart yang sama, import ini tetap menyisipkan
                // baris baru untuk part yang identik -> muncul dobel.
                $stmt = $db->prepare("
                    SELECT id FROM servis_sparepart
                    WHERE servis_id=? AND sparepart_id=?
                    LIMIT 1
                ");
                $stmt->bind_param('ii', $id, $req['sparepart_id']);
                $stmt->execute();
                $existing = $stmt->get_result()->fetch_assoc();
                $stmt->close();
                if ($existing) continue;

                // Sparepart dari request pelanggan sendiri SELALU langsung
                // 'disetujui', apapun lanjut_ke-nya -- pelanggan sudah
                // memilihnya sendiri saat booking, jadi tidak perlu approve
                // ulang di aplikasi. (Sebelumnya status ini ikut jadi
                // 'menunggu' saat lanjut_ke=menunggu_part, yang bikin servis
                // stuck menunggu approval untuk sesuatu yang sebenarnya
                // sudah disetujui pelanggan sejak awal.)
                $statusPersetujuan = 'disetujui';

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

        // Cek apakah servis ini punya sparepart manual/rekomendasi dari
        // kasir (di luar request pelanggan sendiri). Dipakai untuk (a)
        // mengunci opsi "Tunggu Persetujuan Pelanggan" kalau sparepart-nya
        // 100% dari request pelanggan sendiri -- tidak ada apa pun yang
        // perlu di-approve ulang -- dan (b) untuk auto-approve di bawah.
        $stmt = $db->prepare("
            SELECT COUNT(*) AS jml FROM servis_sparepart
            WHERE servis_id=? AND sumber IN ('manual','rekomendasi')
        ");
        $stmt->bind_param('i', $id);
        $stmt->execute();
        $adaManualRekomendasi = (int)($stmt->get_result()->fetch_assoc()['jml'] ?? 0) > 0;
        $stmt->close();

        // Divalidasi di sini juga (bukan cuma dikunci di Flutter) supaya
        // tidak bisa dilewati lewat panggilan API langsung.
        if ($lanjutKe === 'menunggu_part' && !$adaManualRekomendasi) {
            responseError('Tidak ada sparepart rekomendasi/manual dari kasir yang perlu disetujui pelanggan. Pilih "Langsung Kerjakan".');
        }

        // Update status servis
        $now = date('Y-m-d H:i:s');
        $stmt = $db->prepare("
            UPDATE servis SET status=?, waktu_diagnosa=? WHERE id=?
        ");
        $stmt->bind_param('ssi', $lanjutKe, $now, $id);
        $stmt->execute(); $stmt->close();

        // Kalau kasir pilih "Langsung Kerjakan" dan sudah konfirmasi ke
        // pelanggan di luar aplikasi (telepon/langsung di bengkel), semua
        // sparepart manual/rekomendasi yang masih 'menunggu' di-auto-approve
        // supaya servis tidak nyangkut menunggu approval in-app yang
        // mungkin tidak akan pernah datang.
        if ($lanjutKe === 'dikerjakan' && $konfirmasiLuarAplikasi) {
            $stmt = $db->prepare("
                UPDATE servis_sparepart SET status_persetujuan='disetujui'
                WHERE servis_id=? AND status_persetujuan='menunggu'
            ");
            $stmt->bind_param('i', $id);
            $stmt->execute(); $stmt->close();
        }

        // ── Notifikasi FCM: sparepart perlu persetujuan ───
        // Dikirim TEPAT saat status resmi pindah ke menunggu_part -- bukan
        // saat sparepart di-input (baik dari import request maupun dari
        // tombol "+" manual kasir). Alasannya: sebelum status ini di-set,
        // kasir mungkin masih menambah part lain atau akhirnya malah pilih
        // "langsung kerjakan" (skip menunggu_part) -- notifikasi yang
        // dikirim lebih awal jadi prematur/tidak relevan buat pelanggan.
        // Dihitung dari servis_sparepart langsung supaya mencakup SEMUA
        // sumber (request maupun manual/rekomendasi kasir), bukan cuma
        // yang berasal dari booking_sparepart_request.
        if ($lanjutKe === 'menunggu_part') {
            $stmtD = $db->prepare("
                SELECT b.pelanggan_id, b.no_booking, k.merk, k.model, k.no_polisi,
                       COUNT(ss.id) AS jml_part
                FROM   servis s
                JOIN   booking b   ON b.id = s.booking_id
                JOIN   kendaraan k ON k.id = b.kendaraan_id
                JOIN   servis_sparepart ss ON ss.servis_id = s.id
                                          AND ss.status_persetujuan = 'menunggu'
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

    // Kalau sparepart ini SUDAH ada di servis (dari sumber mana pun --
    // request maupun ditambah manual sebelumnya), gabung jumlahnya ke baris
    // yang sudah ada, jangan bikin baris baru. Ini pasangan dari fix di
    // action `selesai_diagnosa`: dua-duanya sama-sama mencegah 1 sparepart
    // muncul dobel di servis yang sama.
    $stmt = $db->prepare("
        SELECT id, jumlah, status_persetujuan FROM servis_sparepart
        WHERE servis_id=? AND sparepart_id=? LIMIT 1
    ");
    $stmt->bind_param('ii', $servisId, $sparepartId);
    $stmt->execute();
    $existing = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if ($existing) {
        $jumlahBaru  = (int)$existing['jumlah'] + $jumlah;
        $subtotalBaru = $harga * $jumlahBaru;
        $stmt = $db->prepare("
            UPDATE servis_sparepart
            SET jumlah=?, harga_jual=?, subtotal=?
            WHERE id=?
        ");
        $stmt->bind_param('iddi', $jumlahBaru, $harga, $subtotalBaru, $existing['id']);
        if (!$stmt->execute()) responseError('Gagal memperbarui jumlah sparepart', 500);
        $stmt->close();
        $newId    = (int)$existing['id'];
        $subtotal = $subtotalBaru;
        // Status persetujuan baris yang sudah ada TIDAK diturunkan jadi
        // 'disetujui' hanya karena ada penambahan jumlah -- kalau sudah
        // 'menunggu' (perlu persetujuan pelanggan), tetap 'menunggu'.
        $statusPersetujuan = $existing['status_persetujuan'];
    } else {
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
    }

    // Catatan: notifikasi FCM "Konfirmasi Sparepart Diperlukan" dikirim
    // dari sini HANYA untuk kasus servis yang statusnya SUDAH menunggu_part
    // (kasir menambah part lagi belakangan, sudah lewat momen transisi
    // status). Untuk kasus normal (masih diagnosa), notifikasi baru
    // dikirim nanti di action `selesai_diagnosa` saat status resmi
    // dipindah ke 'menunggu_part' -- supaya pelanggan tidak dapat notif
    // untuk sesuatu yang belum tentu jadi (mis. kasir masih nambah part
    // lain, atau akhirnya pilih "langsung kerjakan" dan skip menunggu_part).
    if ($statusPersetujuan === 'menunggu') {
        $stmtS = $db->prepare("SELECT status FROM servis WHERE id=? LIMIT 1");
        $stmtS->bind_param('i', $servisId);
        $stmtS->execute();
        $servisRow = $stmtS->get_result()->fetch_assoc();
        $stmtS->close();

        if ($servisRow && $servisRow['status'] === 'menunggu_part') {
            $stmtD = $db->prepare("
                SELECT b.pelanggan_id, b.id AS booking_id, k.merk, k.model, k.no_polisi
                FROM   servis s
                JOIN   booking b   ON b.id = s.booking_id
                JOIN   kendaraan k ON k.id = b.kendaraan_id
                WHERE  s.id = ?
                LIMIT  1
            ");
            $stmtD->bind_param('i', $servisId);
            $stmtD->execute();
            $sDetail = $stmtD->get_result()->fetch_assoc();
            $stmtD->close();

            if ($sDetail) {
                $kendaraan = "{$sDetail['merk']} {$sDetail['model']} ({$sDetail['no_polisi']})";
                kirimNotifikasi(
                    $db,
                    (int)$sDetail['pelanggan_id'],
                    'servis_sparepart',
                    'Konfirmasi Sparepart Diperlukan 🔧',
                    "Sparepart {$sp['nama']} diusulkan untuk kendaraan $kendaraan. Buka aplikasi untuk menyetujui atau menolak.",
                    (int)$sDetail['booking_id'],
                    $servisId
                );
            }
        }
    }

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