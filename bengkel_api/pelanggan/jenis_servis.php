<?php
// pelanggan/jenis_servis.php
// GET → list jenis servis aktif (untuk dropdown saat booking)

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../middleware/auth.php';

setCORSHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'GET') responseError('Method tidak diizinkan', 405);

requireRole('pelanggan', 'kasir');
$db = getDB();

$result = $db->query("
    SELECT id, nama, deskripsi, harga_jasa, estimasi_menit
    FROM jenis_servis
    WHERE is_aktif = 1
    ORDER BY nama
");
$rows = [];
while ($row = $result->fetch_assoc()) $rows[] = $row;
$db->close();

responseOk('OK', $rows);
