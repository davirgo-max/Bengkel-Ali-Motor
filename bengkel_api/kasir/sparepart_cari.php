<?php
// kasir/sparepart_cari.php
// GET ?search=X          → cari sparepart by nama/kode (untuk dropdown tambah part)
// GET ?id=X              → detail 1 sparepart
// GET                    → list semua sparepart aktif (tanpa search)

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../middleware/auth.php';

setCORSHeaders();
if ($_SERVER['REQUEST_METHOD'] !== 'GET') responseError('Method tidak diizinkan', 405);

requireRole('kasir', 'owner');
$db = getDB();

// ── Detail 1 sparepart ────────────────────────────────────
if (isset($_GET['id'])) {
    $id   = (int)$_GET['id'];
    $stmt = $db->prepare("
        SELECT s.id, s.kode, s.nama, s.satuan,
               s.harga_beli, s.harga_jual, s.stok,
               s.stok_minimum, k.nama AS kategori
        FROM sparepart s
        LEFT JOIN kategori_sparepart k ON k.id = s.kategori_id
        WHERE s.id = ? AND s.is_aktif = 1 LIMIT 1
    ");
    $stmt->bind_param('i', $id);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    $db->close();

    if (!$row) responseError('Sparepart tidak ditemukan', 404);
    responseOk('OK', $row);
}

// ── Cari / list sparepart ─────────────────────────────────
$search     = trim($_GET['search']      ?? '');
$kategoriId = !empty($_GET['kategori_id']) ? (int)$_GET['kategori_id'] : null;
$stokAda    = isset($_GET['stok_ada'])  ? (bool)$_GET['stok_ada'] : false;

$where  = ['s.is_aktif = 1'];
$params = [];
$types  = '';

if ($search) {
    $keyword  = '%' . $search . '%';
    $where[]  = '(s.nama LIKE ? OR s.kode LIKE ?)';
    $params[] = $keyword;
    $params[] = $keyword;
    $types   .= 'ss';
}

if ($kategoriId) {
    $where[]  = 's.kategori_id = ?';
    $params[] = $kategoriId;
    $types   .= 'i';
}

if ($stokAda) {
    $where[] = 's.stok > 0';
}

$whereSQL = implode(' AND ', $where);
$sql = "
    SELECT s.id, s.kode, s.nama, s.satuan,
           s.harga_jual, s.stok, s.stok_minimum,
           k.nama AS kategori,
           (s.stok > 0) AS tersedia,
           (s.stok <= s.stok_minimum) AS stok_menipis
    FROM sparepart s
    LEFT JOIN kategori_sparepart k ON k.id = s.kategori_id
    WHERE $whereSQL
    ORDER BY k.nama, s.nama
    LIMIT 30
";

if ($types) {
    $stmt = $db->prepare($sql);
    $stmt->bind_param($types, ...$params);
    $stmt->execute();
    $result = $stmt->get_result();
} else {
    $result = $db->query($sql);
}

$rows = [];
while ($r = $result->fetch_assoc()) {
    $r['tersedia']     = (bool)$r['tersedia'];
    $r['stok_menipis'] = (bool)$r['stok_menipis'];
    $rows[] = $r;
}

if (isset($stmt)) $stmt->close();
$db->close();

responseOk('OK', $rows);
