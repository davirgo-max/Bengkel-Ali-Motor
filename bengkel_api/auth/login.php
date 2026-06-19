<?php
// auth/login.php
// POST /bengkel_api/auth/login.php
// Body: { "username": "...", "password": "...", "tipe": "user" | "pelanggan" }

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../middleware/auth.php';

setCORSHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    responseError('Method tidak diizinkan', 405);
}

$body     = getRequestBody();
$username = trim($body['username'] ?? '');
$password = trim($body['password'] ?? '');
$tipe     = trim($body['tipe'] ?? 'pelanggan');

if (!$username || !$password) {
    responseError('Username/no_hp dan password wajib diisi');
}

if (!in_array($tipe, ['user', 'pelanggan'])) {
    responseError('Tipe login tidak valid');
}

$db = getDB();

// ---- Login sebagai Kasir / Owner ----
if ($tipe === 'user') {
    $stmt = $db->prepare("
        SELECT id, nama, username, password, role, is_aktif
        FROM users WHERE username = ? LIMIT 1
    ");
    $stmt->bind_param('s', $username);
    $stmt->execute();
    $user = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$user)              responseError('Username atau password salah', 401);
    if (!$user['is_aktif'])  responseError('Akun tidak aktif, hubungi Owner', 403);
    if (!password_verify($password, $user['password']))
                             responseError('Username atau password salah', 401);

    $token = generateToken($user['id'], $user['role'], 'user');
    responseOk('Login berhasil', [
        'token' => $token,
        'role'  => $user['role'],
        'user'  => [
            'id'       => $user['id'],
            'nama'     => $user['nama'],
            'username' => $user['username'],
        ],
    ]);
}

// ---- Login sebagai Pelanggan (no_hp atau email) ----
if ($tipe === 'pelanggan') {
    $stmt = $db->prepare("
        SELECT id, nama, no_hp, email, password, is_aktif, is_diblokir, blokir_sampai
        FROM pelanggan WHERE no_hp = ? OR email = ? LIMIT 1
    ");
    $stmt->bind_param('ss', $username, $username);
    $stmt->execute();
    $pelanggan = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$pelanggan)               responseError('No HP/email atau password salah', 401);
    if (!$pelanggan['is_aktif'])   responseError('Akun tidak aktif', 403);
    if ($pelanggan['is_diblokir']) {
        $sampai = $pelanggan['blokir_sampai']
            ? ' sampai ' . date('d/m/Y', strtotime($pelanggan['blokir_sampai']))
            : ' secara permanen';
        responseError('Akun Anda diblokir' . $sampai . '. Hubungi bengkel untuk informasi lebih lanjut.', 403);
    }
    if (!password_verify($password, $pelanggan['password']))
                                   responseError('No HP/email atau password salah', 401);

    $token = generateToken($pelanggan['id'], 'pelanggan', 'pelanggan');
    responseOk('Login berhasil', [
        'token' => $token,
        'role'  => 'pelanggan',
        'user'  => [
            'id'    => $pelanggan['id'],
            'nama'  => $pelanggan['nama'],
            'no_hp' => $pelanggan['no_hp'],
            'email' => $pelanggan['email'],
        ],
    ]);
}

$db->close();