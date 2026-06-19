<?php
// owner/pelanggan.php
// GET             → daftar pelanggan (filter: diblokir=1 untuk yang aktif blokir saja)
// POST {action: 'unblock', pelanggan_id: X} → owner unblock pelanggan

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../middleware/auth.php';

setCORSHeaders();
requireRole('owner');
$db = getDB();

// ── GET: Daftar Pelanggan ─────────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $hanyaDiblokir = !empty($_GET['diblokir']);
    $search        = trim($_GET['q'] ?? '');

    $where  = '1=1';
    $params = [];
    $types  = '';

    if ($hanyaDiblokir) {
        $where .= " AND pb.id IS NOT NULL AND (pb.blokir_sampai IS NULL OR pb.blokir_sampai > NOW())";
    }
    if ($search !== '') {
        $like    = "%$search%";
        $where  .= " AND (p.nama LIKE ? OR p.no_hp LIKE ? OR u.email LIKE ?)";
        $params  = array_merge($params, [$like, $like, $like]);
        $types  .= 'sss';
    }

    $sql = "
        SELECT
            p.id,
            p.nama,
            p.no_hp,
            u.email,
            p.created_at,
            pb.id            AS blokir_id,
            pb.alasan        AS blokir_alasan,
            pb.blokir_sampai,
            pb.jumlah_noshow,
            COUNT(b.id)      AS total_booking
        FROM pelanggan p
        JOIN users u ON u.id = p.user_id
        LEFT JOIN pelanggan_blokir pb
            ON pb.pelanggan_id = p.id
            AND (pb.blokir_sampai IS NULL OR pb.blokir_sampai > NOW())
        LEFT JOIN booking b ON b.pelanggan_id = p.id
        WHERE $where
        GROUP BY p.id, p.nama, p.no_hp, u.email, p.created_at,
                 pb.id, pb.alasan, pb.blokir_sampai, pb.jumlah_noshow
        ORDER BY pb.id DESC, p.nama ASC
        LIMIT 200
    ";

    $stmt = $db->prepare($sql);
    if ($types) $stmt->bind_param($types, ...$params);
    $stmt->execute();
    $res  = $stmt->get_result();
    $list = [];
    while ($r = $res->fetch_assoc()) {
        $list[] = [
            'id'             => (int)$r['id'],
            'nama'           => $r['nama'],
            'no_hp'          => $r['no_hp'],
            'email'          => $r['email'],
            'total_booking'  => (int)$r['total_booking'],
            'created_at'     => $r['created_at'],
            'diblokir'       => !empty($r['blokir_id']),
            'blokir_alasan'  => $r['blokir_alasan'],
            'blokir_sampai'  => $r['blokir_sampai'],
            'jumlah_noshow'  => (int)($r['jumlah_noshow'] ?? 0),
        ];
    }
    $stmt->close();

    responseOk('ok',['pelanggan' => $list, 'total' => count($list)]);
}

// ── POST: Unblock ─────────────────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $body   = json_decode(file_get_contents('php://input'), true) ?? [];
    $action = $body['action'] ?? '';

    if ($action !== 'unblock') responseError('Action tidak dikenal', 400);

    $pelangganId = (int)($body['pelanggan_id'] ?? 0);
    if (!$pelangganId) responseError('pelanggan_id wajib diisi', 400);

    // Cek apakah pelanggan memang diblokir
    $stmt = $db->prepare("
        SELECT id FROM pelanggan_blokir
        WHERE pelanggan_id = ?
          AND (blokir_sampai IS NULL OR blokir_sampai > NOW())
        LIMIT 1
    ");
    $stmt->bind_param('i', $pelangganId);
    $stmt->execute();
    $blokir = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$blokir) responseError('Pelanggan tidak dalam status blokir aktif', 404);

    // Hapus / expire semua blokir aktif pelanggan ini
    $stmt = $db->prepare("
        DELETE FROM pelanggan_blokir
        WHERE pelanggan_id = ?
          AND (blokir_sampai IS NULL OR blokir_sampai > NOW())
    ");
    $stmt->bind_param('i', $pelangganId);
    $stmt->execute();
    $stmt->close();

    responseOk('ok',['message' => 'Pelanggan berhasil di-unblock']);
}

responseError('Method tidak diizinkan', 405);
