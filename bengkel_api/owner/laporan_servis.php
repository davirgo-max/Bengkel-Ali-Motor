<?php
// owner/laporan_servis.php
// GET ?periode=hari_ini|minggu_ini|bulan_ini  (default: bulan_ini)
//     ?tgl_mulai=YYYY-MM-DD&tgl_selesai=YYYY-MM-DD  (custom range dari Flutter)
//     ?dari=YYYY-MM-DD&sampai=YYYY-MM-DD             (custom range langsung)
//     &mekanik_id=X           (opsional, filter per mekanik)
//     &jenis_servis_id=X      (opsional, filter per jenis servis)

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../middleware/auth.php';

setCORSHeaders();
if ($_SERVER['REQUEST_METHOD'] !== 'GET') responseError('Method tidak diizinkan', 405);

requireRole('owner');
$db = getDB();

// ── Params ───────────────────────────────────────────────
$periode = $_GET['periode'] ?? 'bulan_ini';

if (!empty($_GET['tgl_mulai']) && !empty($_GET['tgl_selesai'])) {
    // Custom range dari Flutter
    $dari   = $_GET['tgl_mulai'];
    $sampai = $_GET['tgl_selesai'];
} elseif (!empty($_GET['dari']) && !empty($_GET['sampai'])) {
    // Custom range langsung
    $dari   = $_GET['dari'];
    $sampai = $_GET['sampai'];
} else {
    // Konversi periode keyword → range tanggal
    $today = date('Y-m-d');
    switch ($periode) {
        case 'hari_ini':
            $dari   = $today;
            $sampai = $today;
            break;
        case 'minggu_ini':
            $dari   = date('Y-m-d', strtotime('monday this week'));
            $sampai = date('Y-m-d', strtotime('sunday this week'));
            break;
        case 'bulan_ini':
        default:
            $dari   = date('Y-m-01');
            $sampai = date('Y-m-t');
            break;
    }
}

$mekanikId     = !empty($_GET['mekanik_id'])      ? (int)$_GET['mekanik_id']      : null;
$jenisServisId = !empty($_GET['jenis_servis_id']) ? (int)$_GET['jenis_servis_id'] : null;

// ── Bangun klausa WHERE dinamis ──────────────────────────
$where   = "b.tanggal_servis BETWEEN ? AND ?";
$params  = [$dari, $sampai];
$types   = 'ss';

if ($mekanikId) {
    $where   .= " AND s.mekanik_id = ?";
    $params[]  = $mekanikId;
    $types    .= 'i';
}
if ($jenisServisId) {
    $where   .= " AND b.jenis_servis_id = ?";
    $params[]  = $jenisServisId;
    $types    .= 'i';
}

// ── Ringkasan ─────────────────────────────────────────────
$stmt = $db->prepare("
    SELECT
        COUNT(DISTINCT s.id)                                             AS total_servis,
        SUM(s.status = 'selesai')                                        AS selesai,
        SUM(s.status IN ('antrian','proses'))                            AS berjalan,
        COALESCE(SUM(CASE WHEN s.status='selesai' THEN
            COALESCE(js.harga_jasa, 0) + COALESCE(sp_total.total_sp, 0)
        END), 0)                                                         AS total_pendapatan
    FROM booking b
    LEFT JOIN servis s        ON s.booking_id = b.id
    LEFT JOIN jenis_servis js ON js.id = b.jenis_servis_id
    LEFT JOIN (
        SELECT servis_id, SUM(subtotal) AS total_sp
        FROM servis_sparepart
        WHERE status_persetujuan = 'disetujui'
        GROUP BY servis_id
    ) sp_total ON sp_total.servis_id = s.id
    WHERE $where
");
$stmt->bind_param($types, ...$params);
$stmt->execute();
$ringkasan = $stmt->get_result()->fetch_assoc();
$stmt->close();

// ── Terlaris per jenis servis ─────────────────────────────
$stmt = $db->prepare("
    SELECT
        js.id,
        js.nama,
        COUNT(s.id)                                            AS jumlah,
        COALESCE(SUM(js.harga_jasa), 0)                       AS total_jasa
    FROM booking b
    LEFT JOIN servis s        ON s.booking_id = b.id AND s.status = 'selesai'
    LEFT JOIN jenis_servis js ON js.id = b.jenis_servis_id
    WHERE $where
    GROUP BY js.id, js.nama
    ORDER BY jumlah DESC
    LIMIT 10
");
$stmt->bind_param($types, ...$params);
$stmt->execute();
$res = $stmt->get_result();
$terlaris = [];
while ($r = $res->fetch_assoc()) {
    $terlaris[] = [
        'id'         => (int)($r['id'] ?? 0),
        'nama'       => $r['nama'] ?? 'Tidak Diketahui',
        'jumlah'     => (int)$r['jumlah'],
        'total_jasa' => (float)$r['total_jasa'],
    ];
}
$stmt->close();

// ── Performa per mekanik ──────────────────────────────────
$stmt = $db->prepare("
    SELECT
        m.id,
        m.nama,
        COUNT(s.id)                                            AS jumlah_servis,
        COALESCE(SUM(js.harga_jasa), 0)                       AS total_pendapatan
    FROM booking b
    LEFT JOIN servis s        ON s.booking_id = b.id AND s.status = 'selesai'
    LEFT JOIN jenis_servis js ON js.id = b.jenis_servis_id
    LEFT JOIN mekanik m       ON m.id = s.mekanik_id
    WHERE $where AND m.id IS NOT NULL
    GROUP BY m.id, m.nama
    ORDER BY jumlah_servis DESC
");
$stmt->bind_param($types, ...$params);
$stmt->execute();
$res = $stmt->get_result();
$perMekanik = [];
while ($r = $res->fetch_assoc()) {
    $perMekanik[] = [
        'id'               => (int)$r['id'],
        'nama'             => $r['nama'],
        'jumlah_servis'    => (int)$r['jumlah_servis'],
        'total_pendapatan' => (float)$r['total_pendapatan'],
    ];
}
$stmt->close();

// ── Detail tabel servis ───────────────────────────────────
$stmt = $db->prepare("
    SELECT
        s.id,
        b.no_booking,
        b.tanggal_servis,
        p.nama                                                 AS nama_pelanggan,
        k.merk, k.model, k.no_polisi,
        js.nama                                                AS jenis_servis,
        COALESCE(js.harga_jasa, 0)                            AS harga_jasa,
        m.nama                                                 AS nama_mekanik,
        s.status,
        COALESCE(sp_total.total_sp, 0)                        AS total_sparepart,
        COALESCE(js.harga_jasa, 0) + COALESCE(sp_total.total_sp, 0) AS total_biaya
    FROM booking b
    JOIN pelanggan p      ON p.id = b.pelanggan_id
    JOIN kendaraan k      ON k.id = b.kendaraan_id
    LEFT JOIN servis s        ON s.booking_id = b.id
    LEFT JOIN jenis_servis js ON js.id = b.jenis_servis_id
    LEFT JOIN mekanik m       ON m.id = s.mekanik_id
    LEFT JOIN (
        SELECT servis_id, SUM(subtotal) AS total_sp
        FROM servis_sparepart
        WHERE status_persetujuan = 'disetujui'
        GROUP BY servis_id
    ) sp_total ON sp_total.servis_id = s.id
    WHERE $where
    ORDER BY b.tanggal_servis DESC, b.id DESC
    LIMIT 200
");
$stmt->bind_param($types, ...$params);
$stmt->execute();
$res = $stmt->get_result();
$detail = [];
while ($r = $res->fetch_assoc()) {
    $detail[] = [
        'id'              => (int)($r['id'] ?? 0),
        'no_booking'      => $r['no_booking'],
        'tanggal_servis'  => $r['tanggal_servis'],
        'nama_pelanggan'  => $r['nama_pelanggan'],
        'kendaraan'       => trim("{$r['merk']} {$r['model']}"),
        'no_polisi'       => $r['no_polisi'],
        'jenis_servis'    => $r['jenis_servis'] ?? '-',
        'harga_jasa'      => (float)$r['harga_jasa'],
        'nama_mekanik'    => $r['nama_mekanik'] ?? '-',
        'status'          => $r['status'] ?? '-',
        'total_sparepart' => (float)$r['total_sparepart'],
        'total_biaya'     => (float)$r['total_biaya'],
    ];
}
$stmt->close();

// ── Daftar mekanik & jenis servis untuk filter dropdown ──
$mekanikList = [];
$res = $db->query("SELECT id, nama FROM mekanik WHERE is_aktif = 1 ORDER BY nama");
while ($r = $res->fetch_assoc()) $mekanikList[] = ['id' => (int)$r['id'], 'nama' => $r['nama']];

$jenisList = [];
$res = $db->query("SELECT id, nama FROM jenis_servis WHERE is_aktif = 1 ORDER BY nama");
while ($r = $res->fetch_assoc()) $jenisList[] = ['id' => (int)$r['id'], 'nama' => $r['nama']];

responseOk('ok', [
    'periode'     => ['dari' => $dari, 'sampai' => $sampai, 'periode' => $periode],
    'filter'      => ['mekanik_id' => $mekanikId, 'jenis_servis_id' => $jenisServisId],
    'ringkasan'   => [
        'total_servis'     => (int)($ringkasan['total_servis'] ?? 0),
        'selesai'          => (int)($ringkasan['selesai'] ?? 0),
        'berjalan'         => (int)($ringkasan['berjalan'] ?? 0),
        'total_pendapatan' => (float)($ringkasan['total_pendapatan'] ?? 0),
    ],
    'terlaris'    => $terlaris,
    'per_mekanik' => $perMekanik,
    'detail'      => $detail,
    'filter_options' => [
        'mekanik'      => $mekanikList,
        'jenis_servis' => $jenisList,
    ],
]);