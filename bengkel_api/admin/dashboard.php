<?php
// admin/dashboard.php
// GET → ringkasan health-check bengkel untuk Dashboard Admin
//
// Response:
//   stat_card       → 4 angka cepat (stok kritis, mekanik aktif, pelanggan diblokir, hari libur bulan ini)
//   stok_kritis     → list sparepart stok menipis / habis (maks 10)
//   hari_libur      → list hari libur mendatang dalam 30 hari ke depan (maks 5)
//   status_staff    → ringkasan jumlah kasir aktif vs nonaktif

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../middleware/auth.php';

setCORSHeaders();
if ($_SERVER['REQUEST_METHOD'] !== 'GET') responseError('Method tidak diizinkan', 405);

requireRole('admin');
$db = getDB();

// ── 1. Stat: sparepart stok kritis (stok <= stok_minimum & aktif) ────────────
$row = $db->query("
    SELECT COUNT(*) AS total
    FROM sparepart
    WHERE stok <= stok_minimum AND is_aktif = 1
")->fetch_assoc();
$statStokKritis = (int)$row['total'];

// ── 2. Stat: mekanik aktif ────────────────────────────────────────────────────
$row = $db->query("
    SELECT COUNT(*) AS total FROM mekanik WHERE is_aktif = 1
")->fetch_assoc();
$statMekanikAktif = (int)$row['total'];

// ── 3. Stat: pelanggan diblokir ───────────────────────────────────────────────
$row = $db->query("
    SELECT COUNT(*) AS total FROM pelanggan WHERE is_diblokir = 1
")->fetch_assoc();
$statPelangganBlokir = (int)$row['total'];

// ── 4. Stat: hari libur bulan ini ─────────────────────────────────────────────
$bulanIni  = date('Y-m');
$row = $db->query("
    SELECT COUNT(*) AS total
    FROM hari_libur
    WHERE DATE_FORMAT(tanggal, '%Y-%m') = '$bulanIni'
")->fetch_assoc();
$statHariLibur = (int)$row['total'];

// ── 5. Tabel stok kritis (maks 10) ───────────────────────────────────────────
$result = $db->query("
    SELECT s.id, s.kode, s.nama, s.satuan,
           s.stok, s.stok_minimum,
           k.nama AS kategori,
           (s.stok = 0) AS habis
    FROM sparepart s
    LEFT JOIN kategori_sparepart k ON k.id = s.kategori_id
    WHERE s.stok <= s.stok_minimum AND s.is_aktif = 1
    ORDER BY s.stok ASC, s.nama ASC
    LIMIT 10
");
$stokKritis = [];
while ($r = $result->fetch_assoc()) {
    $r['habis'] = (bool)$r['habis'];
    $r['stok']  = (int)$r['stok'];
    $r['stok_minimum'] = (int)$r['stok_minimum'];
    $stokKritis[] = $r;
}

// ── 6. Hari libur mendatang (30 hari ke depan, maks 5) ───────────────────────
$hari30 = date('Y-m-d', strtotime('+30 days'));
$today  = date('Y-m-d');
$stmt = $db->prepare("
    SELECT id, tanggal, keterangan, sumber
    FROM hari_libur
    WHERE tanggal >= ? AND tanggal <= ?
    ORDER BY tanggal ASC
    LIMIT 5
");
$stmt->bind_param('ss', $today, $hari30);
$stmt->execute();
$result = $stmt->get_result();
$hariLiburMendatang = [];
while ($r = $result->fetch_assoc()) {
    $hariLiburMendatang[] = $r;
}
$stmt->close();

// ── 7. Status staff (owner + kasir) ─────────────────────────────────────────
$result = $db->query("
    SELECT role,
           SUM(is_aktif = 1)  AS aktif,
           SUM(is_aktif = 0)  AS nonaktif,
           COUNT(*)            AS total
    FROM users
    WHERE role IN ('kasir', 'owner')
    GROUP BY role
");
$statusStaff = [];
while ($r = $result->fetch_assoc()) {
    $r['aktif']    = (int)$r['aktif'];
    $r['nonaktif'] = (int)$r['nonaktif'];
    $r['total']    = (int)$r['total'];
    $statusStaff[] = $r;
}

$db->close();

responseOk('OK', [
    'stat_card' => [
        'stok_kritis'       => $statStokKritis,
        'mekanik_aktif'     => $statMekanikAktif,
        'pelanggan_diblokir'=> $statPelangganBlokir,
        'hari_libur_bulan_ini' => $statHariLibur,
    ],
    'stok_kritis'         => $stokKritis,
    'hari_libur_mendatang'=> $hariLiburMendatang,
    'status_staff'        => $statusStaff,
]);
