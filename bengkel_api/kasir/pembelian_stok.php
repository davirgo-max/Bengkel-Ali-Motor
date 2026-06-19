<?php
// kasir/pembelian_stok.php

require_once __DIR__ . '/../config/database.php';   // FIX: db.php → database.php (sesuai file yang ada)
require_once __DIR__ . '/../middleware/auth.php';

// FIX: requireAuth(['kasir','owner']) tidak valid karena requireAuth() tidak
//      menerima parameter. Gunakan requireRole() yang memang menerima variadic role.
$user   = requireRole('kasir', 'owner');
$method = $_SERVER['REQUEST_METHOD'];

header('Content-Type: application/json');

// Ambil koneksi PDO dari helper di database.php
// database.php menyediakan getDB() yang return mysqli, sedangkan query di file ini
// menggunakan PDO. Buat koneksi PDO sendiri agar konsisten.
try {
    $pdo = new PDO(
        'mysql:host=' . DB_HOST . ';dbname=' . DB_NAME . ';charset=utf8mb4',
        DB_USER,
        DB_PASS,
        [
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        ]
    );
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Koneksi DB gagal: ' . $e->getMessage()]);
    exit;
}

// ── GET — Riwayat pembelian ──────────────────────────────────────────────────
if ($method === 'GET') {
    $dari   = $_GET['dari']   ?? date('Y-m-d');
    $sampai = $_GET['sampai'] ?? $dari;

    $stmt = $pdo->prepare("
        SELECT
            p.id, p.no_pembelian, p.tanggal, p.supplier,
            p.total, p.keterangan,
            u.nama AS nama_kasir
        FROM pembelian_stok p
        JOIN users u ON u.id = p.user_id
        WHERE p.tanggal BETWEEN :dari AND :sampai
        ORDER BY p.created_at DESC
    ");
    $stmt->execute([':dari' => $dari, ':sampai' => $sampai]);
    $rows = $stmt->fetchAll();

    // Attach detail per pembelian
    foreach ($rows as &$row) {
        $dStmt = $pdo->prepare("
            SELECT d.id, d.sparepart_id, s.nama, s.satuan,
                   d.jumlah, d.harga_beli, d.subtotal
            FROM detail_pembelian_stok d
            JOIN sparepart s ON s.id = d.sparepart_id
            WHERE d.pembelian_id = :pid
        ");
        $dStmt->execute([':pid' => $row['id']]);
        $row['details'] = $dStmt->fetchAll();
    }
    unset($row); // putus referensi foreach

    echo json_encode(['success' => true, 'data' => $rows]);
    exit;
}

// ── POST — Catat pembelian baru ──────────────────────────────────────────────
if ($method === 'POST') {
    $body = json_decode(file_get_contents('php://input'), true);

    $items      = $body['items']      ?? [];
    $supplier   = trim($body['supplier']   ?? '');
    $keterangan = trim($body['keterangan'] ?? '');
    $tanggal    = $body['tanggal']    ?? date('Y-m-d');

    if (empty($items)) {
        http_response_code(422);
        echo json_encode(['success' => false, 'message' => 'Items tidak boleh kosong']);
        exit;
    }

    // Validasi tiap item
    foreach ($items as $item) {
        if (empty($item['sparepart_id']) || empty($item['jumlah']) || !isset($item['harga_beli'])) {
            http_response_code(422);
            echo json_encode(['success' => false, 'message' => 'Data item tidak lengkap']);
            exit;
        }
        if ((int)$item['jumlah'] <= 0 || (float)$item['harga_beli'] < 0) {
            http_response_code(422);
            echo json_encode(['success' => false, 'message' => 'Jumlah/harga tidak valid']);
            exit;
        }
    }

    // Generate no_pembelian: PB-YYYYMMDD-XXX
    $tglKode = date('Ymd', strtotime($tanggal));
    $cntStmt = $pdo->prepare(
        "SELECT COUNT(*) FROM pembelian_stok WHERE DATE(tanggal) = :tgl"
    );
    $cntStmt->execute([':tgl' => $tanggal]);
    $urut        = ((int)$cntStmt->fetchColumn()) + 1;
    $noPembelian = 'PB-' . $tglKode . '-' . str_pad($urut, 3, '0', STR_PAD_LEFT);

    // Hitung total
    $total = 0;
    foreach ($items as $item) {
        $total += (float)$item['harga_beli'] * (int)$item['jumlah'];
    }

    $pdo->beginTransaction();
    try {
        // Insert header
        $ins = $pdo->prepare("
            INSERT INTO pembelian_stok (no_pembelian, user_id, supplier, tanggal, total, keterangan)
            VALUES (:no, :uid, :sup, :tgl, :total, :ket)
        ");
        $ins->execute([
            ':no'    => $noPembelian,
            ':uid'   => $user['user_id'],   // FIX: requireRole() return key 'user_id', bukan 'id'
            ':sup'   => $supplier  ?: null,
            ':tgl'   => $tanggal,
            ':total' => $total,
            ':ket'   => $keterangan ?: null,
        ]);
        $pembelianId = (int)$pdo->lastInsertId();

        // Insert detail + update stok
        $detailIns = $pdo->prepare("
            INSERT INTO detail_pembelian_stok (pembelian_id, sparepart_id, jumlah, harga_beli, subtotal)
            VALUES (:pid, :sid, :jml, :harga, :sub)
        ");
        $stokUpd = $pdo->prepare("
            UPDATE sparepart SET stok = stok + :jml, harga_beli = :harga, updated_at = NOW()
            WHERE id = :sid
        ");

        foreach ($items as $item) {
            $sub = (float)$item['harga_beli'] * (int)$item['jumlah'];
            $detailIns->execute([
                ':pid'   => $pembelianId,
                ':sid'   => (int)$item['sparepart_id'],
                ':jml'   => (int)$item['jumlah'],
                ':harga' => (float)$item['harga_beli'],
                ':sub'   => $sub,
            ]);
            $stokUpd->execute([
                ':jml'   => (int)$item['jumlah'],
                ':harga' => (float)$item['harga_beli'],
                ':sid'   => (int)$item['sparepart_id'],
            ]);
        }

        $pdo->commit();
        echo json_encode([
            'success' => true,
            'message' => 'Pembelian berhasil dicatat',
            'data'    => [
                'id'          => $pembelianId,
                'no_pembelian' => $noPembelian,
                'total'        => $total,
            ],
        ]);
    } catch (Exception $e) {
        $pdo->rollBack();
        http_response_code(500);
        echo json_encode(['success' => false, 'message' => 'Gagal menyimpan: ' . $e->getMessage()]);
    }
    exit;
}

http_response_code(405);
echo json_encode(['success' => false, 'message' => 'Method tidak diizinkan']);