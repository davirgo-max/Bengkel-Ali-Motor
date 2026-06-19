<?php
// admin/hari_libur.php — CRUD hari libur (admin only)
// GET    ?tahun=YYYY          → list libur dalam 1 tahun (default tahun ini)
// POST   {tanggal, keterangan}→ tambah libur manual
// DELETE ?id=N                → hapus 1 libur
// POST   {sync_api:true}      → sinkronisasi hari libur nasional dari API

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../middleware/auth.php';

setCORSHeaders();
requireRole('admin');

$db = getDB();

// ── GET: daftar hari libur ────────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $tahun = (int)($_GET['tahun'] ?? date('Y'));

    $stmt = $db->prepare("
        SELECT id, tanggal, keterangan, sumber, created_at
        FROM hari_libur
        WHERE YEAR(tanggal) = ?
        ORDER BY tanggal ASC
    ");
    $stmt->bind_param('i', $tahun);
    $stmt->execute();
    $result = $stmt->get_result();
    $rows = [];
    while ($r = $result->fetch_assoc()) $rows[] = $r;
    $stmt->close();
    $db->close();
    responseOk('OK', $rows);
}

// ── DELETE: hapus 1 hari libur ────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'DELETE') {
    $id = (int)($_GET['id'] ?? 0);
    if (!$id) responseError('ID wajib diisi');

    $stmt = $db->prepare("DELETE FROM hari_libur WHERE id = ?");
    $stmt->bind_param('i', $id);
    $stmt->execute();
    $affected = $stmt->affected_rows;
    $stmt->close();
    $db->close();

    if ($affected === 0) responseError('Data tidak ditemukan', 404);
    responseOk('Hari libur berhasil dihapus');
}

// ── POST: tambah manual ATAU sync API ────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $body = getRequestBody();

    // ── Sync hari libur nasional dari API publik ─────────
    if (!empty($body['sync_api'])) {
        $tahun = (int)($body['tahun'] ?? date('Y'));
        $items = $body['items'] ?? [];

        if (empty($items)) {
            responseError('Tidak ada data yang dikirim');
        }

        $inserted = 0;
        $skipped  = 0;

        $stmt = $db->prepare("
            INSERT INTO hari_libur (tanggal, keterangan, sumber)
            VALUES (?, ?, 'api')
            ON DUPLICATE KEY UPDATE
                keterangan = IF(sumber='api', VALUES(keterangan), keterangan),
                sumber     = IF(sumber='api', 'api', sumber)
        ");

        foreach ($items as $item) {
            $tgl = $item['tanggal'] ?? '';
            $ket = mb_substr($item['keterangan'] ?? '', 0, 150);
            if (!$tgl) continue;
            $stmt->bind_param('ss', $tgl, $ket);
            if ($stmt->execute()) {
                if ($stmt->affected_rows > 0) $inserted++;
                else $skipped++;
            }
        }
        $stmt->close();
        $db->close();

        responseOk("Sinkronisasi selesai: $inserted ditambahkan, $skipped sudah ada", [
            'inserted' => $inserted,
            'skipped'  => $skipped,
            'tahun'    => $tahun,
        ]);
    }

    // ── Tambah manual ────────────────────────────────────
    $tanggal    = trim($body['tanggal']    ?? '');
    $keterangan = trim($body['keterangan'] ?? '');

    if (!$tanggal)    responseError('Tanggal wajib diisi');
    if (!$keterangan) responseError('Keterangan wajib diisi');

    // Validasi format YYYY-MM-DD
    if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $tanggal)) {
        responseError('Format tanggal harus YYYY-MM-DD');
    }

    // Cek apakah hari Ahad (0 = Minggu)
    $hari = date('w', strtotime($tanggal));
    if ($hari === false) responseError('Tanggal tidak valid');

    // Cek duplikat
    $stmt = $db->prepare("SELECT id FROM hari_libur WHERE tanggal = ? LIMIT 1");
    $stmt->bind_param('s', $tanggal);
    $stmt->execute();
    if ($stmt->get_result()->num_rows > 0) {
        $stmt->close(); $db->close();
        responseError('Tanggal ini sudah ada di daftar hari libur');
    }
    $stmt->close();

    $sumber = 'manual';
    $stmt = $db->prepare("INSERT INTO hari_libur (tanggal, keterangan, sumber) VALUES (?, ?, ?)");
    $stmt->bind_param('sss', $tanggal, $keterangan, $sumber);
    if (!$stmt->execute()) {
        $stmt->close(); $db->close();
        responseError('Gagal menyimpan hari libur');
    }
    $newId = $stmt->insert_id;
    $stmt->close();
    $db->close();

    responseOk('Hari libur berhasil ditambahkan', [
        'id'         => $newId,
        'tanggal'    => $tanggal,
        'keterangan' => $keterangan,
        'sumber'     => 'manual',
    ]);
}

responseError('Method tidak diizinkan', 405);