<?php
// auth/me.php
// GET /bengkel_api/auth/me.php
// Header: Authorization: Bearer <token>
// Dipakai Flutter saat app dibuka ulang untuk cek token masih valid

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../middleware/auth.php';

setCORSHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    responseError('Method tidak diizinkan', 405);
}

$auth = requireAuth();
$db   = getDB();

if ($auth['tipe'] === 'user') {
    $stmt = $db->prepare("SELECT id, nama, username, role FROM users WHERE id = ? LIMIT 1");
    $stmt->bind_param('i', $auth['user_id']);
    $stmt->execute();
    $user = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$user) responseError('User tidak ditemukan', 404);

    responseOk('OK', [
        'token_valid' => true,
        'role'        => $user['role'],
        'user'        => $user,
    ]);
}

if ($auth['tipe'] === 'pelanggan') {
    $stmt = $db->prepare("SELECT id, nama, no_hp, email FROM pelanggan WHERE id = ? LIMIT 1");
    $stmt->bind_param('i', $auth['user_id']);
    $stmt->execute();
    $pelanggan = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$pelanggan) responseError('Pelanggan tidak ditemukan', 404);

    responseOk('OK', [
        'token_valid' => true,
        'role'        => 'pelanggan',
        'user'        => $pelanggan,
    ]);
}

$db->close();
