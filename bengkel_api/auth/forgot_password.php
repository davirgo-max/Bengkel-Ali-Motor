<?php
// auth/forgot_password.php
// POST { "identifier": "081234567890" }   ← no_hp atau email
// Response sukses: { "success": true, "message": "..." }

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/mail_config.php';

setCORSHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    responseError('Method tidak diizinkan', 405);
}

$body       = getRequestBody();
$identifier = trim($body['identifier'] ?? '');

if ($identifier === '') {
    responseError('No HP atau email wajib diisi');
}

$db = getDB();

// ── Cari pelanggan berdasarkan no_hp ATAU email ────────────────────────────
$stmt = $db->prepare(
    "SELECT id, nama, email, is_aktif, is_diblokir, blokir_sampai
     FROM pelanggan
     WHERE (no_hp = ? OR email = ?)
     LIMIT 1"
);
$stmt->bind_param('ss', $identifier, $identifier);
$stmt->execute();
$pelanggan = $stmt->get_result()->fetch_assoc();
$stmt->close();

// Selalu balas sukses meski tidak ketemu (security: jangan bocorkan data akun mana yang ada)
if (!$pelanggan) {
    responseOk('Jika akun ditemukan, kode OTP akan dikirim ke email terdaftar.');
}

if (!$pelanggan['is_aktif']) {
    responseError('Akun tidak aktif');
}

if ($pelanggan['is_diblokir']) {
    $sampai = $pelanggan['blokir_sampai']
        ? ' sampai ' . date('d/m/Y', strtotime($pelanggan['blokir_sampai']))
        : ' secara permanen';
    responseError('Akun Anda diblokir' . $sampai . '. Hubungi bengkel untuk informasi lebih lanjut.', 403);
}

// ── Akun belum punya email terdaftar → tidak bisa kirim OTP ───────────────
// (email wajib diisi untuk akun baru, tapi akun lama sebelum aturan ini
// berlaku mungkin belum punya. Minta mereka isi dulu lewat menu profil.)
if (empty($pelanggan['email'])) {
    responseError(
        'Akun Anda belum memiliki email terdaftar. Silakan tambahkan email lewat menu Profil terlebih dahulu, baru gunakan fitur lupa password.'
    );
}

$pelangganId = $pelanggan['id'];

// ── Rate limit: maksimal 3 request per 10 menit ────────────────────────────
$stmtRate = $db->prepare(
    "SELECT COUNT(*) AS jumlah FROM password_reset_tokens
     WHERE pelanggan_id = ?
       AND created_at >= DATE_SUB(NOW(), INTERVAL 10 MINUTE)"
);
$stmtRate->bind_param('i', $pelangganId);
$stmtRate->execute();
$jumlahRequest = (int) $stmtRate->get_result()->fetch_assoc()['jumlah'];
$stmtRate->close();

if ($jumlahRequest >= 3) {
    responseError('Terlalu banyak permintaan. Coba lagi dalam 10 menit.');
}

// ── Hapus token lama yang belum dipakai ───────────────────────────────────
$stmtDel = $db->prepare("DELETE FROM password_reset_tokens WHERE pelanggan_id = ? AND is_used = 0");
$stmtDel->bind_param('i', $pelangganId);
$stmtDel->execute();
$stmtDel->close();

// ── Buat OTP 6 digit ──────────────────────────────────────────────────────
// token punya UNIQUE constraint di DB, jadi kalau ada tabrakan (sangat jarang,
// 1 dari 1 juta), coba generate ulang sampai beberapa kali.
$expiredAt   = date('Y-m-d H:i:s', strtotime('+1 hour'));
$stmtInsert  = $db->prepare(
    "INSERT INTO password_reset_tokens (pelanggan_id, token, expired_at, is_used, created_at)
     VALUES (?, ?, ?, 0, NOW())"
);

$maxPercobaan = 5;
$berhasil     = false;
$otp          = '';

for ($i = 0; $i < $maxPercobaan; $i++) {
    $otp = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);
    $stmtInsert->bind_param('iss', $pelangganId, $otp, $expiredAt);

    if ($stmtInsert->execute()) {
        $berhasil = true;
        break;
    }

    // errno 1062 = duplicate entry (tabrakan UNIQUE token) → coba lagi dengan OTP baru
    if ($stmtInsert->errno !== 1062) {
        break;
    }
}
$stmtInsert->close();

if (!$berhasil) {
    $db->close();
    responseError('Gagal membuat kode OTP, coba lagi.', 500);
}

$db->close();

// ── Kirim OTP via email (Gmail SMTP) ───────────────────────────────────────
$hasil = kirimEmailOtp($pelanggan['email'], $pelanggan['nama'], $otp, 'reset_password');

if (!$hasil['success']) {
    // Tetap log error di server untuk debugging, tapi jangan bocorkan detail SMTP ke client
    error_log('Gagal kirim email OTP: ' . ($hasil['error'] ?? 'unknown error'));
    responseError('Gagal mengirim email OTP. Coba lagi beberapa saat lagi.', 500);
}

responseOk('Kode OTP berhasil dikirim ke email terdaftar. Berlaku 1 jam.');
