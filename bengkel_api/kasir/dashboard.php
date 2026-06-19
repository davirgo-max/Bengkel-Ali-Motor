<?php
// kasir/dashboard.php
// GET → ringkasan hari ini: booking, servis, kas, pemasukan

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../middleware/auth.php';

setCORSHeaders();
if ($_SERVER['REQUEST_METHOD'] !== 'GET') responseError('Method tidak diizinkan', 405);

requireRole('kasir', 'owner');
$db      = getDB();
$tanggal = $_GET['tanggal'] ?? date('Y-m-d');

// ── Ringkasan booking hari ini ────────────────────────────
$stmt = $db->prepare("
    SELECT
        COUNT(*) AS total,
        SUM(status = 'menunggu')     AS menunggu,
        SUM(status = 'dikonfirmasi') AS dikonfirmasi,
        SUM(status = 'aktif')        AS aktif,
        SUM(status = 'selesai')      AS selesai,
        SUM(status = 'no_show')      AS no_show,
        SUM(status = 'dibatalkan')   AS dibatalkan
    FROM booking WHERE tanggal_servis = ?
");
$stmt->bind_param('s', $tanggal);
$stmt->execute();
$booking = $stmt->get_result()->fetch_assoc();
$stmt->close();

// ── Ringkasan servis aktif ────────────────────────────────
$stmt = $db->prepare("
    SELECT
        COUNT(*) AS total,
        SUM(s.status = 'antrian')        AS antrian,
        SUM(s.status = 'dikerjakan')     AS dikerjakan,
        SUM(s.status = 'menunggu_part')  AS menunggu_part,
        SUM(s.status = 'selesai_servis') AS selesai_servis
    FROM servis s
    JOIN booking b ON b.id = s.booking_id
    WHERE b.tanggal_servis = ?
    AND s.status != 'selesai'
");
$stmt->bind_param('s', $tanggal);
$stmt->execute();
$servis = $stmt->get_result()->fetch_assoc();
$stmt->close();

// ── Kas harian ────────────────────────────────────────────
$stmt = $db->prepare("
    SELECT id, status, kas_awal, kas_akhir_sistem,
           kas_akhir_fisik, selisih, total_pemasukan,
           catatan_kasir, ditutup_at
    FROM kas_harian WHERE tanggal = ? LIMIT 1
");
$stmt->bind_param('s', $tanggal);
$stmt->execute();
$kas = $stmt->get_result()->fetch_assoc();
$stmt->close();

// ── Total pemasukan dari transaksi ────────────────────────
$stmt = $db->prepare("
    SELECT
        COALESCE(SUM(grand_total), 0) AS total,
        COALESCE(SUM(CASE WHEN metode_bayar='cash' THEN grand_total END), 0) AS cash,
        COALESCE(SUM(CASE WHEN metode_bayar='transfer' THEN grand_total END), 0) AS transfer,
        COUNT(*) AS jumlah_transaksi
    FROM transaksi WHERE DATE(tanggal) = ?
");
$stmt->bind_param('s', $tanggal);
$stmt->execute();
$pemasukan = $stmt->get_result()->fetch_assoc();
$stmt->close();

// ── Servis selesai belum bayar ────────────────────────────
$stmt = $db->prepare("
    SELECT COUNT(*) AS total
    FROM servis s
    JOIN booking b ON b.id = s.booking_id
    WHERE b.tanggal_servis = ?
    AND s.status = 'selesai_servis'
");
$stmt->bind_param('s', $tanggal);
$stmt->execute();
$menungguBayar = (int)$stmt->get_result()->fetch_assoc()['total'];
$stmt->close();

$db->close();

responseOk('OK', [
    'tanggal'         => $tanggal,
    'booking'         => $booking,
    'servis'          => $servis,
    'kas'             => $kas,
    'pemasukan'       => $pemasukan,
    'menunggu_bayar'  => $menungguBayar,
]);