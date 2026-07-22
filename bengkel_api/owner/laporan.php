<?php
// owner/laporan.php
// GET ?tipe=servis|sparepart|keuangan
//     &periode=hari_ini|minggu_ini|bulan_ini|custom
//     &tgl_mulai=YYYY-MM-DD&tgl_selesai=YYYY-MM-DD

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../middleware/auth.php';

setCORSHeaders();
if ($_SERVER['REQUEST_METHOD'] !== 'GET') responseError('Method tidak diizinkan', 405);

requireRole('owner');
$db = getDB();

// ── Hitung range tanggal ──────────────────────────────────
$periode    = $_GET['periode']    ?? 'hari_ini';
$tglMulai   = $_GET['tgl_mulai']  ?? null;
$tglSelesai = $_GET['tgl_selesai']?? null;

if ($periode === 'custom' && $tglMulai && $tglSelesai) {
    // pakai range custom
} else {
    switch ($periode) {
        case 'minggu_ini':
            $tglMulai   = date('Y-m-d', strtotime('monday this week'));
            $tglSelesai = date('Y-m-d', strtotime('sunday this week'));
            break;
        case 'bulan_ini':
            $tglMulai   = date('Y-m-01');
            $tglSelesai = date('Y-m-t');
            break;
        default: // hari_ini
            $tglMulai   = date('Y-m-d');
            $tglSelesai = date('Y-m-d');
    }
}

$tipe = trim($_GET['tipe'] ?? 'servis');

// ── LAPORAN SERVIS ────────────────────────────────────────
if ($tipe === 'servis') {
    // Ringkasan
    $stmt = $db->prepare("
        SELECT
            COUNT(DISTINCT s.id)                                        AS total_servis,
            SUM(s.status = 'selesai')                                   AS selesai,
            SUM(b.status = 'no_show')                                   AS no_show,
            SUM(b.status = 'dibatalkan')                                AS dibatalkan,
            COALESCE(SUM(CASE WHEN s.status='selesai'
                THEN js.harga_jasa END), 0)                             AS total_pendapatan_jasa
        FROM booking b
        LEFT JOIN servis s        ON s.booking_id = b.id
        LEFT JOIN jenis_servis js ON js.id = b.jenis_servis_id
        WHERE b.tanggal_servis BETWEEN ? AND ?
    ");
    $stmt->bind_param('ss', $tglMulai, $tglSelesai);
    $stmt->execute();
    $ringkasan = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    // Detail per servis
    $stmt = $db->prepare("
        SELECT s.id, b.no_booking, b.tanggal_servis, b.tipe,
               p.nama AS nama_pelanggan,
               k.merk, k.model, k.no_polisi,
               js.nama AS jenis_servis, js.harga_jasa,
               m.nama AS nama_mekanik,
               s.status,
               s.waktu_mulai, s.waktu_selesai,
               COALESCE(SUM(ss.subtotal), 0) AS total_sparepart,
               COALESCE(js.harga_jasa, 0) + COALESCE(SUM(ss.subtotal), 0) AS total_biaya
        FROM booking b
        JOIN pelanggan p  ON p.id = b.pelanggan_id
        JOIN kendaraan k  ON k.id = b.kendaraan_id
        LEFT JOIN servis s        ON s.booking_id = b.id
        LEFT JOIN jenis_servis js ON js.id = b.jenis_servis_id
        LEFT JOIN mekanik m       ON m.id = s.mekanik_id
        LEFT JOIN servis_sparepart ss ON ss.servis_id = s.id
        WHERE b.tanggal_servis BETWEEN ? AND ?
        AND b.status NOT IN ('dibatalkan')
        GROUP BY s.id, b.id
        ORDER BY b.tanggal_servis DESC, b.created_at DESC
    ");
    $stmt->bind_param('ss', $tglMulai, $tglSelesai);
    $stmt->execute();
    $result = $stmt->get_result();
    $detail = [];
    while ($r = $result->fetch_assoc()) $rows[] = $r;
    $result->free();
    $stmt->close();

    $db->close();
    responseOk('OK', [
        'tipe'      => 'servis',
        'periode'   => ['mulai' => $tglMulai, 'selesai' => $tglSelesai],
        'ringkasan' => $ringkasan,
        'detail'    => $detail,
    ]);
}

// ── LAPORAN SPAREPART ─────────────────────────────────────
if ($tipe === 'sparepart') {
    // Sparepart terjual (dari servis + penjualan langsung)
    $stmt = $db->prepare("
        SELECT sp.id, sp.kode, sp.nama, sp.satuan,
               sp.harga_beli, sp.harga_jual, sp.stok,
               COALESCE(SUM(ss.jumlah), 0)    AS terjual_servis,
               COALESCE(SUM(ss.subtotal), 0)  AS pendapatan_servis
        FROM sparepart sp
        LEFT JOIN servis_sparepart ss ON ss.sparepart_id = sp.id
        LEFT JOIN servis s            ON s.id = ss.servis_id
        LEFT JOIN booking b           ON b.id = s.booking_id
        WHERE (b.tanggal_servis BETWEEN ? AND ? OR ss.id IS NULL)
        AND sp.is_aktif = 1
        GROUP BY sp.id
        ORDER BY terjual_servis DESC
    ");
    $stmt->bind_param('ss', $tglMulai, $tglSelesai);
    $stmt->execute();
    $result = $stmt->get_result();
    $rows = [];
    while ($r = $result->fetch_assoc()) {
        $terjual     = (int)$r['terjual_servis'];
        $pendapatan  = (float)$r['pendapatan_servis'];
        $hpp         = $terjual * (float)$r['harga_beli'];
        $r['terjual']    = $terjual;
        $r['pendapatan'] = $pendapatan;
        $r['hpp']        = $hpp;
        $r['laba']       = $pendapatan - $hpp;
        $rows[] = $r;
    }
    $result->free();
    $stmt->close();

    // Stok menipis
    $menipis = [];
    $res = $db->query("
        SELECT id, kode, nama, satuan, stok, stok_minimum
        FROM sparepart
        WHERE stok <= stok_minimum AND is_aktif=1
        ORDER BY stok ASC
    ");
    while ($r = $res->fetch_assoc()) $menipis[] = $r;

    // Ringkasan
    $totalTerjual   = array_sum(array_column($rows, 'terjual'));
    $totalPendapatan = array_sum(array_column($rows, 'pendapatan'));
    $totalHPP       = array_sum(array_column($rows, 'hpp'));

    $db->close();
    responseOk('OK', [
        'tipe'    => 'sparepart',
        'periode' => ['mulai' => $tglMulai, 'selesai' => $tglSelesai],
        'ringkasan' => [
            'total_terjual'    => $totalTerjual,
            'total_pendapatan' => $totalPendapatan,
            'total_hpp'        => $totalHPP,
            'total_laba'       => $totalPendapatan - $totalHPP,
            'item_habis'       => count(array_filter($rows,
                fn($r) => $r['stok'] == 0)),
        ],
        'detail'  => $rows,
        'stok_menipis' => $menipis,
    ]);
}

// ── LAPORAN KEUANGAN ──────────────────────────────────────
if ($tipe === 'keuangan') {
    // Rekap dari transaksi
    $stmt = $db->prepare("
        SELECT
            COALESCE(SUM(grand_total), 0)                                          AS total_pemasukan,
            COALESCE(SUM(total_jasa), 0)                                           AS pemasukan_jasa,
            COALESCE(SUM(total_sparepart), 0)                                      AS pemasukan_sparepart,
            COALESCE(SUM(diskon), 0)                                               AS total_diskon,
            COALESCE(SUM(CASE WHEN metode_bayar='cash'     THEN grand_total END), 0) AS cash,
            COALESCE(SUM(CASE WHEN metode_bayar='transfer' THEN grand_total END), 0) AS transfer,
            COUNT(*) AS jumlah_transaksi
        FROM transaksi
        WHERE DATE(tanggal) BETWEEN ? AND ?
        AND status = 'lunas'
    ");
    $stmt->bind_param('ss', $tglMulai, $tglSelesai);
    $stmt->execute();
    $ringkasan = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    // HPP sparepart terjual
    $stmt = $db->prepare("
        SELECT COALESCE(SUM(sp.harga_beli * ss.jumlah), 0) AS total_hpp
        FROM servis_sparepart ss
        JOIN sparepart sp ON sp.id = ss.sparepart_id
        JOIN servis s     ON s.id  = ss.servis_id
        JOIN booking b    ON b.id  = s.booking_id
        WHERE b.tanggal_servis BETWEEN ? AND ?
        AND s.status = 'selesai'
    ");
    $stmt->bind_param('ss', $tglMulai, $tglSelesai);
    $stmt->execute();
    $hpp = (float)$stmt->get_result()->fetch_assoc()['total_hpp'];
    $stmt->close();

    $db->close();
    responseOk('OK', [
        'tipe'    => 'keuangan',
        'periode' => ['mulai' => $tglMulai, 'selesai' => $tglSelesai],
        'ringkasan' => array_merge($ringkasan, [
            'hpp_sparepart' => $hpp,
            'laba_kotor'    => (float)$ringkasan['total_pemasukan'] - $hpp,
        ]),
    ]);
}

responseError('Tipe laporan tidak valid. Gunakan: servis, sparepart, atau keuangan');