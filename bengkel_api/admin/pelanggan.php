<?php
// admin/pelanggan.php
// GET                    → list semua pelanggan (paginasi / search)
// GET ?id=X              → detail pelanggan + kendaraan
// GET ?id=X&riwayat=1    → detail + riwayat penalti
// PUT ?id=X              → buka blokir pelanggan

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../middleware/auth.php';

setCORSHeaders();
if (!in_array($_SERVER['REQUEST_METHOD'], ['GET', 'PUT']))
    responseError('Method tidak diizinkan', 405);

requireRole('admin');
$db = getDB();

// ── PUT: buka blokir ────────────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'PUT') {
    $id   = isset($_GET['id']) ? (int)$_GET['id'] : 0;
    $body = getRequestBody();
    if (!$id) responseError('Parameter id wajib diisi');

    $stmt = $db->prepare("SELECT id FROM pelanggan WHERE id=? LIMIT 1");
    $stmt->bind_param('i', $id);
    $stmt->execute();
    if (!$stmt->get_result()->fetch_assoc()) responseError('Pelanggan tidak ditemukan', 404);
    $stmt->close();

    $stmt = $db->prepare("
        UPDATE pelanggan
        SET is_diblokir=0, blokir_sampai=NULL, blokir_alasan=NULL
        WHERE id=?
    ");
    $stmt->bind_param('i', $id);
    $stmt->execute();
    $stmt->close();

    $alasan  = trim($body['alasan'] ?? 'Dibuka manual oleh admin');
    $oleh    = 'admin';
    $stmt = $db->prepare("
        INSERT INTO log_blokir_pelanggan (pelanggan_id, aksi, alasan, dilakukan_oleh)
        VALUES (?, 'buka_blokir', ?, ?)
    ");
    $stmt->bind_param('iss', $id, $alasan, $oleh);
    $stmt->execute();
    $stmt->close();

    $db->close();
    responseOk('Blokir pelanggan berhasil dibuka');
}

// ── GET detail ────────────────────────────────────────────
if (isset($_GET['id'])) {
    $id      = (int)$_GET['id'];
    $riwayat = !empty($_GET['riwayat']);

    $stmt = $db->prepare("
        SELECT id, nama, no_hp, email, alamat,
               is_aktif, is_diblokir, blokir_sampai,
               blokir_alasan, total_noshow, created_at
        FROM pelanggan WHERE id=? LIMIT 1
    ");
    $stmt->bind_param('i', $id);
    $stmt->execute();
    $pelanggan = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if (!$pelanggan) responseError('Pelanggan tidak ditemukan', 404);

    // Kendaraan
    $stmt = $db->prepare("
        SELECT id, merk, model, tahun, no_polisi, warna
        FROM kendaraan WHERE pelanggan_id=?
        ORDER BY created_at DESC
    ");
    $stmt->bind_param('i', $id);
    $stmt->execute();
    $kendaraan = [];
    $res = $stmt->get_result();
    while ($r = $res->fetch_assoc()) $kendaraan[] = $r;
    $stmt->close();

    $response = [
        'pelanggan' => $pelanggan,
        'kendaraan' => $kendaraan,
    ];

    if ($riwayat) {
        // Riwayat penalti
        $stmt = $db->prepare("
            SELECT pn.noshow_ke, pn.blokir_hari,
                   pn.blokir_mulai, pn.blokir_sampai, pn.created_at,
                   b.no_booking, b.tanggal_servis
            FROM penalti_noshow pn
            JOIN booking b ON b.id = pn.booking_id
            WHERE pn.pelanggan_id=?
            ORDER BY pn.created_at DESC
        ");
        $stmt->bind_param('i', $id);
        $stmt->execute();
        $penalti = [];
        $res = $stmt->get_result();
        while ($r = $res->fetch_assoc()) $penalti[] = $r;
        $stmt->close();
        $response['riwayat_penalti'] = $penalti;

        // Riwayat transaksi (booking yang sudah selesai pembayaran)
        $stmt = $db->prepare("
            SELECT t.id, t.no_nota AS no_transaksi, t.tanggal,
                   js.nama AS jenis_servis,
                   t.grand_total AS total_bayar,
                   t.status,
                   m.nama AS mekanik,
                   k.no_polisi
            FROM transaksi t
            LEFT JOIN servis sv  ON sv.id = t.servis_id
            LEFT JOIN booking b  ON b.id  = sv.booking_id
            LEFT JOIN jenis_servis js ON js.id = b.jenis_servis_id
            LEFT JOIN mekanik m  ON m.id  = sv.mekanik_id
            LEFT JOIN kendaraan k ON k.id = b.kendaraan_id
            WHERE t.pelanggan_id = ?
              AND t.tipe = 'servis'
            ORDER BY t.tanggal DESC
            LIMIT 50
        ");
        $stmt->bind_param('i', $id);
        $stmt->execute();
        $transaksi = [];
        $res = $stmt->get_result();
        while ($r = $res->fetch_assoc()) {
            $r['total_bayar'] = (float)$r['total_bayar'];
            $transaksi[] = $r;
        }
        $stmt->close();
        $response['riwayat_transaksi'] = $transaksi;

        // Booking aktif — semua booking yang belum selesai pembayaran
        // Status yang dianggap "aktif": menunggu, dikonfirmasi, aktif, dibatalkan, no_show
        // (selesai dikecualikan karena sudah ada riwayat transaksi)
        $stmt = $db->prepare("
            SELECT b.id, b.no_booking,
                   b.tanggal_servis, b.status, b.tipe,
                   b.keluhan, b.created_at,
                   -- kendaraan
                   k.merk, k.model, k.no_polisi, k.warna, k.tahun,
                   -- jenis servis
                   js.nama AS jenis_servis, js.harga_jasa,
                   -- slot waktu
                   sw.label AS slot_label,
                   sw.jam_mulai, sw.jam_selesai,
                   -- servis (progress)
                   sv.id   AS servis_id, sv.status AS status_servis,
                   sv.diagnosa, sv.waktu_mulai, sv.waktu_selesai,
                   m.nama  AS nama_mekanik
            FROM booking b
            JOIN kendaraan k     ON k.id = b.kendaraan_id
            LEFT JOIN jenis_servis js ON js.id = b.jenis_servis_id
            LEFT JOIN slot_waktu sw   ON sw.id = b.slot_id
            LEFT JOIN servis sv       ON sv.booking_id = b.id
            LEFT JOIN mekanik m       ON m.id = sv.mekanik_id
            WHERE b.pelanggan_id = ?
              AND b.status != 'selesai'
            ORDER BY b.tanggal_servis DESC, b.created_at DESC
        ");
        $stmt->bind_param('i', $id);
        $stmt->execute();
        $bookingAktif = [];
        $res = $stmt->get_result();
        while ($r = $res->fetch_assoc()) {
            $bookingId = (int)$r['id'];
            $r['id']        = $bookingId;
            $r['servis_id'] = $r['servis_id'] ? (int)$r['servis_id'] : null;
            $r['tahun']     = $r['tahun'] ? (int)$r['tahun'] : null;
            $r['harga_jasa']= $r['harga_jasa'] ? (float)$r['harga_jasa'] : null;

            // Sparepart request untuk booking ini
            $stmt2 = $db->prepare("
                SELECT bsr.id, sp.nama AS nama_sparepart, sp.satuan,
                       bsr.jumlah, bsr.harga_jual, bsr.subtotal, bsr.status
                FROM booking_sparepart_request bsr
                JOIN sparepart sp ON sp.id = bsr.sparepart_id
                WHERE bsr.booking_id = ?
                ORDER BY bsr.id ASC
            ");
            $stmt2->bind_param('i', $bookingId);
            $stmt2->execute();
            $spList = [];
            $res2 = $stmt2->get_result();
            while ($sp = $res2->fetch_assoc()) {
                $sp['jumlah']    = (int)$sp['jumlah'];
                $sp['harga_jual']= (float)$sp['harga_jual'];
                $sp['subtotal']  = (float)$sp['subtotal'];
                $spList[] = $sp;
            }
            $stmt2->close();

            $r['sparepart_request'] = $spList;
            $bookingAktif[] = $r;
        }
        $stmt->close();
        $response['booking_aktif'] = $bookingAktif;
    }

    $db->close();
    responseOk('OK', $response);
}

// ── GET list semua pelanggan ──────────────────────────────
$search   = trim($_GET['search'] ?? '');
$page     = max(1, (int)($_GET['page'] ?? 1));
$perPage  = 20;
$offset   = ($page - 1) * $perPage;
$filter   = trim($_GET['filter'] ?? 'semua'); // semua | aktif | diblokir

$where = 'WHERE is_aktif = 1';
$params = [];
$types  = '';

if ($filter === 'diblokir') {
    $where .= ' AND is_diblokir = 1';
} elseif ($filter === 'aktif') {
    $where .= ' AND is_diblokir = 0';
}

if ($search !== '') {
    $kw = '%' . $search . '%';
    $where .= ' AND (nama LIKE ? OR no_hp LIKE ? OR email LIKE ?)';
    $params = [$kw, $kw, $kw];
    $types  = 'sss';
}

// Count total
$countSql = "SELECT COUNT(*) AS total FROM pelanggan $where";
$stmt     = $db->prepare($countSql);
if ($types) $stmt->bind_param($types, ...$params);
$stmt->execute();
$total = (int)$stmt->get_result()->fetch_assoc()['total'];
$stmt->close();

// Data
$sql  = "
    SELECT id, nama, no_hp, email,
           is_diblokir, total_noshow,
           blokir_sampai, blokir_alasan, created_at
    FROM pelanggan
    $where
    ORDER BY nama ASC
    LIMIT ? OFFSET ?
";
$stmt = $db->prepare($sql);
$limitParams = array_merge($params, [$perPage, $offset]);
$limitTypes  = $types . 'ii';
$stmt->bind_param($limitTypes, ...$limitParams);
$stmt->execute();
$rows = [];
$res  = $stmt->get_result();
while ($r = $res->fetch_assoc()) {
    $r['id']          = (int)$r['id'];
    $r['is_diblokir'] = (bool)$r['is_diblokir'];
    $r['total_noshow']= (int)$r['total_noshow'];
    $rows[] = $r;
}
$stmt->close();
$db->close();

responseOk('OK', [
    'pelanggan'    => $rows,
    'total'        => $total,
    'page'         => $page,
    'per_page'     => $perPage,
    'total_halaman'=> (int)ceil($total / $perPage),
]);