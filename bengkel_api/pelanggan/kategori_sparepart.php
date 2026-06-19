<?php
// pelanggan/kategori_sparepart.php
// GET → daftar kategori sparepart yang memiliki minimal 1 sparepart aktif
// Dipakai untuk dropdown filter di form booking pelanggan.

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../middleware/auth.php';

setCORSHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    responseError('Method tidak diizinkan', 405);
}

requireRole('pelanggan');
$db = getDB();

// Hanya tampilkan kategori yang punya minimal 1 sparepart aktif & stok > 0
// agar dropdown filter tidak menampilkan kategori kosong
$result = $db->query("
    SELECT DISTINCT ks.id, ks.nama
    FROM kategori_sparepart ks
    INNER JOIN sparepart sp ON sp.kategori_id = ks.id
    WHERE sp.is_aktif = 1 AND sp.stok > 0
    ORDER BY ks.nama ASC
");

$rows = [];
while ($row = $result->fetch_assoc()) {
    $rows[] = ['id' => (int)$row['id'], 'nama' => $row['nama']];
}

$db->close();
responseOk('OK', $rows);