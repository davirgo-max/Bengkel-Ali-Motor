<?php
// pelanggan/sparepart.php
// GET /bengkel_api/pelanggan/sparepart.php          → list semua sparepart aktif
// GET /bengkel_api/pelanggan/sparepart.php?id=1     → detail 1 sparepart
// GET /bengkel_api/pelanggan/sparepart.php?search=oli → search by nama/kode
// GET /bengkel_api/pelanggan/sparepart.php?kategori_id=1 → filter kategori

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../middleware/auth.php';

setCORSHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    responseError('Method tidak diizinkan', 405);
}

// Endpoint ini boleh diakses pelanggan, dan kasir (mode lihat saja --
// info suku cadang di Aksi Cepat kasir memakai endpoint yang sama persis)
requireRole('pelanggan', 'kasir');

$db = getDB();

// ── Detail 1 sparepart ────────────────────────────────────
if (isset($_GET['id'])) {
    $id = (int)$_GET['id'];
    $stmt = $db->prepare("
        SELECT s.id, s.kode, s.nama, s.deskripsi, s.satuan,
               s.harga_jual, s.stok, s.foto, s.is_aktif,
               k.nama AS kategori
        FROM sparepart s
        LEFT JOIN kategori_sparepart k ON k.id = s.kategori_id
        WHERE s.id = ? AND s.is_aktif = 1
        LIMIT 1
    ");
    $stmt->bind_param('i', $id);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$row) responseError('Sparepart tidak ditemukan', 404);

    $row['tersedia'] = $row['stok'] > 0;
    responseOk('OK', $row);
}

// ── List / Search / Filter ────────────────────────────────
$where  = ['s.is_aktif = 1'];
$params = [];
$types  = '';

if (!empty($_GET['search'])) {
    $keyword = '%' . $_GET['search'] . '%';
    $where[]  = '(s.nama LIKE ? OR s.kode LIKE ?)';
    $params[] = $keyword;
    $params[] = $keyword;
    $types   .= 'ss';
}

if (!empty($_GET['kategori_id'])) {
    $where[]  = 's.kategori_id = ?';
    $params[] = (int)$_GET['kategori_id'];
    $types   .= 'i';
}

$whereSQL = implode(' AND ', $where);

$sql = "
    SELECT s.id, s.kode, s.nama, s.satuan,
           s.harga_jual, s.stok, s.foto,
           k.nama AS kategori,
           (s.stok > 0) AS tersedia
    FROM sparepart s
    LEFT JOIN kategori_sparepart k ON k.id = s.kategori_id
    WHERE $whereSQL
    ORDER BY k.nama, s.nama
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
while ($row = $result->fetch_assoc()) {
    $row['tersedia'] = (bool)$row['tersedia'];
    $rows[] = $row;
}

// Ambil juga list kategori untuk filter di Flutter
$kategoriResult = $db->query("SELECT id, nama FROM kategori_sparepart ORDER BY nama");
$kategori = [];
while ($k = $kategoriResult->fetch_assoc()) $kategori[] = $k;

responseOk('OK', [
    'sparepart' => $rows,
    'kategori'  => $kategori,
    'total'     => count($rows),
]);

$db->close();