<?php
// kasir/pengaturan.php
// GET  → ambil pengaturan bengkel
// PUT  → simpan pengaturan bengkel

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../middleware/auth.php';

setCORSHeaders();
$auth    = requireRole('kasir');
$kasirId = $auth['user_id'];
$db      = getDB();

// ── GET ───────────────────────────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $row = $db->query("SELECT * FROM pengaturan_bengkel WHERE id=1 LIMIT 1")
               ->fetch_assoc();
    $db->close();

    if (!$row) responseError('Pengaturan tidak ditemukan', 404);
    responseOk('OK', $row);
}

// ── PUT ───────────────────────────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'PUT') {
    $body  = getRequestBody();

    $namaBengkel         = trim($body['nama_bengkel']         ?? '');
    $alamatBengkel       = trim($body['alamat_bengkel']       ?? '') ?: null;
    $noHpBengkel         = trim($body['no_hp_bengkel']        ?? '') ?: null;
    $kuotaBookingHarian  = (int)($body['kuota_booking_harian'] ?? 10);
    $jamBuka             = trim($body['jam_buka']             ?? '08:00:00');
    $jamTutup            = trim($body['jam_tutup']            ?? '17:00:00');

    if (!$namaBengkel) responseError('Nama bengkel wajib diisi');
    if ($kuotaBookingHarian < 1 || $kuotaBookingHarian > 100)
        responseError('Kuota booking harian harus antara 1-100');

    // Validasi format jam HH:MM atau HH:MM:SS
    $jamBukaFull  = strlen($jamBuka)  === 5 ? $jamBuka  . ':00' : $jamBuka;
    $jamTutupFull = strlen($jamTutup) === 5 ? $jamTutup . ':00' : $jamTutup;

    $stmt = $db->prepare("
        UPDATE pengaturan_bengkel SET
            nama_bengkel        = ?,
            alamat_bengkel      = ?,
            no_hp_bengkel       = ?,
            kuota_booking_harian= ?,
            jam_buka            = ?,
            jam_tutup           = ?,
            updated_by          = ?
        WHERE id = 1
    ");
    $stmt->bind_param('ssssssi',
        $namaBengkel, $alamatBengkel, $noHpBengkel,
        $kuotaBookingHarian, $jamBukaFull, $jamTutupFull,
        $kasirId
    );

    if (!$stmt->execute()) responseError('Gagal menyimpan pengaturan', 500);
    $stmt->close();
    $db->close();

    responseOk('Pengaturan berhasil disimpan');
}

responseError('Method tidak diizinkan', 405);