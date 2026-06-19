<?php
// pelanggan/notifikasi.php
// GET                    → list notifikasi pelanggan (terbaru di atas)
// PUT ?id=X              → tandai 1 notifikasi sudah dibaca
// PUT ?action=read_all   → tandai semua sudah dibaca

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../middleware/auth.php';

setCORSHeaders();

$auth        = requireRole('pelanggan');
$pelangganId = $auth['user_id'];
$db          = getDB();

// ── GET ───────────────────────────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $stmt = $db->prepare("
        SELECT id, tipe, judul, pesan, is_read, created_at
        FROM notifikasi
        WHERE pelanggan_id = ?
        ORDER BY created_at DESC
        LIMIT 50
    ");
    $stmt->bind_param('i', $pelangganId);
    $stmt->execute();
    $result = $stmt->get_result();
    $rows   = [];
    while ($row = $result->fetch_assoc()) {
        $row['is_read'] = (bool)$row['is_read'];
        $rows[] = $row;
    }
    $stmt->close();

    // Hitung unread
    $stmt = $db->prepare("SELECT COUNT(*) AS total FROM notifikasi WHERE pelanggan_id = ? AND is_read = 0");
    $stmt->bind_param('i', $pelangganId);
    $stmt->execute();
    $unread = $stmt->get_result()->fetch_assoc()['total'];
    $stmt->close();
    $db->close();

    responseOk('OK', [
        'notifikasi'   => $rows,
        'unread_count' => (int)$unread,
    ]);
}

// ── PUT: tandai dibaca ────────────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'PUT') {
    $body   = getRequestBody();
    $action = trim($body['action'] ?? '');

    // Tandai semua dibaca
    if ($action === 'read_all') {
        $stmt = $db->prepare("UPDATE notifikasi SET is_read = 1 WHERE pelanggan_id = ?");
        $stmt->bind_param('i', $pelangganId);
        $stmt->execute();
        $stmt->close();
        $db->close();
        responseOk('Semua notifikasi ditandai sudah dibaca');
    }

    // Tandai 1 notifikasi
    $id = (int)($_GET['id'] ?? 0);
    if (!$id) responseError('ID notifikasi wajib diisi');

    $stmt = $db->prepare("
        UPDATE notifikasi SET is_read = 1
        WHERE id = ? AND pelanggan_id = ?
    ");
    $stmt->bind_param('ii', $id, $pelangganId);
    $stmt->execute();
    $stmt->close();
    $db->close();

    responseOk('Notifikasi ditandai sudah dibaca');
}

responseError('Method tidak diizinkan', 405);
