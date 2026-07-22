<?php
// auth/reset_password.php
// POST { "identifier": "081234...", "otp": "123456", "password_baru": "abc123" }

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/response.php';

setCORSHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    responseError('Method tidak diizinkan', 405);
}

$body         = getRequestBody();
$identifier   = trim($body['identifier'] ?? '');
$otp          = trim($body['otp'] ?? '');
$passwordBaru = trim($body['password_baru'] ?? '');

// ── Validasi input ────────────────────────────────────────────────────────
if ($identifier === '' || $otp === '' || $passwordBaru === '') {
    responseError('Semua field wajib diisi');
}

if (strlen($otp) !== 6 || !ctype_digit($otp)) {
    responseError('Format OTP tidak valid');
}

if (strlen($passwordBaru) < 6) {
    responseError('Password minimal 6 karakter');
}

$db = getDB();

// ── Cari pelanggan ────────────────────────────────────────────────────────
$stmtP = $db->prepare(
    "SELECT id FROM pelanggan
     WHERE (no_hp = ? OR email = ?) AND is_aktif = 1
     LIMIT 1"
);
$stmtP->bind_param('ss', $identifier, $identifier);
$stmtP->execute();
$pelanggan = $stmtP->get_result()->fetch_assoc();
$stmtP->close();

if (!$pelanggan) {
    responseError('Akun tidak ditemukan');
}

$pelangganId = $pelanggan['id'];

// ── Verifikasi OTP ────────────────────────────────────────────────────────
$stmtOtp = $db->prepare(
    "SELECT id FROM password_reset_tokens
     WHERE pelanggan_id = ?
       AND token        = ?
       AND is_used      = 0
       AND expired_at   > NOW()
     LIMIT 1"
);
$stmtOtp->bind_param('is', $pelangganId, $otp);
$stmtOtp->execute();
$tokenRow = $stmtOtp->get_result()->fetch_assoc();
$stmtOtp->close();

if (!$tokenRow) {
    responseError('OTP tidak valid atau sudah kadaluarsa');
}

// ── Update password & tandai token sudah dipakai (transaksi) ─────────────
$db->begin_transaction();

try {
    $hash = password_hash($passwordBaru, PASSWORD_BCRYPT);

    $stmtUpdate = $db->prepare("UPDATE pelanggan SET password = ? WHERE id = ?");
    $stmtUpdate->bind_param('si', $hash, $pelangganId);
    $stmtUpdate->execute();
    $stmtUpdate->close();

    $stmtUsed = $db->prepare("UPDATE password_reset_tokens SET is_used = 1 WHERE id = ?");
    $stmtUsed->bind_param('i', $tokenRow['id']);
    $stmtUsed->execute();
    $stmtUsed->close();

    // Cleanup token yang sudah dipakai
    $stmtClean = $db->prepare("DELETE FROM password_reset_tokens WHERE pelanggan_id = ? AND is_used = 1");
    $stmtClean->bind_param('i', $pelangganId);
    $stmtClean->execute();
    $stmtClean->close();

    $db->commit();
    $db->close();

    responseOk('Password berhasil diubah. Silakan login dengan password baru.');
} catch (Exception $e) {
    $db->rollback();
    $db->close();
    responseError('Gagal mengubah password. Coba lagi.', 500);
}
