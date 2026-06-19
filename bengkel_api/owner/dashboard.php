<?php
// owner/dashboard.php
// GET → stat cards + grafik pendapatan 8 minggu + ringkasan hari ini

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../middleware/auth.php';

setCORSHeaders();
if ($_SERVER['REQUEST_METHOD'] !== 'GET') responseError('Method tidak diizinkan', 405);

requireRole('owner');
$db  = getDB();
$now = date('Y-m-d');

// ── Pendapatan bulan ini ──────────────────────────────────
$bln1 = date('Y-m-01');
$bln2 = date('Y-m-t');
$stmt = $db->prepare("
    SELECT COALESCE(SUM(total_bayar), 0) AS total
    FROM transaksi
    WHERE DATE(created_at) BETWEEN ? AND ?
");
$stmt->bind_param('ss', $bln1, $bln2);
$stmt->execute();
$pendapatanBulanIni = (float)($stmt->get_result()->fetch_assoc()['total'] ?? 0);
$stmt->close();

// Pendapatan bulan lalu (banding)
$lalu1 = date('Y-m-01', strtotime('-1 month'));
$lalu2 = date('Y-m-t',  strtotime('-1 month'));
$stmt = $db->prepare("
    SELECT COALESCE(SUM(total_bayar), 0) AS total
    FROM transaksi
    WHERE DATE(created_at) BETWEEN ? AND ?
");
$stmt->bind_param('ss', $lalu1, $lalu2);
$stmt->execute();
$pendapatanBulanLalu = (float)($stmt->get_result()->fetch_assoc()['total'] ?? 0);
$stmt->close();

// ── Servis aktif hari ini ─────────────────────────────────
$stmt = $db->prepare("
    SELECT COUNT(*) AS total
    FROM servis s
    JOIN booking b ON b.id = s.booking_id
    WHERE b.tanggal_servis = ?
      AND s.status IN ('antrian','proses')
");
$stmt->bind_param('s', $now);
$stmt->execute();
$servisAktif = (int)($stmt->get_result()->fetch_assoc()['total'] ?? 0);
$stmt->close();

// ── Total servis selesai bulan ini ───────────────────────
$stmt = $db->prepare("
    SELECT COUNT(*) AS total
    FROM servis s
    JOIN booking b ON b.id = s.booking_id
    WHERE b.tanggal_servis BETWEEN ? AND ?
      AND s.status = 'selesai'
");
$stmt->bind_param('ss', $bln1, $bln2);
$stmt->execute();
$servisSelesai = (int)($stmt->get_result()->fetch_assoc()['total'] ?? 0);
$stmt->close();

// ── Pelanggan diblokir ────────────────────────────────────
$res = $db->query("
    SELECT COUNT(*) AS total FROM pelanggan_blokir
    WHERE blokir_sampai IS NULL OR blokir_sampai > NOW()
");
$pelangganDiblokir = (int)($res->fetch_assoc()['total'] ?? 0);

// ── Stok kritis ───────────────────────────────────────────
$res = $db->query("
    SELECT COUNT(*) AS total FROM sparepart
    WHERE stok <= stok_minimum AND is_aktif = 1
");
$stokKritis = (int)($res->fetch_assoc()['total'] ?? 0);

// ── Grafik pendapatan 8 minggu ───────────────────────────
$stmt = $db->prepare("
    SELECT
        YEARWEEK(created_at, 1)        AS minggu_key,
        DATE(MIN(created_at))          AS tgl_mulai,
        COALESCE(SUM(total_bayar), 0)  AS pendapatan
    FROM transaksi
    WHERE DATE(created_at) >= DATE_SUB(?, INTERVAL 7 WEEK)
    GROUP BY YEARWEEK(created_at, 1)
    ORDER BY minggu_key ASC
    LIMIT 8
");
$stmt->bind_param('s', $now);
$stmt->execute();
$res = $stmt->get_result();
$grafikMingguan = [];
while ($r = $res->fetch_assoc()) {
    $grafikMingguan[] = [
        'minggu_key' => $r['minggu_key'],
        'tgl_mulai'  => $r['tgl_mulai'],
        'pendapatan' => (float)$r['pendapatan'],
    ];
}
$stmt->close();

// ── Top 5 mekanik bulan ini ───────────────────────────────
$stmt = $db->prepare("
    SELECT m.nama, COUNT(s.id) AS jumlah
    FROM servis s
    JOIN booking b ON b.id = s.booking_id
    JOIN mekanik m ON m.id = s.mekanik_id
    WHERE b.tanggal_servis BETWEEN ? AND ?
      AND s.status = 'selesai'
    GROUP BY m.id, m.nama
    ORDER BY jumlah DESC
    LIMIT 5
");
$stmt->bind_param('ss', $bln1, $bln2);
$stmt->execute();
$res = $stmt->get_result();
$topMekanik = [];
while ($r = $res->fetch_assoc()) {
    $topMekanik[] = ['nama' => $r['nama'], 'jumlah' => (int)$r['jumlah']];
}
$stmt->close();

responseOk('ok',[
    'stat' => [
        'pendapatan_bulan_ini'  => $pendapatanBulanIni,
        'pendapatan_bulan_lalu' => $pendapatanBulanLalu,
        'servis_aktif_hari_ini' => $servisAktif,
        'servis_selesai_bulan'  => $servisSelesai,
        'pelanggan_diblokir'    => $pelangganDiblokir,
        'stok_kritis'           => $stokKritis,
    ],
    'grafik_mingguan' => $grafikMingguan,
    'top_mekanik'     => $topMekanik,
]);
