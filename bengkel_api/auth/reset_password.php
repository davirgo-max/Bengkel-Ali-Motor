<?php
// auth/reset_password.php
// POST { "identifier": "081234...", "otp": "123456", "password_baru": "abc123" }

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(204); exit; }

require_once __DIR__ . '/../config/db.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Method not allowed']);
    exit;
}

$body         = json_decode(file_get_contents('php://input'), true) ?? [];
$identifier   = trim($body['identifier'] ?? '');
$otp          = trim($body['otp'] ?? '');
$passwordBaru = trim($body['password_baru'] ?? '');

// ── Validasi input ────────────────────────────────────────────────────────
if ($identifier === '' || $otp === '' || $passwordBaru === '') {
    echo json_encode(['success' => false, 'message' => 'Semua field wajib diisi']);
    exit;
}

if (strlen($otp) !== 6 || !ctype_digit($otp)) {
    echo json_encode(['success' => false, 'message' => 'Format OTP tidak valid']);
    exit;
}

if (strlen($passwordBaru) < 6) {
    echo json_encode(['success' => false, 'message' => 'Password minimal 6 karakter']);
    exit;
}

// ── Cari pelanggan ────────────────────────────────────────────────────────
$stmtP = $pdo->prepare(
    "SELECT id FROM pelanggan
     WHERE (no_hp = :id OR email = :id) AND is_aktif = 1
     LIMIT 1"
);
$stmtP->execute([':id' => $identifier]);
$pelanggan = $stmtP->fetch(PDO::FETCH_ASSOC);

if (!$pelanggan) {
    echo json_encode(['success' => false, 'message' => 'Akun tidak ditemukan']);
    exit;
}

$pelangganId = $pelanggan['id'];

// ── Verifikasi OTP ────────────────────────────────────────────────────────
$stmtOtp = $pdo->prepare(
    "SELECT id FROM password_reset_tokens
     WHERE pelanggan_id = :pid
       AND token        = :token
       AND is_used      = 0
       AND expired_at   > NOW()
     LIMIT 1"
);
$stmtOtp->execute([':pid' => $pelangganId, ':token' => $otp]);
$tokenRow = $stmtOtp->fetch(PDO::FETCH_ASSOC);

if (!$tokenRow) {
    echo json_encode(['success' => false, 'message' => 'OTP tidak valid atau sudah kadaluarsa']);
    exit;
}

// ── Update password & tandai token sudah dipakai (transaksi) ─────────────
try {
    $pdo->beginTransaction();

    // Update password pelanggan
    $hash = password_hash($passwordBaru, PASSWORD_BCRYPT);
    $pdo->prepare("UPDATE pelanggan SET password = :pw WHERE id = :pid")
        ->execute([':pw' => $hash, ':pid' => $pelangganId]);

    // Tandai token sudah dipakai
    $pdo->prepare("UPDATE password_reset_tokens SET is_used = 1 WHERE id = :id")
        ->execute([':id' => $tokenRow['id']]);

    // Hapus semua token lama pelanggan ini (cleanup)
    $pdo->prepare("DELETE FROM password_reset_tokens WHERE pelanggan_id = :pid AND is_used = 1")
        ->execute([':pid' => $pelangganId]);

    $pdo->commit();

    echo json_encode([
        'success' => true,
        'message' => 'Password berhasil diubah. Silakan login dengan password baru.'
    ]);
} catch (Exception $e) {
    $pdo->rollBack();
    echo json_encode(['success' => false, 'message' => 'Gagal mengubah password. Coba lagi.']);
}