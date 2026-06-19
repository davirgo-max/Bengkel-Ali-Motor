<?php
// admin/kelola_blokir.php
// GET                             → list pelanggan yang sedang diblokir
// GET ?pelanggan_id=X             → riwayat penalti 1 pelanggan
// PUT body: {pelanggan_id, aksi}  → buka_blokir atau blokir_manual

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../middleware/auth.php';
require_once __DIR__ . '/../config/penalti_helper.php';

setCORSHeaders();
$auth = requireRole('admin');
$db   = getDB();

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    if (!empty($_GET['pelanggan_id'])) {
        $pid  = (int)$_GET['pelanggan_id'];
        $stmt = $db->prepare("
            SELECT pn.*, b.no_booking, b.tanggal_servis, sw.label AS slot_label
            FROM penalti_noshow pn
            JOIN booking b     ON b.id  = pn.booking_id
            LEFT JOIN slot_waktu sw ON sw.id = b.slot_id
            WHERE pn.pelanggan_id = ?
            ORDER BY pn.created_at DESC
        ");
        $stmt->bind_param('i', $pid);
        $stmt->execute();
        $rows = [];
        $result = $stmt->get_result();
        while ($r = $result->fetch_assoc()) $rows[] = $r;
        $stmt->close();
        responseOk('OK', $rows);
    }

    $stmt = $db->prepare("
        SELECT p.id, p.nama, p.no_hp, p.is_diblokir,
               p.blokir_sampai, p.blokir_alasan, p.total_noshow
        FROM pelanggan p
        WHERE p.is_diblokir = 1
        ORDER BY p.total_noshow DESC
    ");
    $stmt->execute();
    $rows = [];
    $result = $stmt->get_result();
    while ($r = $result->fetch_assoc()) {
        $r['permanen'] = $r['blokir_sampai'] === null;
        if (!$r['permanen'] && strtotime($r['blokir_sampai']) <= time()) {
            $db->query("UPDATE pelanggan SET is_diblokir=0, blokir_sampai=NULL WHERE id={$r['id']}");
            continue;
        }
        $rows[] = $r;
    }
    $stmt->close();
    responseOk('OK', $rows);
}

if ($_SERVER['REQUEST_METHOD'] === 'PUT') {
    $body = getRequestBody();
    $pid  = (int)($body['pelanggan_id'] ?? 0);
    $aksi = trim($body['aksi'] ?? '');
    if (!$pid) responseError('pelanggan_id wajib diisi');

    if ($aksi === 'buka_blokir') {
        $alasan    = trim($body['alasan'] ?? 'Dibuka manual oleh owner');
        $namaOwner = "owner:{$auth['user_id']}";
        $stmt = $db->prepare("UPDATE pelanggan SET is_diblokir=0, blokir_sampai=NULL, blokir_alasan=NULL WHERE id=?");
        $stmt->bind_param('i', $pid); $stmt->execute(); $stmt->close();
        $stmt = $db->prepare("INSERT INTO log_blokir_pelanggan (pelanggan_id, aksi, alasan, dilakukan_oleh) VALUES (?, 'buka_blokir', ?, ?)");
        $stmt->bind_param('iss', $pid, $alasan, $namaOwner); $stmt->execute(); $stmt->close();
        responseOk('Blokir berhasil dibuka');
    }

    if ($aksi === 'blokir_manual') {
        $alasan    = trim($body['alasan'] ?? 'Diblokir manual oleh owner');
        $hari      = !empty($body['hari']) ? (int)$body['hari'] : null;
        $sampai    = $hari ? date('Y-m-d H:i:s', strtotime("+$hari days")) : null;
        $namaOwner = "owner:{$auth['user_id']}";
        $stmt = $db->prepare("UPDATE pelanggan SET is_diblokir=1, blokir_sampai=?, blokir_alasan=? WHERE id=?");
        $stmt->bind_param('ssi', $sampai, $alasan, $pid); $stmt->execute(); $stmt->close();
        $stmt = $db->prepare("INSERT INTO log_blokir_pelanggan (pelanggan_id, aksi, alasan, dilakukan_oleh) VALUES (?, 'blokir', ?, ?)");
        $stmt->bind_param('iss', $pid, $alasan, $namaOwner); $stmt->execute(); $stmt->close();
        responseOk('Pelanggan berhasil diblokir');
    }

    responseError('Aksi tidak valid');
}

responseError('Method tidak diizinkan', 405);