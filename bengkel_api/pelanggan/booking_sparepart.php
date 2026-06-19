<?php
// pelanggan/booking_sparepart.php
// GET ?booking_id=X  → daftar request sparepart milik booking tersebut (milik pelanggan yg login)

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../middleware/auth.php';

setCORSHeaders();

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    responseError('Method tidak diizinkan', 405);
}

$auth        = requireRole('pelanggan');
$pelangganId = $auth['user_id'];
$db          = getDB();

$bookingId = (int)($_GET['booking_id'] ?? 0);
if (!$bookingId) responseError('booking_id wajib diisi');

// Pastikan booking ini milik pelanggan yang sedang login
$stmt = $db->prepare("SELECT id FROM booking WHERE id = ? AND pelanggan_id = ? LIMIT 1");
$stmt->bind_param('ii', $bookingId, $pelangganId);
$stmt->execute();
if ($stmt->get_result()->num_rows === 0) {
    $stmt->close();
    responseError('Booking tidak ditemukan', 404);
}
$stmt->close();

// Ambil daftar request sparepart beserta nama & satuan dari tabel sparepart
$stmt = $db->prepare("
    SELECT
        bsr.id,
        bsr.sparepart_id,
        sp.nama,
        sp.satuan,
        bsr.jumlah,
        bsr.harga_jual,
        bsr.subtotal,
        bsr.catatan,
        bsr.status,
        bsr.catatan_kasir,
        bsr.created_at
    FROM booking_sparepart_request bsr
    JOIN sparepart sp ON sp.id = bsr.sparepart_id
    WHERE bsr.booking_id = ?
    ORDER BY bsr.id ASC
");
$stmt->bind_param('i', $bookingId);
$stmt->execute();

$rows = [];
$result = $stmt->get_result();
while ($row = $result->fetch_assoc()) {
    $row['harga_jual'] = (float)$row['harga_jual'];
    $row['subtotal']   = (float)$row['subtotal'];
    $row['jumlah']     = (int)$row['jumlah'];
    $rows[] = $row;
}
$stmt->close();
$db->close();

responseOk('OK', $rows);