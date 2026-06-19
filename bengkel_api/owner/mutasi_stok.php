<?php
// owner/mutasi_stok.php
// GET  ?dari=YYYY-MM-DD&sampai=YYYY-MM-DD   → semua mutasi stok dalam range
// GET  ?dari=...&sampai=...&sparepart_id=X  → filter per item
// GET  ?ringkasan=1&dari=...&sampai=...     → hanya angka ringkasan

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../middleware/auth.php';

setCORSHeaders();
if ($_SERVER['REQUEST_METHOD'] !== 'GET') responseError('Method tidak diizinkan', 405);

requireRole('owner');
$db = getDB();

$dari        = $_GET['dari']          ?? date('Y-m-d');
$sampai      = $_GET['sampai']        ?? $dari;
$sparepartId = isset($_GET['sparepart_id']) ? (int)$_GET['sparepart_id'] : null;
$ringkasan   = !empty($_GET['ringkasan']);

// ── Ringkasan saja ────────────────────────────────────────
if ($ringkasan) {
    // Total masuk (pembelian stok)
    $stmt = $db->prepare("
        SELECT
            COUNT(DISTINCT p.id)          AS jumlah_pembelian,
            COALESCE(SUM(d.jumlah), 0)    AS total_qty_masuk,
            COALESCE(SUM(d.subtotal), 0)  AS total_nilai_masuk
        FROM pembelian_stok p
        JOIN detail_pembelian_stok d ON d.pembelian_id = p.id
        WHERE p.tanggal BETWEEN ? AND ?
    ");
    $stmt->bind_param('ss', $dari, $sampai);
    $stmt->execute();
    $masuk = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    // Total keluar via servis
    $stmt = $db->prepare("
        SELECT
            COALESCE(SUM(ss.jumlah), 0)   AS qty_keluar_servis,
            COALESCE(SUM(ss.subtotal), 0) AS nilai_keluar_servis
        FROM servis_sparepart ss
        JOIN servis s  ON s.id  = ss.servis_id
        JOIN booking b ON b.id  = s.booking_id
        WHERE b.tanggal_servis BETWEEN ? AND ?
        AND s.status = 'selesai'
        AND ss.status_persetujuan = 'disetujui'
    ");
    $stmt->bind_param('ss', $dari, $sampai);
    $stmt->execute();
    $keluarServis = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    // Total keluar via jual langsung
    $stmt = $db->prepare("
        SELECT
            COALESCE(SUM(tsl.jumlah), 0)   AS qty_keluar_langsung,
            COALESCE(SUM(tsl.subtotal), 0) AS nilai_keluar_langsung
        FROM transaksi_sparepart_langsung tsl
        JOIN transaksi t ON t.id = tsl.transaksi_id
        WHERE DATE(t.tanggal) BETWEEN ? AND ?
        AND t.status = 'lunas'
    ");
    $stmt->bind_param('ss', $dari, $sampai);
    $stmt->execute();
    $keluarLangsung = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    $db->close();
    responseOk('OK', [
        'periode' => ['dari' => $dari, 'sampai' => $sampai],
        'masuk' => [
            'jumlah_pembelian' => (int)$masuk['jumlah_pembelian'],
            'total_qty'        => (int)$masuk['total_qty_masuk'],
            'total_nilai'      => (float)$masuk['total_nilai_masuk'],
        ],
        'keluar' => [
            'qty_servis'       => (int)$keluarServis['qty_keluar_servis'],
            'nilai_servis'     => (float)$keluarServis['nilai_keluar_servis'],
            'qty_langsung'     => (int)$keluarLangsung['qty_keluar_langsung'],
            'nilai_langsung'   => (float)$keluarLangsung['nilai_keluar_langsung'],
            'total_qty'        => (int)$keluarServis['qty_keluar_servis']
                                + (int)$keluarLangsung['qty_keluar_langsung'],
            'total_nilai'      => (float)$keluarServis['nilai_keluar_servis']
                                + (float)$keluarLangsung['nilai_keluar_langsung'],
        ],
    ]);
}

// ── Detail mutasi ─────────────────────────────────────────
// Kumpulkan semua event dalam range, urutkan by tanggal DESC
// Tipe: 'masuk' (pembelian) | 'keluar_servis' | 'keluar_langsung'

$rows = [];

// 1. MASUK — dari pembelian stok
$filterSp = $sparepartId ? 'AND d.sparepart_id = ?' : '';
$sql = "
    SELECT
        p.tanggal                               AS tanggal,
        'masuk'                                 AS tipe,
        sp.id                                   AS sparepart_id,
        sp.kode                                 AS kode,
        sp.nama                                 AS nama_sparepart,
        sp.satuan                               AS satuan,
        d.jumlah                                AS qty,
        d.harga_beli                            AS harga_satuan,
        d.subtotal                              AS nilai,
        p.no_pembelian                          AS referensi,
        COALESCE(p.supplier, '-')               AS keterangan,
        u.nama                                  AS oleh
    FROM pembelian_stok p
    JOIN detail_pembelian_stok d ON d.pembelian_id = p.id
    JOIN sparepart sp             ON sp.id = d.sparepart_id
    JOIN users u                  ON u.id  = p.user_id
    WHERE p.tanggal BETWEEN ? AND ?
    $filterSp
    ORDER BY p.tanggal DESC, p.created_at DESC
";
$stmt = $db->prepare($sql);
if ($sparepartId) {
    $stmt->bind_param('ssi', $dari, $sampai, $sparepartId);
} else {
    $stmt->bind_param('ss', $dari, $sampai);
}
$stmt->execute();
$res = $stmt->get_result();
while ($r = $res->fetch_assoc()) $rows[] = $r;
$res->free(); $stmt->close();

// 2. KELUAR — dari servis (sparepart dipakai)
$filterSp2 = $sparepartId ? 'AND ss.sparepart_id = ?' : '';
$sql = "
    SELECT
        b.tanggal_servis                        AS tanggal,
        'keluar_servis'                         AS tipe,
        sp.id                                   AS sparepart_id,
        sp.kode                                 AS kode,
        sp.nama                                 AS nama_sparepart,
        sp.satuan                               AS satuan,
        ss.jumlah                               AS qty,
        ss.harga_jual                           AS harga_satuan,
        ss.subtotal                             AS nilai,
        b.no_booking                            AS referensi,
        CONCAT(p.nama, ' · ', k.merk, ' ', k.model, ' (', k.no_polisi, ')') AS keterangan,
        m.nama                                  AS oleh
    FROM servis_sparepart ss
    JOIN servis s    ON s.id  = ss.servis_id
    JOIN booking b   ON b.id  = s.booking_id
    JOIN sparepart sp ON sp.id = ss.sparepart_id
    JOIN pelanggan p  ON p.id  = b.pelanggan_id
    JOIN kendaraan k  ON k.id  = b.kendaraan_id
    LEFT JOIN mekanik m ON m.id = s.mekanik_id
    WHERE b.tanggal_servis BETWEEN ? AND ?
    AND s.status = 'selesai'
    AND ss.status_persetujuan = 'disetujui'
    $filterSp2
    ORDER BY b.tanggal_servis DESC
";
$stmt = $db->prepare($sql);
if ($sparepartId) {
    $stmt->bind_param('ssi', $dari, $sampai, $sparepartId);
} else {
    $stmt->bind_param('ss', $dari, $sampai);
}
$stmt->execute();
$res = $stmt->get_result();
while ($r = $res->fetch_assoc()) $rows[] = $r;
$res->free(); $stmt->close();

// 3. KELUAR — dari jual langsung (non-servis)
$filterSp3 = $sparepartId ? 'AND tsl.sparepart_id = ?' : '';
$sql = "
    SELECT
        DATE(t.tanggal)                         AS tanggal,
        'keluar_langsung'                       AS tipe,
        sp.id                                   AS sparepart_id,
        sp.kode                                 AS kode,
        sp.nama                                 AS nama_sparepart,
        sp.satuan                               AS satuan,
        tsl.jumlah                              AS qty,
        tsl.harga_jual                          AS harga_satuan,
        tsl.subtotal                            AS nilai,
        t.no_nota                               AS referensi,
        'Penjualan langsung'                    AS keterangan,
        u.nama                                  AS oleh
    FROM transaksi_sparepart_langsung tsl
    JOIN transaksi t  ON t.id  = tsl.transaksi_id
    JOIN sparepart sp ON sp.id = tsl.sparepart_id
    JOIN users u      ON u.id  = t.kasir_id
    WHERE DATE(t.tanggal) BETWEEN ? AND ?
    AND t.status = 'lunas'
    $filterSp3
    ORDER BY t.tanggal DESC
";
$stmt = $db->prepare($sql);
if ($sparepartId) {
    $stmt->bind_param('ssi', $dari, $sampai, $sparepartId);
} else {
    $stmt->bind_param('ss', $dari, $sampai);
}
$stmt->execute();
$res = $stmt->get_result();
while ($r = $res->fetch_assoc()) $rows[] = $r;
$res->free(); $stmt->close();

$db->close();

// Urutkan semua rows by tanggal DESC
usort($rows, fn($a, $b) => strcmp($b['tanggal'], $a['tanggal']));

// Cast tipe angka
foreach ($rows as &$r) {
    $r['qty']          = (int)$r['qty'];
    $r['harga_satuan'] = (float)$r['harga_satuan'];
    $r['nilai']        = (float)$r['nilai'];
    $r['sparepart_id'] = (int)$r['sparepart_id'];
}
unset($r);

responseOk('OK', [
    'periode' => ['dari' => $dari, 'sampai' => $sampai],
    'total'   => count($rows),
    'mutasi'  => $rows,
]);