<?php
// admin/sparepart_upload.php
// POST multipart/form-data: foto (file) + sparepart_id
// → upload gambar, simpan nama file ke DB, return URL

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../middleware/auth.php';

setCORSHeaders();
if ($_SERVER['REQUEST_METHOD'] !== 'POST') responseError('Method tidak diizinkan', 405);

requireRole('admin');

$sparepartId = (int)($_POST['sparepart_id'] ?? 0);
if (!$sparepartId) responseError('sparepart_id wajib diisi');

if (!isset($_FILES['foto']) || $_FILES['foto']['error'] !== UPLOAD_ERR_OK) {
    responseError('File foto tidak ditemukan atau gagal diupload');
}

$file      = $_FILES['foto'];
$maxSize   = 2 * 1024 * 1024; // 2 MB
$allowedExt = ['jpg','jpeg','png','webp'];

// Validasi ukuran
if ($file['size'] > $maxSize) responseError('Ukuran file maksimal 2 MB');

// Validasi ekstensi
$ext = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
if (!in_array($ext, $allowedExt)) {
    responseError('Format file harus JPG, PNG, atau WebP');
}

// Validasi MIME type (lebih aman dari ekstensi saja)
$finfo    = finfo_open(FILEINFO_MIME_TYPE);
$mimeType = finfo_file($finfo, $file['tmp_name']);
finfo_close($finfo);
$allowedMime = ['image/jpeg','image/png','image/webp'];
if (!in_array($mimeType, $allowedMime)) {
    responseError('Tipe file tidak valid');
}

// Generate nama file unik
$namaFile  = 'sp_' . $sparepartId . '_' . time() . '.' . $ext;
$uploadDir = __DIR__ . '/../uploads/sparepart/';
$uploadPath = $uploadDir . $namaFile;

// Pastikan folder ada
if (!is_dir($uploadDir)) mkdir($uploadDir, 0755, true);

// Hapus foto lama jika ada
$db   = getDB();
$stmt = $db->prepare("SELECT foto FROM sparepart WHERE id=? LIMIT 1");
$stmt->bind_param('i', $sparepartId);
$stmt->execute();
$old = $stmt->get_result()->fetch_assoc();
$stmt->close();

if ($old && $old['foto']) {
    $oldPath = $uploadDir . $old['foto'];
    if (file_exists($oldPath)) unlink($oldPath);
}

// Upload file
if (!move_uploaded_file($file['tmp_name'], $uploadPath)) {
    responseError('Gagal menyimpan file ke server', 500);
}

// Update kolom foto di DB
$stmt = $db->prepare("UPDATE sparepart SET foto=? WHERE id=?");
$stmt->bind_param('si', $namaFile, $sparepartId);
$stmt->execute(); $stmt->close();
$db->close();

// Bangun URL untuk dikembalikan ke Flutter
$protocol = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
$host     = $_SERVER['HTTP_HOST'];
$fotoUrl  = "$protocol://$host/bengkel_api/uploads/sparepart/$namaFile";

responseOk('Foto berhasil diupload', [
    'nama_file' => $namaFile,
    'url'       => $fotoUrl,
]);