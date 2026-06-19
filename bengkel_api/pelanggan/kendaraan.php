<?php
// pelanggan/kendaraan.php
// GET  /bengkel_api/pelanggan/kendaraan.php        → list kendaraan milik pelanggan
// POST /bengkel_api/pelanggan/kendaraan.php        → tambah kendaraan baru
// PUT  /bengkel_api/pelanggan/kendaraan.php?id=1   → edit kendaraan
// DELETE /bengkel_api/pelanggan/kendaraan.php?id=1 → hapus kendaraan

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../middleware/auth.php';

setCORSHeaders();

// Wajib login sebagai pelanggan
$auth = requireRole('pelanggan');
$pelangganId = $auth['user_id'];
$db = getDB();
$method = $_SERVER['REQUEST_METHOD'];

// ── GET: list kendaraan ──────────────────────────────────
if ($method === 'GET') {
    $stmt = $db->prepare("
        SELECT id, merk, model, tahun, no_polisi, warna
        FROM kendaraan
        WHERE pelanggan_id = ?
        ORDER BY created_at DESC
    ");
    $stmt->bind_param('i', $pelangganId);
    $stmt->execute();
    $rows = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    $stmt->close();
    $db->close();
    responseOk('Data kendaraan', ['kendaraan' => $rows]);
}

// ── POST: tambah kendaraan ───────────────────────────────
if ($method === 'POST') {
    $body      = getRequestBody();
    $merk      = trim($body['merk']      ?? '');
    $model     = trim($body['model']     ?? '');
    $tahun     = (int)($body['tahun']    ?? 0);
    $no_polisi = strtoupper(trim($body['no_polisi'] ?? ''));
    $warna     = trim($body['warna']     ?? '');

    if (!$merk || !$model || !$no_polisi) {
        responseError('Merk, model, dan no polisi wajib diisi');
    }

    // Cek no polisi sudah ada
    $chk = $db->prepare("SELECT id FROM kendaraan WHERE no_polisi = ? LIMIT 1");
    $chk->bind_param('s', $no_polisi);
    $chk->execute();
    if ($chk->get_result()->num_rows > 0) {
        $chk->close();
        responseError('No polisi sudah terdaftar');
    }
    $chk->close();

    $tahunVal = $tahun > 0 ? $tahun : null;
    $warnaVal = $warna ?: null;

    $stmt = $db->prepare("
        INSERT INTO kendaraan (pelanggan_id, merk, model, tahun, no_polisi, warna)
        VALUES (?, ?, ?, ?, ?, ?)
    ");
    $stmt->bind_param('issiiss', $pelangganId, $merk, $model, $tahunVal, $no_polisi, $warnaVal);

    // fix bind null int
    $stmt->close();
    $stmt = $db->prepare("
        INSERT INTO kendaraan (pelanggan_id, merk, model, tahun, no_polisi, warna)
        VALUES (?, ?, ?, ?, ?, ?)
    ");
    $stmt->bind_param('ississ', $pelangganId, $merk, $model, $tahun ?: null, $no_polisi, $warnaVal);

    if (!$stmt->execute()) {
        responseError('Gagal menyimpan kendaraan', 500);
    }
    $newId = $stmt->insert_id;
    $stmt->close();
    $db->close();

    responseOk('Kendaraan berhasil ditambahkan', ['kendaraan_id' => $newId]);
}

// ── PUT: edit kendaraan ──────────────────────────────────
if ($method === 'PUT') {
    $id   = (int)($_GET['id'] ?? 0);
    if ($id <= 0) responseError('ID tidak valid');

    // Pastikan kendaraan milik pelanggan ini
    $chk = $db->prepare("SELECT id FROM kendaraan WHERE id = ? AND pelanggan_id = ? LIMIT 1");
    $chk->bind_param('ii', $id, $pelangganId);
    $chk->execute();
    if ($chk->get_result()->num_rows === 0) {
        responseError('Kendaraan tidak ditemukan', 404);
    }
    $chk->close();

    $body      = getRequestBody();
    $merk      = trim($body['merk']      ?? '');
    $model     = trim($body['model']     ?? '');
    $tahun     = (int)($body['tahun']    ?? 0);
    $no_polisi = strtoupper(trim($body['no_polisi'] ?? ''));
    $warna     = trim($body['warna']     ?? '');

    if (!$merk || !$model || !$no_polisi) {
        responseError('Merk, model, dan no polisi wajib diisi');
    }

    // Cek no polisi milik kendaraan lain
    $chk2 = $db->prepare("SELECT id FROM kendaraan WHERE no_polisi = ? AND id != ? LIMIT 1");
    $chk2->bind_param('si', $no_polisi, $id);
    $chk2->execute();
    if ($chk2->get_result()->num_rows > 0) {
        responseError('No polisi sudah digunakan kendaraan lain');
    }
    $chk2->close();

    $stmt = $db->prepare("
        UPDATE kendaraan SET merk=?, model=?, tahun=?, no_polisi=?, warna=?
        WHERE id=?
    ");
    $tahunVal = $tahun > 0 ? $tahun : null;
    $warnaVal = $warna ?: null;
    $stmt->bind_param('ssissi', $merk, $model, $tahunVal, $no_polisi, $warnaVal, $id);
    $stmt->execute();
    $stmt->close();
    $db->close();

    responseOk('Kendaraan berhasil diperbarui');
}

// ── DELETE: hapus kendaraan ──────────────────────────────
if ($method === 'DELETE') {
    $id = (int)($_GET['id'] ?? 0);
    if ($id <= 0) responseError('ID tidak valid');

    $chk = $db->prepare("SELECT id FROM kendaraan WHERE id = ? AND pelanggan_id = ? LIMIT 1");
    $chk->bind_param('ii', $id, $pelangganId);
    $chk->execute();
    if ($chk->get_result()->num_rows === 0) {
        responseError('Kendaraan tidak ditemukan', 404);
    }
    $chk->close();

    // Cek apakah kendaraan sedang ada booking aktif
    $chkBooking = $db->prepare("
        SELECT id FROM booking
        WHERE kendaraan_id = ?
        AND status NOT IN ('selesai', 'dibatalkan', 'no_show')
        LIMIT 1
    ");
    $chkBooking->bind_param('i', $id);
    $chkBooking->execute();
    if ($chkBooking->get_result()->num_rows > 0) {
        responseError('Tidak bisa hapus kendaraan yang masih memiliki booking aktif');
    }
    $chkBooking->close();

    $stmt = $db->prepare("DELETE FROM kendaraan WHERE id = ?");
    $stmt->bind_param('i', $id);
    $stmt->execute();
    $stmt->close();
    $db->close();

    responseOk('Kendaraan berhasil dihapus');
}

$db->close();
responseError('Method tidak diizinkan', 405);
