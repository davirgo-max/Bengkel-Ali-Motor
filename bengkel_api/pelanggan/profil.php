<?php
// pelanggan/profil.php
// GET  → data profil pelanggan
// PUT  → update profil (hanya email & alamat jika masih kosong)
//        atau ganti password (?action=ganti_password)

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../middleware/auth.php';

setCORSHeaders();

$auth        = requireRole('pelanggan');
$pelangganId = $auth['user_id'];
$db          = getDB();

// ── GET: ambil data profil ────────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $stmt = $db->prepare("
        SELECT id, nama, no_hp, email, alamat, created_at
        FROM pelanggan WHERE id = ? LIMIT 1
    ");
    $stmt->bind_param('i', $pelangganId);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    $db->close();

    if (!$row) responseError('Data tidak ditemukan', 404);
    responseOk('OK', $row);
}

// ── PUT: update profil / ganti password ──────────────────
if ($_SERVER['REQUEST_METHOD'] === 'PUT') {
    $body   = getRequestBody();
    $action = trim($body['action'] ?? '');

    // ── Ganti password ────────────────────────────────────
    if ($action === 'ganti_password') {
        $passLama = trim($body['password_lama'] ?? '');
        $passBaru = trim($body['password_baru'] ?? '');

        if (!$passLama || !$passBaru) responseError('Password lama dan baru wajib diisi');
        if (strlen($passBaru) < 6)    responseError('Password baru minimal 6 karakter');

        $stmt = $db->prepare("SELECT password FROM pelanggan WHERE id = ? LIMIT 1");
        $stmt->bind_param('i', $pelangganId);
        $stmt->execute();
        $current = $stmt->get_result()->fetch_assoc();
        $stmt->close();

        if (!password_verify($passLama, $current['password'])) {
            responseError('Password lama tidak sesuai', 401);
        }

        $hash = password_hash($passBaru, PASSWORD_BCRYPT);
        $stmt = $db->prepare("UPDATE pelanggan SET password = ? WHERE id = ?");
        $stmt->bind_param('si', $hash, $pelangganId);
        $stmt->execute();
        $stmt->close();
        $db->close();

        responseOk('Password berhasil diubah');
    }

    // ── Update email / alamat (hanya jika masih kosong) ───
    // Ambil data saat ini untuk validasi
    $stmt = $db->prepare("SELECT email, alamat FROM pelanggan WHERE id = ? LIMIT 1");
    $stmt->bind_param('i', $pelangganId);
    $stmt->execute();
    $current = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    $emailBaru  = trim($body['email']  ?? '') ?: null;
    $alamatBaru = trim($body['alamat'] ?? '') ?: null;

    // Validasi: email hanya boleh diisi jika sebelumnya kosong
    if ($emailBaru !== null) {
        if (!empty($current['email'])) {
            responseError('Email tidak dapat diubah karena sudah pernah diisi', 403);
        }
        if (!filter_var($emailBaru, FILTER_VALIDATE_EMAIL)) {
            responseError('Format email tidak valid');
        }
        // Cek email tidak bentrok dengan akun lain
        $stmt = $db->prepare("SELECT id FROM pelanggan WHERE email = ? AND id != ? LIMIT 1");
        $stmt->bind_param('si', $emailBaru, $pelangganId);
        $stmt->execute();
        if ($stmt->get_result()->num_rows > 0) {
            responseError('Email sudah digunakan akun lain');
        }
        $stmt->close();
    }

    // Validasi: alamat hanya boleh diisi jika sebelumnya kosong
    if ($alamatBaru !== null && !empty($current['alamat'])) {
        responseError('Alamat tidak dapat diubah karena sudah pernah diisi', 403);
    }

    // Tentukan nilai akhir: jika field tidak dikirim, pakai nilai lama
    $emailFinal  = $emailBaru  ?? $current['email'];
    $alamatFinal = $alamatBaru ?? $current['alamat'];

    // Update — nama & no_hp tidak pernah diubah di sini
    $stmt = $db->prepare("UPDATE pelanggan SET email = ?, alamat = ? WHERE id = ?");
    $stmt->bind_param('ssi', $emailFinal, $alamatFinal, $pelangganId);
    $stmt->execute();
    $stmt->close();
    $db->close();

    responseOk('Data berhasil disimpan');
}

responseError('Method tidak diizinkan', 405);