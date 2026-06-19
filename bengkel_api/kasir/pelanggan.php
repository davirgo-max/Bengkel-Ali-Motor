<?php
// kasir/pelanggan.php
// GET ?search=X          → cari pelanggan by nama/no_hp
// GET ?id=X              → detail pelanggan + kendaraan
// GET ?id=X&include=riwayat → detail + riwayat booking + penalti

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../middleware/auth.php';

setCORSHeaders();
if (!in_array($_SERVER['REQUEST_METHOD'], ['GET', 'PUT']))
    responseError('Method tidak diizinkan', 405);

$auth = requireRole('kasir', 'owner');
$db = getDB();

// ── PUT: blokir / buka blokir ─────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'PUT') {
    $body        = getRequestBody();
    $pelangganId = (int)($body['pelanggan_id'] ?? 0);
    $aksi        = trim($body['aksi'] ?? '');
    if (!$pelangganId) responseError('pelanggan_id wajib diisi');

    // Cek pelanggan ada
    $stmt = $db->prepare("SELECT id, is_diblokir FROM pelanggan WHERE id=? LIMIT 1");
    $stmt->bind_param('i', $pelangganId);
    $stmt->execute();
    $pelanggan = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if (!$pelanggan) responseError('Pelanggan tidak ditemukan', 404);

    // Ambil kasir_id untuk log
    $kasirId = $auth['user_id'] ?? 0;

    if ($aksi === 'buka_blokir') {
        $stmt = $db->prepare("
            UPDATE pelanggan
            SET is_diblokir=0, blokir_sampai=NULL, blokir_alasan=NULL
            WHERE id=?
        ");
        $stmt->bind_param('i', $pelangganId);
        $stmt->execute(); $stmt->close();
        // Insert log
        $dilakukanOleh = "kasir:$kasirId";
        $alasanLog = 'Dibuka manual oleh kasir';
        $stmt = $db->prepare("INSERT INTO log_blokir_pelanggan (pelanggan_id, aksi, alasan, dilakukan_oleh) VALUES (?, 'buka_blokir', ?, ?)");
        $stmt->bind_param('iss', $pelangganId, $alasanLog, $dilakukanOleh);
        $stmt->execute(); $stmt->close();
        $db->close();
        responseOk('Blokir pelanggan berhasil dibuka');

    } elseif ($aksi === 'blokir_manual') {
        $hari   = (int)($body['hari']   ?? 7);
        $alasan = trim($body['alasan']  ?? 'Diblokir manual oleh kasir');
        $sampai = date('Y-m-d H:i:s', strtotime("+$hari days"));
        $stmt = $db->prepare("
            UPDATE pelanggan
            SET is_diblokir=1, blokir_sampai=?, blokir_alasan=?
            WHERE id=?
        ");
        $stmt->bind_param('ssi', $sampai, $alasan, $pelangganId);
        $stmt->execute(); $stmt->close();
        // Insert log
        $dilakukanOleh = "kasir:$kasirId";
        $stmt = $db->prepare("INSERT INTO log_blokir_pelanggan (pelanggan_id, aksi, alasan, dilakukan_oleh) VALUES (?, 'blokir', ?, ?)");
        $stmt->bind_param('iss', $pelangganId, $alasan, $dilakukanOleh);
        $stmt->execute(); $stmt->close();
        $db->close();
        responseOk("Pelanggan diblokir selama $hari hari", [
            'blokir_sampai' => $sampai,
        ]);

    } else {
        responseError('Aksi tidak valid. Gunakan: buka_blokir atau blokir_manual');
    }
}

// ── Detail pelanggan ──────────────────────────────────────
if (isset($_GET['id'])) {
    $id      = (int)$_GET['id'];
    $include = trim($_GET['include'] ?? '');

    $stmt = $db->prepare("
        SELECT id, nama, no_hp, email, alamat,
               is_aktif, is_diblokir, blokir_sampai,
               blokir_alasan, total_noshow, created_at
        FROM pelanggan WHERE id = ? LIMIT 1
    ");
    $stmt->bind_param('i', $id);
    $stmt->execute();
    $pelanggan = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$pelanggan) responseError('Pelanggan tidak ditemukan', 404);

    // Kendaraan
    $stmt = $db->prepare("
        SELECT id, merk, model, tahun, no_polisi, warna
        FROM kendaraan WHERE pelanggan_id = ?
        ORDER BY created_at DESC
    ");
    $stmt->bind_param('i', $id);
    $stmt->execute();
    $kendaraan = [];
    $result = $stmt->get_result();
    while ($r = $result->fetch_assoc()) $kendaraan[] = $r;
    $stmt->close();

    $response = [
        'pelanggan' => $pelanggan,
        'kendaraan' => $kendaraan,
    ];

    // Riwayat booking + penalti (jika diminta)
    if ($include === 'riwayat') {
        $stmt = $db->prepare("
            SELECT b.id, b.no_booking, b.tanggal_servis,
                   b.status, b.tipe,
                   sw.label AS slot_label,
                   k.merk, k.model, k.no_polisi,
                   js.nama AS jenis_servis,
                   s.status AS status_servis
            FROM booking b
            JOIN kendaraan k  ON k.id = b.kendaraan_id
            LEFT JOIN slot_waktu sw   ON sw.id = b.slot_id
            LEFT JOIN jenis_servis js ON js.id = b.jenis_servis_id
            LEFT JOIN servis s        ON s.booking_id = b.id
            WHERE b.pelanggan_id = ?
            ORDER BY b.tanggal_servis DESC
            LIMIT 20
        ");
        $stmt->bind_param('i', $id);
        $stmt->execute();
        $riwayatBooking = [];
        $result = $stmt->get_result();
        while ($r = $result->fetch_assoc()) $riwayatBooking[] = $r;
        $stmt->close();

        $stmt = $db->prepare("
            SELECT pn.noshow_ke, pn.noshow_dalam_14,
                   pn.blokir_hari, pn.blokir_mulai,
                   pn.blokir_sampai, pn.created_at,
                   b.no_booking, b.tanggal_servis
            FROM penalti_noshow pn
            JOIN booking b ON b.id = pn.booking_id
            WHERE pn.pelanggan_id = ?
            ORDER BY pn.created_at DESC
        ");
        $stmt->bind_param('i', $id);
        $stmt->execute();
        $penalti = [];
        $result = $stmt->get_result();
        while ($r = $result->fetch_assoc()) $penalti[] = $r;
        $stmt->close();

        $response['riwayat_booking'] = $riwayatBooking;
        $response['riwayat_penalti'] = $penalti;
    }

    $db->close();
    responseOk('OK', $response);
}

// ── Cari pelanggan ────────────────────────────────────────
$search = trim($_GET['search'] ?? '');
if (!$search) responseError('Parameter search wajib diisi');

$keyword = '%' . $search . '%';
$stmt    = $db->prepare("
    SELECT id, nama, no_hp, email,
           is_diblokir, total_noshow,
           blokir_sampai, blokir_alasan
    FROM pelanggan
    WHERE (nama LIKE ? OR no_hp LIKE ? OR email LIKE ?)
    AND is_aktif = 1
    ORDER BY nama
    LIMIT 15
");
$stmt->bind_param('sss', $keyword, $keyword, $keyword);
$stmt->execute();
$rows = [];
$result = $stmt->get_result();
while ($r = $result->fetch_assoc()) {
    $r['is_diblokir'] = (bool)$r['is_diblokir'];
    $rows[] = $r;
}
$stmt->close();
$db->close();

responseOk('OK', $rows);