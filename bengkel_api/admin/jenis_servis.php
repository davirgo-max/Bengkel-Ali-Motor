<?php
// admin/jenis_servis.php
// GET           → list semua jenis servis
// POST          → tambah jenis servis baru
// PUT ?id=X     → edit jenis servis / toggle aktif
// DELETE ?id=X  → hapus jenis servis (soft delete jika pernah dipakai)

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../middleware/auth.php';

setCORSHeaders();
$auth = requireRole('admin');
$db   = getDB();

// ── GET ───────────────────────────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $tampilkan = $_GET['tampilkan'] ?? 'semua'; // semua | aktif | nonaktif
    $where = '';
    if ($tampilkan === 'aktif')    $where = 'WHERE js.is_aktif = 1';
    if ($tampilkan === 'nonaktif') $where = 'WHERE js.is_aktif = 0';

    $result = $db->query("
        SELECT js.id, js.nama, js.deskripsi, js.harga_jasa,
               js.estimasi_menit, js.is_aktif, js.created_at,
               COUNT(b.id) AS jumlah_dipakai
        FROM jenis_servis js
        LEFT JOIN booking b ON b.jenis_servis_id = js.id
        $where
        GROUP BY js.id
        ORDER BY js.is_aktif DESC, js.nama ASC
    ");
    $rows = [];
    while ($r = $result->fetch_assoc()) {
        $r['harga_jasa']      = (float)$r['harga_jasa'];
        $r['estimasi_menit']  = (int)$r['estimasi_menit'];
        $r['is_aktif']        = (bool)$r['is_aktif'];
        $r['jumlah_dipakai']  = (int)$r['jumlah_dipakai'];
        $rows[] = $r;
    }
    $db->close();
    responseOk('OK', $rows);
}

// ── POST: tambah jenis servis ─────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $body          = getRequestBody();
    $nama          = trim($body['nama']           ?? '');
    $deskripsi     = trim($body['deskripsi']       ?? '') ?: null;
    $hargaJasa     = (float)($body['harga_jasa']   ?? 0);
    $estimasiMenit = (int)($body['estimasi_menit'] ?? 60);

    if (!$nama)             responseError('Nama jenis servis wajib diisi');
    if ($hargaJasa < 0)     responseError('Harga jasa tidak boleh negatif');
    if ($estimasiMenit <= 0) responseError('Estimasi waktu harus lebih dari 0 menit');

    // Cek nama duplikat
    $stmt = $db->prepare("SELECT id FROM jenis_servis WHERE nama=? LIMIT 1");
    $stmt->bind_param('s', $nama);
    $stmt->execute();
    if ($stmt->get_result()->num_rows > 0) {
        $stmt->close();
        responseError("Jenis servis '$nama' sudah terdaftar");
    }
    $stmt->close();

    $stmt = $db->prepare("
        INSERT INTO jenis_servis (nama, deskripsi, harga_jasa, estimasi_menit)
        VALUES (?, ?, ?, ?)
    ");
    $stmt->bind_param('ssdi', $nama, $deskripsi, $hargaJasa, $estimasiMenit);
    if (!$stmt->execute()) responseError('Gagal menyimpan jenis servis', 500);
    $newId = $stmt->insert_id;
    $stmt->close();
    $db->close();
    responseOk('Jenis servis berhasil ditambahkan', ['id' => $newId]);
}

// ── PUT: edit atau toggle aktif ───────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'PUT') {
    $id     = (int)($_GET['id'] ?? 0);
    $body   = getRequestBody();
    $action = trim($body['action'] ?? 'edit');
    if (!$id) responseError('ID jenis servis wajib diisi');

    $stmt = $db->prepare("SELECT id FROM jenis_servis WHERE id=? LIMIT 1");
    $stmt->bind_param('i', $id);
    $stmt->execute();
    if ($stmt->get_result()->num_rows === 0) {
        $stmt->close();
        responseError('Jenis servis tidak ditemukan', 404);
    }
    $stmt->close();

    if ($action === 'toggle_aktif') {
        $aktif = (int)($body['is_aktif'] ?? 0);
        $stmt  = $db->prepare("UPDATE jenis_servis SET is_aktif=? WHERE id=?");
        $stmt->bind_param('ii', $aktif, $id);
        $stmt->execute(); $stmt->close();
        $db->close();
        responseOk($aktif ? 'Jenis servis diaktifkan' : 'Jenis servis dinonaktifkan');
    }

    // Default: edit data
    $nama          = trim($body['nama']           ?? '');
    $deskripsi     = trim($body['deskripsi']       ?? '') ?: null;
    $hargaJasa     = (float)($body['harga_jasa']   ?? 0);
    $estimasiMenit = (int)($body['estimasi_menit'] ?? 60);

    if (!$nama)             responseError('Nama jenis servis wajib diisi');
    if ($hargaJasa < 0)     responseError('Harga jasa tidak boleh negatif');
    if ($estimasiMenit <= 0) responseError('Estimasi waktu harus lebih dari 0 menit');

    // Cek duplikat nama di jenis servis lain
    $stmt = $db->prepare("SELECT id FROM jenis_servis WHERE nama=? AND id!=? LIMIT 1");
    $stmt->bind_param('si', $nama, $id);
    $stmt->execute();
    if ($stmt->get_result()->num_rows > 0) {
        $stmt->close();
        responseError("Nama '$nama' sudah digunakan jenis servis lain");
    }
    $stmt->close();

    $stmt = $db->prepare("
        UPDATE jenis_servis
        SET nama=?, deskripsi=?, harga_jasa=?, estimasi_menit=?
        WHERE id=?
    ");
    $stmt->bind_param('ssdii', $nama, $deskripsi, $hargaJasa, $estimasiMenit, $id);
    $stmt->execute(); $stmt->close();
    $db->close();
    responseOk('Jenis servis berhasil diupdate');
}

// ── DELETE ────────────────────────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'DELETE') {
    $id = (int)($_GET['id'] ?? 0);
    if (!$id) responseError('ID jenis servis wajib diisi');

    // Cek apakah pernah dipakai di booking
    $stmt = $db->prepare("SELECT id FROM booking WHERE jenis_servis_id=? LIMIT 1");
    $stmt->bind_param('i', $id);
    $stmt->execute();
    $pernahDipakai = $stmt->get_result()->num_rows > 0;
    $stmt->close();

    if ($pernahDipakai) {
        // Soft delete — nonaktifkan saja agar riwayat booking/servis tidak rusak
        $stmt = $db->prepare("UPDATE jenis_servis SET is_aktif=0 WHERE id=?");
        $stmt->bind_param('i', $id);
        $stmt->execute(); $stmt->close();
        $db->close();
        responseOk('Jenis servis dinonaktifkan (pernah digunakan pada booking)');
    }

    $stmt = $db->prepare("DELETE FROM jenis_servis WHERE id=?");
    $stmt->bind_param('i', $id);
    $stmt->execute();
    $affected = $stmt->affected_rows;
    $stmt->close(); $db->close();

    if ($affected === 0) responseError('Jenis servis tidak ditemukan', 404);
    responseOk('Jenis servis berhasil dihapus');
}

responseError('Method tidak diizinkan', 405);
