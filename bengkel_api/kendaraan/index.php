<?php
// kendaraan/index.php
// GET    → list kendaraan milik pelanggan yg login
// POST   → tambah kendaraan baru
// PUT    → edit kendaraan (kirim ?id=X)
// DELETE → hapus kendaraan (kirim ?id=X)

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../middleware/auth.php';

setCORSHeaders();

$auth = requireRole('pelanggan');
$pelangganId = $auth['user_id'];
$db = getDB();

// ── GET: list kendaraan milik pelanggan ───────────────────
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $stmt = $db->prepare("
        SELECT id, merk, model, tahun, no_polisi, warna
        FROM kendaraan
        WHERE pelanggan_id = ?
        ORDER BY created_at DESC
    ");
    $stmt->bind_param('i', $pelangganId);
    $stmt->execute();
    $result = $stmt->get_result();
    $rows = [];
    while ($row = $result->fetch_assoc()) $rows[] = $row;
    $stmt->close();

    responseOk('OK', $rows);
}

// ── POST: tambah kendaraan ────────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $body     = getRequestBody();
    $merk     = trim($body['merk']      ?? '');
    $model    = trim($body['model']     ?? '');
    $noPolisi = strtoupper(trim($body['no_polisi'] ?? ''));
    $tahun    = !empty($body['tahun'])  ? (int)$body['tahun'] : null;
    $warna    = trim($body['warna']     ?? '') ?: null;

    if (!$merk || !$model || !$noPolisi) {
        responseError('Merk, model, dan no polisi wajib diisi');
    }

    // Cek no polisi sudah terdaftar
    $stmt = $db->prepare("SELECT id FROM kendaraan WHERE no_polisi = ? LIMIT 1");
    $stmt->bind_param('s', $noPolisi);
    $stmt->execute();
    if ($stmt->get_result()->num_rows > 0) {
        $stmt->close();
        responseError('No polisi sudah terdaftar');
    }
    $stmt->close();

    $stmt = $db->prepare("
        INSERT INTO kendaraan (pelanggan_id, merk, model, tahun, no_polisi, warna)
        VALUES (?, ?, ?, ?, ?, ?)
    ");
    $stmt->bind_param('ississ', $pelangganId, $merk, $model, $tahun, $noPolisi, $warna);

    if (!$stmt->execute()) responseError('Gagal menyimpan kendaraan', 500);

    $newId = $stmt->insert_id;
    $stmt->close();
    $db->close();

    responseOk('Kendaraan berhasil ditambahkan', ['id' => $newId]);
}

// ── PUT: edit kendaraan ───────────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'PUT') {
    $id   = (int)($_GET['id'] ?? 0);
    $body = getRequestBody();

    if (!$id) responseError('ID kendaraan wajib diisi');

    // Pastikan kendaraan milik pelanggan ini
    $stmt = $db->prepare("SELECT id FROM kendaraan WHERE id = ? AND pelanggan_id = ? LIMIT 1");
    $stmt->bind_param('ii', $id, $pelangganId);
    $stmt->execute();
    if ($stmt->get_result()->num_rows === 0) {
        responseError('Kendaraan tidak ditemukan', 404);
    }
    $stmt->close();

    $merk     = trim($body['merk']      ?? '');
    $model    = trim($body['model']     ?? '');
    $noPolisi = strtoupper(trim($body['no_polisi'] ?? ''));
    $tahun    = !empty($body['tahun'])  ? (int)$body['tahun'] : null;
    $warna    = trim($body['warna']     ?? '') ?: null;

    if (!$merk || !$model || !$noPolisi) {
        responseError('Merk, model, dan no polisi wajib diisi');
    }

    $stmt = $db->prepare("
        UPDATE kendaraan SET merk=?, model=?, tahun=?, no_polisi=?, warna=?
        WHERE id = ? AND pelanggan_id = ?
    ");
    $stmt->bind_param('ssissii', $merk, $model, $tahun, $noPolisi, $warna, $id, $pelangganId);
    $stmt->execute();
    $stmt->close();
    $db->close();

    responseOk('Kendaraan berhasil diupdate');
}

// ── DELETE: hapus kendaraan ───────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'DELETE') {
    $id = (int)($_GET['id'] ?? 0);
    if (!$id) responseError('ID kendaraan wajib diisi');

    // Cek apakah kendaraan pernah digunakan di booking
    $stmt = $db->prepare("SELECT id FROM booking WHERE kendaraan_id = ? LIMIT 1");
    $stmt->bind_param('i', $id);
    $stmt->execute();
    if ($stmt->get_result()->num_rows > 0) {
        responseError('Kendaraan tidak dapat dihapus karena memiliki riwayat booking');
    }
    $stmt->close();

    $stmt = $db->prepare("DELETE FROM kendaraan WHERE id = ? AND pelanggan_id = ?");
    $stmt->bind_param('ii', $id, $pelangganId);
    $stmt->execute();
    $affected = $stmt->affected_rows;
    $stmt->close();
    $db->close();

    if ($affected === 0) responseError('Kendaraan tidak ditemukan', 404);
    responseOk('Kendaraan berhasil dihapus');
}

responseError('Method tidak diizinkan', 405);
