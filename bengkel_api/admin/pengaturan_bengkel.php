<?php
// admin/pengaturan_bengkel.php
// GET  → ambil pengaturan bengkel (id=1)
// PUT  → update pengaturan bengkel
//
// Field yang bisa diubah:
//   nama_bengkel, alamat_bengkel, no_hp_bengkel,
//   jam_buka (HH:MM), jam_tutup (HH:MM),
//   kuota_booking_harian

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../middleware/auth.php';

setCORSHeaders();
if (!in_array($_SERVER['REQUEST_METHOD'], ['GET', 'PUT']))
    responseError('Method tidak diizinkan', 405);

$auth = requireRole('admin');
$db   = getDB();

// ── GET ────────────────────────────────────────────────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $row = $db->query("
        SELECT id, nama_bengkel, alamat_bengkel, no_hp_bengkel,
               jam_buka, jam_tutup, kuota_booking_harian, updated_at
        FROM pengaturan_bengkel
        WHERE id = 1
        LIMIT 1
    ")->fetch_assoc();

    $db->close();

    if (!$row) responseError('Pengaturan belum tersedia', 404);

    // Format jam: ambil HH:MM saja (potong detik jika ada)
    $row['jam_buka']   = substr($row['jam_buka'],  0, 5);
    $row['jam_tutup']  = substr($row['jam_tutup'], 0, 5);
    $row['kuota_booking_harian'] = (int)$row['kuota_booking_harian'];

    responseOk('OK', $row);
}

// ── PUT ────────────────────────────────────────────────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'PUT') {
    $body = getRequestBody();

    // Validasi field wajib
    $namaBengkel = trim($body['nama_bengkel'] ?? '');
    if (!$namaBengkel) responseError('Nama bengkel wajib diisi');

    $alamat  = trim($body['alamat_bengkel']    ?? '');
    $noHp    = trim($body['no_hp_bengkel']     ?? '');
    $jamBuka = trim($body['jam_buka']          ?? '');
    $jamTutup= trim($body['jam_tutup']         ?? '');
    $kuota   = (int)($body['kuota_booking_harian'] ?? 0);

    // Validasi format jam HH:MM
    $reJam = '/^\d{2}:\d{2}$/';
    if ($jamBuka  && !preg_match($reJam, $jamBuka))  responseError('Format jam_buka harus HH:MM');
    if ($jamTutup && !preg_match($reJam, $jamTutup)) responseError('Format jam_tutup harus HH:MM');
    if ($kuota < 1 || $kuota > 100) responseError('Kuota booking harian harus antara 1 – 100');

    $userId = $auth['user_id'];

    $stmt = $db->prepare("
        UPDATE pengaturan_bengkel
        SET nama_bengkel          = ?,
            alamat_bengkel        = ?,
            no_hp_bengkel         = ?,
            jam_buka              = ?,
            jam_tutup             = ?,
            kuota_booking_harian  = ?,
            updated_by            = ?
        WHERE id = 1
    ");
    $stmt->bind_param(
        'sssssii',
        $namaBengkel, $alamat, $noHp,
        $jamBuka, $jamTutup,
        $kuota, $userId
    );

    if (!$stmt->execute()) {
        $stmt->close(); $db->close();
        responseError('Gagal menyimpan pengaturan');
    }
    $stmt->close();
    $db->close();

    responseOk('Pengaturan berhasil disimpan');
}

responseError('Method tidak diizinkan', 405);
