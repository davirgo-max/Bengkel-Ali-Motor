<?php
// admin/stok_menipis.php
// GET                  → list sparepart stok menipis / habis
// GET ?count_only=1    → hanya return jumlah (untuk dashboard)

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../middleware/auth.php';

setCORSHeaders();
if ($_SERVER['REQUEST_METHOD'] !== 'GET') responseError('Method tidak diizinkan', 405);

requireRole('admin', 'kasir');
$db = getDB();

// Count only — untuk dashboard widget
if (!empty($_GET['count_only'])) {
    $row = $db->query("
        SELECT COUNT(*) AS total FROM sparepart
        WHERE stok <= stok_minimum AND is_aktif = 1
    ")->fetch_assoc();
    $db->close();
    responseOk('OK', ['total' => (int)$row['total']]);
}

// List lengkap
$result = $db->query("
    SELECT s.id, s.kode, s.nama, s.satuan,
           s.stok, s.stok_minimum,
           k.nama AS kategori,
           (s.stok = 0) AS habis
    FROM sparepart s
    LEFT JOIN kategori_sparepart k ON k.id = s.kategori_id
    WHERE s.stok <= s.stok_minimum AND s.is_aktif = 1
    ORDER BY s.stok ASC, s.nama ASC
");

$rows   = [];
$habis  = 0;
$menipis = 0;
while ($r = $result->fetch_assoc()) {
    $r['habis'] = (bool)$r['habis'];
    if ($r['habis']) $habis++;
    else             $menipis++;
    $rows[] = $r;
}
$db->close();

responseOk('OK', [
    'total'   => count($rows),
    'habis'   => $habis,
    'menipis' => $menipis,
    'items'   => $rows,
]);