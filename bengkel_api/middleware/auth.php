<?php
// middleware/auth.php
// Token sederhana berbasis hash (tanpa library JWT eksternal)
// Cocok untuk skripsi dengan XAMPP lokal

require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/database.php';

define('TOKEN_SECRET', 'bengkel_ali_secret_2026');  // ganti saat production
define('TOKEN_EXPIRE', 60 * 60 * 24 * 7);           // 7 hari dalam detik

// ---------- Generate token ----------
function generateToken(int $userId, string $role, string $tipe): string {
    $payload = $userId . '|' . $role . '|' . $tipe . '|' . (time() + TOKEN_EXPIRE);
    $signature = hash_hmac('sha256', $payload, TOKEN_SECRET);
    return base64_encode($payload . '.' . $signature);
}

// ---------- Validasi token ----------
function validateToken(string $token): array|false {
    $decoded = base64_decode($token);
    if (!$decoded) return false;

    $lastDot = strrpos($decoded, '.');
    if ($lastDot === false) return false;

    $payload   = substr($decoded, 0, $lastDot);
    $signature = substr($decoded, $lastDot + 1);

    // Cek signature
    $expected = hash_hmac('sha256', $payload, TOKEN_SECRET);
    if (!hash_equals($expected, $signature)) return false;

    // Cek expired
    $parts = explode('|', $payload);
    if (count($parts) !== 4) return false;

    [$userId, $role, $tipe, $expire] = $parts;
    if (time() > (int)$expire) return false;

    return [
        'user_id' => (int)$userId,
        'role'    => $role,
        'tipe'    => $tipe,   // 'user' (kasir/owner) atau 'pelanggan'
    ];
}

// ---------- Middleware: wajib login ----------
function requireAuth(): array {
    $headers = getallheaders();
    $authHeader = $headers['Authorization'] ?? $headers['authorization'] ?? '';

    if (!str_starts_with($authHeader, 'Bearer ')) {
        responseError('Token tidak ditemukan', 401);
    }

    $token = substr($authHeader, 7);
    $data  = validateToken($token);

    if (!$data) {
        responseError('Token tidak valid atau sudah expired', 401);
    }

    return $data;
}

// ---------- Middleware: cek role tertentu ----------
function requireRole(string ...$roles): array {
    $auth = requireAuth();
    if (!in_array($auth['role'], $roles)) {
        responseError('Akses ditolak untuk role ' . $auth['role'], 403);
    }
    return $auth;
}
