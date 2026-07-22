<?php
// auth/register.php
// POST /bengkel_api/auth/register.php
// Body: { "nama": "...", "no_hp": "...", "email": "...", "password": "...", "alamat": "..." }

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/response.php';

setCORSHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    responseError('Method tidak diizinkan', 405);
}

$body     = getRequestBody();
$nama     = trim($body['nama']     ?? '');
$no_hp    = trim($body['no_hp']    ?? '');
$email    = trim($body['email']    ?? '');
$password = trim($body['password'] ?? '');
$alamat   = trim($body['alamat']   ?? '');

// Validasi wajib
if (!$nama || !$no_hp || !$email || !$password) {
    responseError('Nama, no HP, email, dan password wajib diisi');
}

if (strlen($password) < 6) {
    responseError('Password minimal 6 karakter');
}

if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    responseError('Format email tidak valid');
}

$db = getDB();

// Cek no_hp sudah terdaftar
$stmt = $db->prepare("SELECT id FROM pelanggan WHERE no_hp = ? LIMIT 1");
$stmt->bind_param('s', $no_hp);
$stmt->execute();
if ($stmt->get_result()->num_rows > 0) {
    $stmt->close();
    responseError('No HP sudah terdaftar');
}
$stmt->close();

// Cek email sudah terdaftar (jika diisi)
if ($email) {
    $stmt = $db->prepare("SELECT id FROM pelanggan WHERE email = ? LIMIT 1");
    $stmt->bind_param('s', $email);
    $stmt->execute();
    if ($stmt->get_result()->num_rows > 0) {
        $stmt->close();
        responseError('Email sudah terdaftar');
    }
    $stmt->close();
}

$hashedPassword = password_hash($password, PASSWORD_BCRYPT);
$emailVal = $email ?: null;
$alamatVal = $alamat ?: null;

$stmt = $db->prepare("
    INSERT INTO pelanggan (nama, no_hp, email, password, alamat)
    VALUES (?, ?, ?, ?, ?)
");
$stmt->bind_param('sssss', $nama, $no_hp, $emailVal, $hashedPassword, $alamatVal);

if (!$stmt->execute()) {
    responseError('Gagal mendaftar, coba lagi', 500);
}

$newId = $stmt->insert_id;
$stmt->close();
$db->close();

responseOk('Registrasi berhasil', ['pelanggan_id' => $newId]);
