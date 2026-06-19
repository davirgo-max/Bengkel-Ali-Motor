<?php
// kasir/proses_noshow.php
// POST body: { "booking_id": X }          → manual no-show 1 booking oleh kasir
// POST body: { "action": "auto_scan" }    → scan semua booking hari ini yang
//                                            sudah lewat 30 menit dari jam slot

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../middleware/auth.php';
require_once __DIR__ . '/../config/penalti_helper.php';

setCORSHeaders();
if ($_SERVER['REQUEST_METHOD'] !== 'POST') responseError('Method tidak diizinkan', 405);

$auth = requireRole('kasir', 'owner');
$db   = getDB();
$body = getRequestBody();

// ── Auto-scan: cari booking yang jam slotnya sudah lewat 30 menit ──
if (($body['action'] ?? '') === 'auto_scan') {
    $batasWaktu = date('H:i:s', strtotime('-30 minutes'));

    $stmt = $db->prepare("
        SELECT b.id, b.no_booking, p.nama AS nama_pelanggan,
               sw.jam_mulai, sw.label AS slot_label
        FROM booking b
        JOIN pelanggan p  ON p.id = b.pelanggan_id
        JOIN slot_waktu sw ON sw.id = b.slot_id
        WHERE b.tanggal_servis = CURDATE()
        AND b.status IN ('menunggu','dikonfirmasi')
        AND sw.jam_mulai <= ?
        AND b.slot_id IS NOT NULL
    ");
    $stmt->bind_param('s', $batasWaktu);
    $stmt->execute();
    $result = $stmt->get_result();
    $candidates = [];
    while ($r = $result->fetch_assoc()) $candidates[] = $r;
    $result->free();
    $stmt->close();

    $hasil = [];
    foreach ($candidates as $c) {
        $result = prosesNoShow($c['id'], "kasir:{$auth['user_id']}");
        $hasil[] = [
            'booking_id'      => $c['id'],
            'no_booking'      => $c['no_booking'],
            'nama_pelanggan'  => $c['nama_pelanggan'],
            'slot'            => $c['slot_label'],
            'diblokir'        => $result['diblokir'],
            'pesan'           => $result['pesan'],
        ];
    }

    $db->close();
    responseOk('Auto-scan selesai', [
        'ditemukan'   => count($candidates),
        'diproses'    => count($hasil),
        'detail'      => $hasil,
    ]);
}

// ── Manual no-show 1 booking ──────────────────────────────
$bookingId = (int)($body['booking_id'] ?? 0);
if (!$bookingId) responseError('booking_id wajib diisi');

$result = prosesNoShow($bookingId, "kasir:{$auth['user_id']}");
$db->close();

responseOk($result['pesan'], $result);
