<?php
// admin/akun_kasir.php
// GET           → list semua akun kasir
// POST          → tambah kasir baru
// PUT ?id=X     → toggle aktif / reset password
// DELETE ?id=X  → hapus kasir (hanya jika belum punya transaksi)

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../middleware/auth.php';

setCORSHeaders();
$auth    = requireRole('admin');
$ownerId = $auth['user_id'];
$db      = getDB();

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    // Hanya ambil akun dengan role 'kasir' — owner tidak boleh muncul di sini
    $result = $db->query("
        SELECT id, nama, username, role, is_aktif, created_at
        FROM users
        WHERE role = 'kasir'
        ORDER BY created_at DESC
    ");
    $rows = [];
    while ($r = $result->fetch_assoc()) {
        $r['is_aktif'] = (bool)$r['is_aktif'];
        $rows[] = $r;
    }
    $db->close();
    responseOk('OK', $rows);
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $body     = getRequestBody();
    $nama     = trim($body['nama']     ?? '');
    $username = trim($body['username'] ?? '');
    $password = trim($body['password'] ?? '');

    if (!$nama || !$username || !$password)
        responseError('Nama, username, dan password wajib diisi');
    if (strlen($password) < 6)
        responseError('Password minimal 6 karakter');

    // Cek username sudah ada
    $stmt = $db->prepare("SELECT id FROM users WHERE username=? LIMIT 1");
    $stmt->bind_param('s', $username);
    $stmt->execute();
    if ($stmt->get_result()->num_rows > 0) {
        $stmt->close();
        responseError('Username sudah digunakan');
    }
    $stmt->close();

    $hash = password_hash($password, PASSWORD_BCRYPT);
    $role = 'kasir';
    $stmt = $db->prepare("
        INSERT INTO users (nama, username, password, role) VALUES (?,?,?,?)
    ");
    $stmt->bind_param('ssss', $nama, $username, $hash, $role);
    if (!$stmt->execute()) responseError('Gagal menambah kasir', 500);
    $newId = $stmt->insert_id;
    $stmt->close();
    $db->close();
    responseOk('Kasir berhasil ditambahkan', ['id' => $newId]);
}

if ($_SERVER['REQUEST_METHOD'] === 'PUT') {
    $id     = (int)($_GET['id'] ?? 0);
    $body   = getRequestBody();
    $action = trim($body['action'] ?? 'toggle_aktif');
    if (!$id) responseError('ID kasir wajib diisi');

    // Cegah owner menonaktifkan dirinya sendiri
    if ($id === $ownerId) responseError('Tidak dapat mengubah akun sendiri');

    $stmt = $db->prepare("SELECT id, role FROM users WHERE id=? LIMIT 1");
    $stmt->bind_param('i', $id);
    $stmt->execute();
    $user = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if (!$user) responseError('User tidak ditemukan', 404);

    if ($action === 'toggle_aktif') {
        $aktif = (int)($body['is_aktif'] ?? 0);
        $stmt  = $db->prepare("UPDATE users SET is_aktif=? WHERE id=?");
        $stmt->bind_param('ii', $aktif, $id);
        $stmt->execute(); $stmt->close();
        responseOk($aktif ? 'Kasir diaktifkan' : 'Kasir dinonaktifkan');
    }

    if ($action === 'reset_password') {
        $passBaru = trim($body['password_baru'] ?? '');
        if (strlen($passBaru) < 6)
            responseError('Password baru minimal 6 karakter');
        $hash = password_hash($passBaru, PASSWORD_BCRYPT);
        $stmt = $db->prepare("UPDATE users SET password=? WHERE id=?");
        $stmt->bind_param('si', $hash, $id);
        $stmt->execute(); $stmt->close();
        responseOk('Password berhasil direset');
    }

    responseError('Action tidak valid');
}

if ($_SERVER['REQUEST_METHOD'] === 'DELETE') {
    $id = (int)($_GET['id'] ?? 0);
    if (!$id) responseError('ID kasir wajib diisi');
    if ($id === $ownerId) responseError('Tidak dapat menghapus akun sendiri');

    // Cek kasir punya transaksi
    $stmt = $db->prepare("SELECT id FROM transaksi WHERE kasir_id=? LIMIT 1");
    $stmt->bind_param('i', $id);
    $stmt->execute();
    if ($stmt->get_result()->num_rows > 0) {
        $stmt->close();
        responseError('Kasir tidak dapat dihapus karena memiliki riwayat transaksi. Nonaktifkan saja.');
    }
    $stmt->close();

    $stmt = $db->prepare("DELETE FROM users WHERE id=? AND role='kasir'");
    $stmt->bind_param('i', $id);
    $stmt->execute();
    $affected = $stmt->affected_rows;
    $stmt->close(); $db->close();

    if ($affected === 0) responseError('Kasir tidak ditemukan', 404);
    responseOk('Kasir berhasil dihapus');
}

responseError('Method tidak diizinkan', 405);