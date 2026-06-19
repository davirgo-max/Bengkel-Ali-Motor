<?php
// pelanggan/cek_kuota.php
// GET ?tanggal=YYYY-MM-DD → cek sisa slot booking di tanggal tertentu

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../middleware/auth.php';

setCORSHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'GET') responseError('Method tidak diizinkan', 405);

requireRole('pelanggan');

$tanggal = trim($_GET['tanggal'] ?? '');
if (!$tanggal) responseError('Parameter tanggal wajib diisi');
if ($tanggal < date('Y-m-d')) responseError('Tanggal tidak boleh masa lalu');

$db = getDB();

$stmt = $db->prepare("SELECT kuota_booking_harian FROM pengaturan_bengkel WHERE id = 1");
$stmt->execute();
$kuota = $stmt->get_result()->fetch_assoc()['kuota_booking_harian'] ?? 10;
$stmt->close();

$stmt = $db->prepare("
    SELECT COUNT(*) AS terpakai FROM booking
    WHERE tanggal_servis = ?
    AND status NOT IN ('dibatalkan','no_show')
");
$stmt->bind_param('s', $tanggal);
$stmt->execute();
$terpakai = $stmt->get_result()->fetch_assoc()['terpakai'];
$stmt->close();
$db->close();

$sisa = max(0, $kuota - $terpakai);

responseOk('OK', [
    'tanggal'  => $tanggal,
    'kuota'    => $kuota,
    'terpakai' => (int)$terpakai,
    'sisa'     => $sisa,
    'penuh'    => $sisa === 0,
]);
