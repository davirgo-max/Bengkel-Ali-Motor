<?php
// pelanggan/status_servis.php
// GET                    → list semua servis milik pelanggan
// GET ?id=X              → detail servis + sparepart lengkap dengan sumber & status
// PUT ?id=X              → setujui / tolak sparepart (action: respon_sparepart)

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../middleware/auth.php';

setCORSHeaders();

$auth        = requireRole('pelanggan');
$pelangganId = $auth['user_id'];
$db          = getDB();

// ── GET ───────────────────────────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'GET') {

    // Detail servis beserta sparepart
    if (isset($_GET['id'])) {
        $servisId = (int)$_GET['id'];

        $stmt = $db->prepare("
            SELECT s.id, s.diagnosa, s.catatan_mekanik, s.catatan_pelanggan,
                   s.status, s.waktu_mulai, s.waktu_diagnosa, s.waktu_selesai,
                   b.no_booking, b.tanggal_servis, b.keluhan, b.status AS status_booking,
                   k.merk, k.model, k.no_polisi,
                   js.nama AS jenis_servis, js.harga_jasa,
                   m.nama AS mekanik,
                   u.nama AS kasir
            FROM servis s
            JOIN booking b    ON b.id  = s.booking_id
            JOIN kendaraan k  ON k.id  = b.kendaraan_id
            LEFT JOIN jenis_servis js ON js.id = b.jenis_servis_id
            LEFT JOIN mekanik m       ON m.id  = s.mekanik_id
            LEFT JOIN users u         ON u.id  = s.kasir_id
            WHERE s.id = ? AND b.pelanggan_id = ?
            LIMIT 1
        ");
        $stmt->bind_param('ii', $servisId, $pelangganId);
        $stmt->execute();
        $servis = $stmt->get_result()->fetch_assoc();
        $stmt->close();
        if (!$servis) responseError('Data servis tidak ditemukan', 404);

        // Ambil sparepart + sumber + status_persetujuan
        $stmt = $db->prepare("
            SELECT ss.id, ss.jumlah, ss.harga_jual, ss.subtotal,
                   ss.sumber, ss.status_persetujuan,
                   sp.id AS sparepart_id, sp.nama, sp.satuan
            FROM servis_sparepart ss
            JOIN sparepart sp ON sp.id = ss.sparepart_id
            WHERE ss.servis_id = ?
            ORDER BY ss.sumber ASC, sp.nama ASC
        ");
        $stmt->bind_param('i', $servisId);
        $stmt->execute();
        $result     = $stmt->get_result();
        $spareparts = [];
        $totalPart  = 0;
        while ($row = $result->fetch_assoc()) {
            if ($row['status_persetujuan'] === 'disetujui') {
                $totalPart += (float)$row['subtotal'];
            }
            $spareparts[] = $row;
        }
        $stmt->close();
        $db->close();

        // Cek apakah ada yang perlu respon pelanggan
        $adaMenunggu = count(array_filter($spareparts, fn($p) =>
            $p['status_persetujuan'] === 'menunggu')) > 0;

        $totalJasa = (float)($servis['harga_jasa'] ?? 0);

        responseOk('OK', [
            'servis'                   => $servis,
            'sparepart'                => $spareparts,
            'ada_menunggu_persetujuan' => $adaMenunggu,
            'estimasi_total'           => $totalJasa + $totalPart,
        ]);
    }

    // List semua servis milik pelanggan
    $stmt = $db->prepare("
        SELECT s.id, s.status, s.waktu_mulai, s.waktu_selesai,
               b.no_booking, b.tanggal_servis,
               k.merk, k.model, k.no_polisi,
               js.nama AS jenis_servis,
               (SELECT COUNT(*) > 0
                FROM servis_sparepart ss
                WHERE ss.servis_id = s.id
                AND ss.status_persetujuan = 'menunggu'
               ) AS ada_menunggu_persetujuan
        FROM servis s
        JOIN booking b    ON b.id = s.booking_id
        JOIN kendaraan k  ON k.id = b.kendaraan_id
        LEFT JOIN jenis_servis js ON js.id = b.jenis_servis_id
        WHERE b.pelanggan_id = ?
        ORDER BY b.tanggal_servis DESC
    ");
    $stmt->bind_param('i', $pelangganId);
    $stmt->execute();
    $result = $stmt->get_result();
    $rows   = [];
    while ($row = $result->fetch_assoc()) $rows[] = $row;
    $stmt->close();
    $db->close();
    responseOk('OK', $rows);
}

// ── PUT: respon sparepart dari pelanggan ──────────────────
// Body: {
//   action: 'respon_sparepart',
//   keputusan: 'setuju' | 'tolak',
//   sparepart_dipilih: int (id dari servis_sparepart yang dipilih, jika setuju),
//   catatan_pelanggan: string (opsional)
// }
if ($_SERVER['REQUEST_METHOD'] === 'PUT') {
    $servisId = (int)($_GET['id'] ?? 0);
    if (!$servisId) responseError('ID servis wajib diisi');

    $body   = getRequestBody();
    $action = trim($body['action'] ?? '');

    if ($action !== 'respon_sparepart') responseError('Action tidak valid');

    // Pastikan servis milik pelanggan ini & statusnya menunggu_part
    $stmt = $db->prepare("
        SELECT s.id, s.status
        FROM servis s
        JOIN booking b ON b.id = s.booking_id
        WHERE s.id = ? AND b.pelanggan_id = ?
        LIMIT 1
    ");
    $stmt->bind_param('ii', $servisId, $pelangganId);
    $stmt->execute();
    $servis = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$servis) responseError('Servis tidak ditemukan', 404);
    if ($servis['status'] !== 'menunggu_part')
        responseError('Servis tidak sedang menunggu persetujuan sparepart');

    $keputusan          = trim($body['keputusan'] ?? '');
    $sparepartDipilihId = !empty($body['sparepart_dipilih'])
                            ? (int)$body['sparepart_dipilih'] : null;
    $catatanPelanggan   = trim($body['catatan_pelanggan'] ?? '') ?: null;

    if (!in_array($keputusan, ['setuju', 'tolak']))
        responseError('keputusan harus setuju atau tolak');

    if ($keputusan === 'setuju' && !$sparepartDipilihId)
        responseError('Pilih sparepart yang disetujui terlebih dahulu');

    if ($keputusan === 'setuju') {
        // Validasi: id yang dipilih harus milik servis ini
        $stmt = $db->prepare("
            SELECT id FROM servis_sparepart
            WHERE id = ? AND servis_id = ? LIMIT 1
        ");
        $stmt->bind_param('ii', $sparepartDipilihId, $servisId);
        $stmt->execute();
        if (!$stmt->get_result()->fetch_assoc()) {
            $stmt->close();
            responseError('Sparepart yang dipilih tidak valid');
        }
        $stmt->close();

        // Semua item menunggu → ditolak dulu
        $stmt = $db->prepare("
            UPDATE servis_sparepart
            SET status_persetujuan = 'ditolak'
            WHERE servis_id = ? AND status_persetujuan = 'menunggu'
        ");
        $stmt->bind_param('i', $servisId);
        $stmt->execute(); $stmt->close();

        // Lalu yang dipilih pelanggan → disetujui
        $stmt = $db->prepare("
            UPDATE servis_sparepart
            SET status_persetujuan = 'disetujui'
            WHERE id = ? AND servis_id = ?
        ");
        $stmt->bind_param('ii', $sparepartDipilihId, $servisId);
        $stmt->execute(); $stmt->close();

    } else {
        // Tolak semua sparepart yang menunggu
        $stmt = $db->prepare("
            UPDATE servis_sparepart
            SET status_persetujuan = 'ditolak'
            WHERE servis_id = ? AND status_persetujuan = 'menunggu'
        ");
        $stmt->bind_param('i', $servisId);
        $stmt->execute(); $stmt->close();
    }

    // Simpan catatan pelanggan & update status servis ke dikerjakan
    $stmt = $db->prepare("
        UPDATE servis
        SET catatan_pelanggan = ?, status = 'dikerjakan'
        WHERE id = ?
    ");
    $stmt->bind_param('si', $catatanPelanggan, $servisId);
    $stmt->execute(); $stmt->close();
    $db->close();

    $pesan = $keputusan === 'setuju'
        ? 'Sparepart disetujui, servis akan dilanjutkan'
        : 'Sparepart ditolak, servis akan dilanjutkan tanpa sparepart tersebut';

    responseOk($pesan);
}

responseError('Method tidak diizinkan', 405);