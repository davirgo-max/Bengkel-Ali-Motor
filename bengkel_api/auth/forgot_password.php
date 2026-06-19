<?php
// auth/forgot_password.php
// POST { "identifier": "081234567890" }   ← no_hp atau email
// Response sukses: { "success": true, "message": "...", "dev_otp": "123456" }

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(204); exit; }

require_once __DIR__ . '/../config/db.php';   // $pdo

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Method not allowed']);
    exit;
}

$body       = json_decode(file_get_contents('php://input'), true) ?? [];
$identifier = trim($body['identifier'] ?? '');

if ($identifier === '') {
    echo json_encode(['success' => false, 'message' => 'No HP atau email wajib diisi']);
    exit;
}

// ── Cari pelanggan berdasarkan no_hp ATAU email ────────────────────────────
$stmt = $pdo->prepare(
    "SELECT id, nama, is_aktif
     FROM pelanggan
     WHERE (no_hp = :id OR email = :id)
     LIMIT 1"
);
$stmt->execute([':id' => $identifier]);
$pelanggan = $stmt->fetch(PDO::FETCH_ASSOC);

// Selalu balas sukses meski tidak ketemu (security: jangan bocorkan data)
if (!$pelanggan) {
    echo json_encode([
        'success' => true,
        'message' => 'Jika akun ditemukan, kode OTP akan dikirim.'
    ]);
    exit;
}

if (!$pelanggan['is_aktif']) {
    echo json_encode(['success' => false, 'message' => 'Akun tidak aktif']);
    exit;
}

$pelangganId = $pelanggan['id'];

// ── Rate limit: maksimal 3 request per 10 menit ────────────────────────────
$stmtRate = $pdo->prepare(
    "SELECT COUNT(*) FROM password_reset_tokens
     WHERE pelanggan_id = :pid
       AND created_at >= DATE_SUB(NOW(), INTERVAL 10 MINUTE)"
);
$stmtRate->execute([':pid' => $pelangganId]);
if ((int) $stmtRate->fetchColumn() >= 3) {
    echo json_encode([
        'success' => false,
        'message' => 'Terlalu banyak permintaan. Coba lagi dalam 10 menit.'
    ]);
    exit;
}

// ── Hapus token lama yang belum dipakai ───────────────────────────────────
$pdo->prepare("DELETE FROM password_reset_tokens WHERE pelanggan_id = :pid AND is_used = 0")
    ->execute([':pid' => $pelangganId]);

// ── Buat OTP 6 digit ──────────────────────────────────────────────────────
$otp       = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);
$expiredAt = date('Y-m-d H:i:s', strtotime('+1 hour'));

$stmtInsert = $pdo->prepare(
    "INSERT INTO password_reset_tokens (pelanggan_id, token, expired_at, is_used)
     VALUES (:pid, :token, :exp, 0)"
);
$stmtInsert->execute([
    ':pid'   => $pelangganId,
    ':token' => $otp,
    ':exp'   => $expiredAt,
]);

// ── TODO: Kirim OTP via SMS gateway (Fonnte/Twilio/dll) ──────────────────
// Contoh Fonnte:
// kirimWhatsapp($pelanggan['no_hp'], "Kode OTP reset password Bengkel Ali Motor: $otp\nBerlaku 1 jam.");

// ── Response (dev_otp hanya untuk development, hapus saat production) ─────
echo json_encode([
    'success' => true,
    'message' => 'Kode OTP berhasil dibuat. Berlaku 1 jam.',
    'dev_otp' => $otp,   // ← HAPUS baris ini saat production
]);