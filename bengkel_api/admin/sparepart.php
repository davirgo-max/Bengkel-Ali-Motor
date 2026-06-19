<?php
// owner/sparepart.php
// GET               → list semua sparepart + kategori
// GET ?id=X         → detail 1 sparepart
// POST              → tambah sparepart baru
// PUT ?id=X         → edit sparepart
// DELETE ?id=X      → hapus sparepart (soft delete: is_aktif=0)

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../middleware/auth.php';

setCORSHeaders();
$auth = requireRole('admin');
$db   = getDB();

// ── GET ───────────────────────────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'GET') {

    // Detail 1 sparepart
    if (isset($_GET['id'])) {
        $id   = (int)$_GET['id'];
        $stmt = $db->prepare("
            SELECT s.*, k.nama AS kategori_nama
            FROM sparepart s
            LEFT JOIN kategori_sparepart k ON k.id = s.kategori_id
            WHERE s.id = ? LIMIT 1
        ");
        $stmt->bind_param('i', $id);
        $stmt->execute();
        $row = $stmt->get_result()->fetch_assoc();
        $stmt->close();
        if (!$row) responseError('Sparepart tidak ditemukan', 404);
        responseOk('OK', $row);
    }

    // List semua + filter
    $search    = trim($_GET['search']       ?? '');
    $kategori  = !empty($_GET['kategori_id']) ? (int)$_GET['kategori_id'] : null;
    $tampilkan = $_GET['tampilkan'] ?? 'semua'; // semua | aktif | nonaktif

    $where  = [];
    $params = [];
    $types  = '';

    if ($tampilkan === 'aktif')    { $where[] = 's.is_aktif = 1'; }
    if ($tampilkan === 'nonaktif') { $where[] = 's.is_aktif = 0'; }

    if ($search) {
        $kw       = '%' . $search . '%';
        $where[]  = '(s.nama LIKE ? OR s.kode LIKE ?)';
        $params[] = $kw; $params[] = $kw;
        $types   .= 'ss';
    }

    if ($kategori) {
        $where[]  = 's.kategori_id = ?';
        $params[] = $kategori;
        $types   .= 'i';
    }

    $whereSQL = $where ? 'WHERE ' . implode(' AND ', $where) : '';
    $sql = "
        SELECT s.id, s.kode, s.nama, s.satuan,
               s.harga_beli, s.harga_jual, s.stok,
               s.stok_minimum, s.foto, s.is_aktif,
               k.nama AS kategori_nama,
               (s.stok <= s.stok_minimum) AS stok_menipis
        FROM sparepart s
        LEFT JOIN kategori_sparepart k ON k.id = s.kategori_id
        $whereSQL
        ORDER BY k.nama, s.nama
    ";

    if ($types) {
        $stmt = $db->prepare($sql);
        $stmt->bind_param($types, ...$params);
        $stmt->execute();
        $result = $stmt->get_result();
    } else {
        $result = $db->query($sql);
    }

    $rows = [];
    while ($r = $result->fetch_assoc()) {
        $r['is_aktif']     = (bool)$r['is_aktif'];
        $r['stok_menipis'] = (bool)$r['stok_menipis'];
        $rows[] = $r;
    }
    if (isset($stmt)) $stmt->close();

    // List kategori untuk filter dropdown
    $katRes   = $db->query("SELECT id, nama FROM kategori_sparepart ORDER BY nama");
    $kategori = [];
    while ($k = $katRes->fetch_assoc()) $kategori[] = $k;

    $db->close();
    responseOk('OK', [
        'sparepart' => $rows,
        'kategori'  => $kategori,
        'total'     => count($rows),
    ]);
}

// ── POST: tambah sparepart ────────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $body        = getRequestBody();
    $kode        = strtoupper(trim($body['kode']        ?? ''));
    $nama        = trim($body['nama']                   ?? '');
    $kategoriId  = !empty($body['kategori_id']) ? (int)$body['kategori_id'] : null;
    $satuan      = trim($body['satuan']                 ?? 'pcs');
    $hargaBeli   = (float)($body['harga_beli']          ?? 0);
    $hargaJual   = (float)($body['harga_jual']          ?? 0);
    $stok        = (int)($body['stok']                  ?? 0);
    $stokMin     = (int)($body['stok_minimum']          ?? 5);
    $deskripsi   = trim($body['deskripsi']              ?? '') ?: null;

    if (!$kode || !$nama) responseError('Kode dan nama wajib diisi');
    if ($hargaJual <= 0)  responseError('Harga jual harus lebih dari 0');

    // Cek kode duplikat
    $stmt = $db->prepare("SELECT id FROM sparepart WHERE kode=? LIMIT 1");
    $stmt->bind_param('s', $kode);
    $stmt->execute();
    if ($stmt->get_result()->num_rows > 0) {
        $stmt->close();
        responseError("Kode '$kode' sudah digunakan");
    }
    $stmt->close();

    $stmt = $db->prepare("
        INSERT INTO sparepart
          (kategori_id, kode, nama, deskripsi, satuan,
           harga_beli, harga_jual, stok, stok_minimum)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ");
    $stmt->bind_param('issssddii',
        $kategoriId, $kode, $nama, $deskripsi, $satuan,
        $hargaBeli, $hargaJual, $stok, $stokMin
    );
    if (!$stmt->execute()) responseError('Gagal menyimpan sparepart', 500);
    $newId = $stmt->insert_id;
    $stmt->close();
    $db->close();

    responseOk('Sparepart berhasil ditambahkan', ['id' => $newId]);
}

// ── PUT: edit sparepart ───────────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'PUT') {
    $id   = (int)($_GET['id'] ?? 0);
    $body = getRequestBody();
    if (!$id) responseError('ID sparepart wajib diisi');

    $stmt = $db->prepare("SELECT id FROM sparepart WHERE id=? LIMIT 1");
    $stmt->bind_param('i', $id);
    $stmt->execute();
    if ($stmt->get_result()->num_rows === 0) {
        $stmt->close();
        responseError('Sparepart tidak ditemukan', 404);
    }
    $stmt->close();

    $kode       = strtoupper(trim($body['kode']       ?? ''));
    $nama       = trim($body['nama']                  ?? '');
    $kategoriId = !empty($body['kategori_id']) ? (int)$body['kategori_id'] : null;
    $satuan     = trim($body['satuan']                ?? 'pcs');
    $hargaBeli  = (float)($body['harga_beli']         ?? 0);
    $hargaJual  = (float)($body['harga_jual']         ?? 0);
    $stokMin    = (int)($body['stok_minimum']         ?? 5);
    $deskripsi  = trim($body['deskripsi']             ?? '') ?: null;
    $isAktif    = isset($body['is_aktif']) ? (int)$body['is_aktif'] : 1;

    if (!$kode || !$nama) responseError('Kode dan nama wajib diisi');

    // Cek kode duplikat di sparepart lain
    $stmt = $db->prepare("SELECT id FROM sparepart WHERE kode=? AND id!=? LIMIT 1");
    $stmt->bind_param('si', $kode, $id);
    $stmt->execute();
    if ($stmt->get_result()->num_rows > 0) {
        $stmt->close();
        responseError("Kode '$kode' sudah digunakan sparepart lain");
    }
    $stmt->close();

    $stmt = $db->prepare("
        UPDATE sparepart SET
            kategori_id=?, kode=?, nama=?, deskripsi=?,
            satuan=?, harga_beli=?, harga_jual=?,
            stok_minimum=?, is_aktif=?
        WHERE id=?
    ");
    $stmt->bind_param('issssddiii',
        $kategoriId, $kode, $nama, $deskripsi, $satuan,
        $hargaBeli, $hargaJual, $stokMin, $isAktif, $id
    );
    $stmt->execute(); $stmt->close();
    $db->close();

    responseOk('Sparepart berhasil diupdate');
}

// ── DELETE: nonaktifkan sparepart ─────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'DELETE') {
    $id = (int)($_GET['id'] ?? 0);
    if (!$id) responseError('ID sparepart wajib diisi');

    // Cek apakah pernah dipakai di servis
    $stmt = $db->prepare("SELECT id FROM servis_sparepart WHERE sparepart_id=? LIMIT 1");
    $stmt->bind_param('i', $id);
    $stmt->execute();
    $pernah = $stmt->get_result()->num_rows > 0;
    $stmt->close();

    if ($pernah) {
        // Soft delete — nonaktifkan saja agar riwayat tidak rusak
        $stmt = $db->prepare("UPDATE sparepart SET is_aktif=0 WHERE id=?");
        $stmt->bind_param('i', $id);
        $stmt->execute(); $stmt->close();
        $db->close();
        responseOk('Sparepart dinonaktifkan (pernah digunakan di servis)');
    }

    // Hard delete jika belum pernah dipakai
    $stmt = $db->prepare("DELETE FROM sparepart WHERE id=?");
    $stmt->bind_param('i', $id);
    $stmt->execute();
    $affected = $stmt->affected_rows;
    $stmt->close(); $db->close();

    if ($affected === 0) responseError('Sparepart tidak ditemukan', 404);
    responseOk('Sparepart berhasil dihapus');
}

responseError('Method tidak diizinkan', 405);