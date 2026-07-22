<?php
// admin/mekanik.php
// GET           → list semua mekanik
// POST          → tambah mekanik baru
// PUT ?id=X     → edit mekanik / toggle aktif
// DELETE ?id=X  → hapus mekanik (soft delete jika pernah dipakai)

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../middleware/auth.php';

setCORSHeaders();
$auth = requireRole('admin');
$db   = getDB();

// ── GET ───────────────────────────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $tampilkan = $_GET['tampilkan'] ?? 'aktif'; // aktif | nonaktif | semua
    $where = match ($tampilkan) {
        'nonaktif' => 'WHERE m.is_aktif = 0',
        'semua'    => '',
        default    => 'WHERE m.is_aktif = 1',
    };

    $result = $db->query("
        SELECT m.id, m.nama, m.no_hp, m.spesialisasi,
               m.is_aktif, m.created_at,
               COUNT(s.id) AS jumlah_servis
        FROM mekanik m
        LEFT JOIN servis s ON s.mekanik_id = m.id
        $where
        GROUP BY m.id
        ORDER BY m.is_aktif DESC, m.nama ASC
    ");
    $rows = [];
    while ($r = $result->fetch_assoc()) {
        $r['is_aktif']      = (bool)$r['is_aktif'];
        $r['jumlah_servis'] = (int)$r['jumlah_servis'];
        $rows[] = $r;
    }
    $db->close();
    responseOk('OK', $rows);
}

// ── POST: tambah mekanik ──────────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $body        = getRequestBody();
    $nama        = trim($body['nama']         ?? '');
    $noHp        = trim($body['no_hp']        ?? '') ?: null;
    $spesialisasi = trim($body['spesialisasi'] ?? '') ?: null;

    if (!$nama) responseError('Nama mekanik wajib diisi');
    if ($noHp !== null && !preg_match('/^[0-9+\-\s]{8,15}$/', $noHp)) {
        responseError('No. HP tidak valid (gunakan angka, 8-15 digit)');
    }

    // Cek nama duplikat
    $stmt = $db->prepare("SELECT id FROM mekanik WHERE nama=? LIMIT 1");
    $stmt->bind_param('s', $nama);
    $stmt->execute();
    if ($stmt->get_result()->num_rows > 0) {
        $stmt->close();
        responseError("Nama mekanik '$nama' sudah terdaftar");
    }
    $stmt->close();

    $stmt = $db->prepare("
        INSERT INTO mekanik (nama, no_hp, spesialisasi) VALUES (?, ?, ?)
    ");
    $stmt->bind_param('sss', $nama, $noHp, $spesialisasi);
    if (!$stmt->execute()) responseError('Gagal menyimpan mekanik', 500);
    $newId = $stmt->insert_id;
    $stmt->close();
    $db->close();
    responseOk('Mekanik berhasil ditambahkan', ['id' => $newId]);
}

// ── PUT: edit atau toggle aktif ───────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'PUT') {
    $id     = (int)($_GET['id'] ?? 0);
    $body   = getRequestBody();
    $action = trim($body['action'] ?? 'edit');
    if (!$id) responseError('ID mekanik wajib diisi');

    $stmt = $db->prepare("SELECT id FROM mekanik WHERE id=? LIMIT 1");
    $stmt->bind_param('i', $id);
    $stmt->execute();
    if ($stmt->get_result()->num_rows === 0) {
        $stmt->close();
        responseError('Mekanik tidak ditemukan', 404);
    }
    $stmt->close();

    if ($action === 'toggle_aktif') {
        $aktif = (int)($body['is_aktif'] ?? 0);
        $stmt  = $db->prepare("UPDATE mekanik SET is_aktif=? WHERE id=?");
        $stmt->bind_param('ii', $aktif, $id);
        $stmt->execute(); $stmt->close();
        $db->close();
        responseOk($aktif ? 'Mekanik diaktifkan' : 'Mekanik dinonaktifkan');
    }

    // Default: edit data
    $nama         = trim($body['nama']         ?? '');
    $noHp         = trim($body['no_hp']        ?? '') ?: null;
    $spesialisasi  = trim($body['spesialisasi'] ?? '') ?: null;

    if (!$nama) responseError('Nama mekanik wajib diisi');
    if ($noHp !== null && !preg_match('/^[0-9+\-\s]{8,15}$/', $noHp)) {
        responseError('No. HP tidak valid (gunakan angka, 8-15 digit)');
    }

    // Cek duplikat nama di mekanik lain
    $stmt = $db->prepare("SELECT id FROM mekanik WHERE nama=? AND id!=? LIMIT 1");
    $stmt->bind_param('si', $nama, $id);
    $stmt->execute();
    if ($stmt->get_result()->num_rows > 0) {
        $stmt->close();
        responseError("Nama '$nama' sudah digunakan mekanik lain");
    }
    $stmt->close();

    $stmt = $db->prepare("
        UPDATE mekanik SET nama=?, no_hp=?, spesialisasi=? WHERE id=?
    ");
    $stmt->bind_param('sssi', $nama, $noHp, $spesialisasi, $id);
    $stmt->execute(); $stmt->close();
    $db->close();
    responseOk('Data mekanik berhasil diupdate');
}

// ── DELETE ────────────────────────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'DELETE') {
    $id = (int)($_GET['id'] ?? 0);
    if (!$id) responseError('ID mekanik wajib diisi');

    // Cek apakah mekanik pernah dipakai di servis
    $stmt = $db->prepare("SELECT id FROM servis WHERE mekanik_id=? LIMIT 1");
    $stmt->bind_param('i', $id);
    $stmt->execute();
    $pernahDipakai = $stmt->get_result()->num_rows > 0;
    $stmt->close();

    if ($pernahDipakai) {
        // Soft delete — nonaktifkan saja agar riwayat servis tidak rusak
        $stmt = $db->prepare("UPDATE mekanik SET is_aktif=0 WHERE id=?");
        $stmt->bind_param('i', $id);
        $stmt->execute(); $stmt->close();
        $db->close();
        responseOk('Mekanik dinonaktifkan (pernah menangani servis)');
    }

    $stmt = $db->prepare("DELETE FROM mekanik WHERE id=?");
    $stmt->bind_param('i', $id);
    $stmt->execute();
    $affected = $stmt->affected_rows;
    $stmt->close(); $db->close();

    if ($affected === 0) responseError('Mekanik tidak ditemukan', 404);
    responseOk('Mekanik berhasil dihapus');
}

responseError('Method tidak diizinkan', 405);