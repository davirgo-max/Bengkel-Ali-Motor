<?php
// admin/akun_owner.php
// GET  → ambil info akun owner (nama, username). Owner hanya ada 1.
// PUT  {password_baru} → reset password owner

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../middleware/auth.php';

setCORSHeaders();
requireRole('admin');
$db = getDB();

// ── GET: info owner ───────────────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $result = $db->query("
        SELECT id, nama, username, role, created_at
        FROM users
        WHERE role = 'owner'
        LIMIT 1
    ");
    $owner = $result->fetch_assoc();
    $db->close();

    if (!$owner) {
        responseError('Akun owner tidak ditemukan', 404);
    }
    responseOk('OK', $owner);
}

// ── PUT: reset password owner ─────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'PUT') {
    $body     = getRequestBody();
    $passBaru = trim($body['password_baru'] ?? '');

    if (strlen($passBaru) < 6) {
        responseError('Password baru minimal 6 karakter');
    }

    $hash = password_hash($passBaru, PASSWORD_BCRYPT);
    $stmt = $db->prepare("UPDATE users SET password = ? WHERE role = 'owner' LIMIT 1");
    $stmt->bind_param('s', $hash);
    if (!$stmt->execute() || $stmt->affected_rows === 0) {
        $stmt->close(); $db->close();
        responseError('Gagal mereset password owner', 500);
    }
    $stmt->close();
    $db->close();
    responseOk('Password owner berhasil direset');
}

responseError('Method tidak diizinkan', 405);
