<?php
// owner/laporan_keuangan.php
// GET ?bulan=MM&tahun=YYYY          → laporan keuangan bulan tertentu
// GET ?dari=YYYY-MM-DD&sampai=YYYY-MM-DD → rentang custom
//
// Response:
//   pendapatan        → dari transaksi servis + penjualan sparepart langsung
//   pengeluaran       → dari pembelian stok
//   laba_bersih       → pendapatan - pengeluaran
//   grafik_harian[]   → data per hari untuk chart (7 hari terakhir jika bulan=ini)
//   detail_pendapatan → breakdown per sumber

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../middleware/auth.php';

setCORSHeaders();
if ($_SERVER['REQUEST_METHOD'] !== 'GET') responseError('Method tidak diizinkan', 405);

requireRole('owner');
$db = getDB();

// ── Hitung range tanggal ─────────────────────────────────
if (!empty($_GET['dari']) && !empty($_GET['sampai'])) {
    $dari   = $_GET['dari'];
    $sampai = $_GET['sampai'];
} elseif (!empty($_GET['bulan']) && !empty($_GET['tahun'])) {
    $bln    = str_pad((int)$_GET['bulan'], 2, '0', STR_PAD_LEFT);
    $thn    = (int)$_GET['tahun'];
    $dari   = "$thn-$bln-01";
    $sampai = date('Y-m-t', strtotime($dari));
} else {
    // Default: bulan ini
    $dari   = date('Y-m-01');
    $sampai = date('Y-m-t');
}

// ── Pendapatan dari servis ────────────────────────────────
$stmt = $db->prepare("
    SELECT COALESCE(SUM(t.total_bayar), 0) AS total
    FROM transaksi t
    WHERE t.tipe = 'servis'
      AND DATE(t.created_at) BETWEEN ? AND ?
");
$stmt->bind_param('ss', $dari, $sampai);
$stmt->execute();
$pendapatanServis = (float)($stmt->get_result()->fetch_assoc()['total'] ?? 0);
$stmt->close();

// ── Pendapatan dari penjualan sparepart langsung ─────────
$stmt = $db->prepare("
    SELECT COALESCE(SUM(t.total_bayar), 0) AS total
    FROM transaksi t
    WHERE t.tipe = 'sparepart'
      AND DATE(t.created_at) BETWEEN ? AND ?
");
$stmt->bind_param('ss', $dari, $sampai);
$stmt->execute();
$pendapatanSparepart = (float)($stmt->get_result()->fetch_assoc()['total'] ?? 0);
$stmt->close();

$totalPendapatan = $pendapatanServis + $pendapatanSparepart;

// ── Pengeluaran dari pembelian stok ──────────────────────
$stmt = $db->prepare("
    SELECT COALESCE(SUM(d.subtotal), 0) AS total
    FROM pembelian_stok p
    JOIN detail_pembelian_stok d ON d.pembelian_id = p.id
    WHERE p.tanggal BETWEEN ? AND ?
");
$stmt->bind_param('ss', $dari, $sampai);
$stmt->execute();
$totalPengeluaran = (float)($stmt->get_result()->fetch_assoc()['total'] ?? 0);
$stmt->close();

$labaBersih = $totalPendapatan - $totalPengeluaran;

// ── Grafik harian (per hari dalam range, max 31 hari) ────
$stmt = $db->prepare("
    SELECT
        DATE(t.created_at)                       AS tanggal,
        COALESCE(SUM(t.total_bayar), 0)          AS pendapatan
    FROM transaksi t
    WHERE DATE(t.created_at) BETWEEN ? AND ?
    GROUP BY DATE(t.created_at)
    ORDER BY tanggal ASC
");
$stmt->bind_param('ss', $dari, $sampai);
$stmt->execute();
$res = $stmt->get_result();
$grafikHarian = [];
while ($r = $res->fetch_assoc()) {
    $grafikHarian[] = [
        'tanggal'    => $r['tanggal'],
        'pendapatan' => (float)$r['pendapatan'],
    ];
}
$stmt->close();

// ── Grafik mingguan (7 minggu terakhir) untuk dashboard ──
$stmt = $db->prepare("
    SELECT
        YEARWEEK(t.created_at, 1)                AS minggu,
        MIN(DATE(t.created_at))                  AS tgl_mulai,
        COALESCE(SUM(t.total_bayar), 0)          AS pendapatan
    FROM transaksi t
    WHERE DATE(t.created_at) BETWEEN DATE_SUB(?, INTERVAL 6 WEEK) AND ?
    GROUP BY YEARWEEK(t.created_at, 1)
    ORDER BY minggu ASC
    LIMIT 7
");
$stmt->bind_param('ss', $sampai, $sampai);
$stmt->execute();
$res = $stmt->get_result();
$grafikMingguan = [];
while ($r = $res->fetch_assoc()) {
    $grafikMingguan[] = [
        'minggu'     => $r['minggu'],
        'tgl_mulai'  => $r['tgl_mulai'],
        'pendapatan' => (float)$r['pendapatan'],
    ];
}
$stmt->close();

// ── Jumlah transaksi ─────────────────────────────────────
$stmt = $db->prepare("
    SELECT COUNT(*) AS total FROM transaksi
    WHERE DATE(created_at) BETWEEN ? AND ?
");
$stmt->bind_param('ss', $dari, $sampai);
$stmt->execute();
$jumlahTransaksi = (int)($stmt->get_result()->fetch_assoc()['total'] ?? 0);
$stmt->close();

responseOk('ok',[
    'periode' => [
        'dari'   => $dari,
        'sampai' => $sampai,
    ],
    'ringkasan' => [
        'pendapatan'          => $totalPendapatan,
        'pendapatan_servis'   => $pendapatanServis,
        'pendapatan_sparepart'=> $pendapatanSparepart,
        'pengeluaran'         => $totalPengeluaran,
        'laba_bersih'         => $labaBersih,
        'jumlah_transaksi'    => $jumlahTransaksi,
    ],
    'grafik_harian'   => $grafikHarian,
    'grafik_mingguan' => $grafikMingguan,
]);
