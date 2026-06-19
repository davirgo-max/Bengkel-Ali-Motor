<?php
// kasir/jual_sparepart.php
// POST → proses transaksi penjualan sparepart non-servis (eceran)
//
// Body JSON:
// {
//   "items": [
//     { "sparepart_id": 1, "jumlah": 2, "harga_jual": 50000 },
//     ...
//   ],
//   "metode_bayar": "cash" | "transfer",
//   "jumlah_bayar": 120000
// }
//
// Response sukses:
// {
//   "success": true,
//   "data": {
//     "transaksi_id": 10,
//     "no_nota": "NT-20260611-003",
//     "grand_total": 100000,
//     "jumlah_bayar": 120000,
//     "kembalian": 20000,
//     "metode_bayar": "cash",
//     "tanggal": "2026-06-11 14:30:00"
//   }
// }

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../middleware/auth.php';

setCORSHeaders();

$auth    = requireRole('kasir', 'owner');
$kasirId = $auth['user_id'];

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    responseError('Method tidak diizinkan', 405);
}

$body        = getRequestBody();
$items       = $body['items']       ?? [];
$metodeBayar = trim($body['metode_bayar'] ?? 'cash');
$jumlahBayar = (float)($body['jumlah_bayar'] ?? 0);

// ── Validasi input dasar ──────────────────────────────────
if (empty($items) || !is_array($items)) {
    responseError('Items tidak boleh kosong');
}
if (!in_array($metodeBayar, ['cash', 'transfer'])) {
    responseError('Metode bayar tidak valid');
}

// ── Validasi kas harian sudah dibuka ─────────────────────
$db = getDB();

$kasStmt = $db->prepare(
    "SELECT id FROM kas_harian WHERE tanggal = CURDATE() AND status = 'terbuka' LIMIT 1"
);
$kasStmt->execute();
$kasStmt->store_result();
if ($kasStmt->num_rows === 0) {
    $kasStmt->close();
    $db->close();
    responseError('Kas harian belum dibuka. Buka kas terlebih dahulu.');
}
$kasStmt->close();

// ── Validasi setiap item & hitung total ──────────────────
$totalSparepart = 0.0;
$validItems     = [];

foreach ($items as $item) {
    $sparepartId = (int)($item['sparepart_id'] ?? 0);
    $jumlah      = (int)($item['jumlah']       ?? 0);
    $hargaJual   = (float)($item['harga_jual'] ?? 0);

    if ($sparepartId <= 0 || $jumlah <= 0 || $hargaJual <= 0) {
        $db->close();
        responseError("Item tidak valid (sparepart_id=$sparepartId, jumlah=$jumlah)");
    }

    // Cek stok tersedia
    $stmtCek = $db->prepare(
        "SELECT stok FROM sparepart WHERE id = ? AND is_aktif = 1 LIMIT 1"
    );
    $stmtCek->bind_param('i', $sparepartId);
    $stmtCek->execute();
    $row = $stmtCek->get_result()->fetch_assoc();
    $stmtCek->close();

    if (!$row) {
        $db->close();
        responseError("Sparepart ID $sparepartId tidak ditemukan atau tidak aktif");
    }
    if ($row['stok'] < $jumlah) {
        $db->close();
        responseError("Stok tidak mencukupi untuk sparepart ID $sparepartId (stok: {$row['stok']}, diminta: $jumlah)");
    }

    $subtotal        = $hargaJual * $jumlah;
    $totalSparepart += $subtotal;

    $validItems[] = [
        'sparepart_id' => $sparepartId,
        'jumlah'       => $jumlah,
        'harga_jual'   => $hargaJual,
        'subtotal'     => $subtotal,
    ];
}

$grandTotal = $totalSparepart;
$kembalian  = max(0.0, $jumlahBayar - $grandTotal);

if ($metodeBayar === 'cash' && $jumlahBayar < $grandTotal) {
    $db->close();
    responseError('Jumlah bayar kurang dari total tagihan');
}

// ── Mulai transaksi DB ────────────────────────────────────
$db->begin_transaction();

try {
    // Generate no_nota: NT-YYYYMMDD-XXX
    $countRow = $db->query(
        "SELECT COUNT(*) AS c FROM transaksi WHERE DATE(tanggal) = CURDATE()"
    )->fetch_assoc();
    $noNota = 'NT-' . date('Ymd') . '-' . str_pad((int)$countRow['c'] + 1, 3, '0', STR_PAD_LEFT);

    // Simpan ke tabel transaksi (tipe = 'penjualan_sparepart', servis_id = NULL)
    $stmtTrx = $db->prepare("
        INSERT INTO transaksi
          (no_nota, servis_id, kasir_id, pelanggan_id, tipe,
           total_jasa, total_sparepart, diskon, grand_total,
           metode_bayar, jumlah_bayar, kembalian, status, tanggal)
        VALUES (?, NULL, ?, NULL, 'penjualan_sparepart',
                0, ?, 0, ?,
                ?, ?, ?, 'lunas', NOW())
    ");
    $stmtTrx->bind_param(
        'siddsdd',
        $noNota, $kasirId,
        $totalSparepart, $grandTotal,
        $metodeBayar, $jumlahBayar, $kembalian
    );
    if (!$stmtTrx->execute()) {
        throw new Exception('Gagal menyimpan transaksi: ' . $stmtTrx->error);
    }
    $trxId = $stmtTrx->insert_id;
    $stmtTrx->close();

    // Simpan detail item ke transaksi_sparepart_langsung & kurangi stok
    $stmtDetail = $db->prepare("
        INSERT INTO transaksi_sparepart_langsung
          (transaksi_id, sparepart_id, jumlah, harga_jual, subtotal)
        VALUES (?, ?, ?, ?, ?)
    ");
    
    foreach ($validItems as $vi) {
        $stmtDetail->bind_param(
            'iiidd',
            $trxId,
            $vi['sparepart_id'],
            $vi['jumlah'],
            $vi['harga_jual'],
            $vi['subtotal']
        );
        if (!$stmtDetail->execute()) {
            throw new Exception('Gagal menyimpan detail item: ' . $stmtDetail->error);
        }
    }
    $stmtDetail->close();

    // Update kas harian
    $stmtKas = $db->prepare("
        UPDATE kas_harian
        SET total_pemasukan  = total_pemasukan + ?,
            kas_akhir_sistem = kas_awal + (total_pemasukan + ?)
        WHERE tanggal = CURDATE() AND status = 'terbuka'
    ");
    $stmtKas->bind_param('dd', $grandTotal, $grandTotal);
    if (!$stmtKas->execute()) {
        throw new Exception('Gagal update kas harian: ' . $stmtKas->error);
    }
    $stmtKas->close();

    $db->commit();

    // Ambil tanggal dari DB supaya format konsisten
    $tanggalRow = $db->query(
        "SELECT tanggal FROM transaksi WHERE id = $trxId LIMIT 1"
    )->fetch_assoc();
    $db->close();

    responseOk('Transaksi berhasil', [
        'transaksi_id' => $trxId,
        'no_nota'      => $noNota,
        'grand_total'  => $grandTotal,
        'jumlah_bayar' => $jumlahBayar,
        'kembalian'    => $kembalian,
        'metode_bayar' => $metodeBayar,
        'tanggal'      => $tanggalRow['tanggal'] ?? date('Y-m-d H:i:s'),
    ]);

} catch (Exception $e) {
    $db->rollback();
    $db->close();
    responseError($e->getMessage(), 500);
}