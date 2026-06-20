<?php
// kasir/booking.php
// GET               → list booking hari ini + summary
// GET ?id=X         → detail 1 booking
// PUT ?id=X         → update status (konfirmasi/aktifkan/no_show/batal/review_sparepart)
// POST              → buat walk-in baru (opsional: array sparepart → langsung insert ke servis_sparepart)

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../middleware/auth.php';
require_once __DIR__ . '/../config/penalti_helper.php';
require_once __DIR__ . '/../config/fcm_helper.php';

setCORSHeaders();
$auth    = requireRole('kasir', 'owner');
$kasirId = $auth['user_id'];
$db      = getDB();

// ── GET ───────────────────────────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    // Summary: jumlah booking per tanggal (untuk dot indikator strip)
    if (isset($_GET['mode']) && $_GET['mode'] === 'summary') {
        $dari   = $_GET['dari']   ?? date('Y-m-d');
        $sampai = $_GET['sampai'] ?? date('Y-m-d');
        $stmt   = $db->prepare("
            SELECT DATE(tanggal_servis) AS tgl, COUNT(*) AS total
            FROM booking
            WHERE tanggal_servis BETWEEN ? AND ?
              AND status NOT IN ('batal', 'no_show')
            GROUP BY DATE(tanggal_servis)
        ");
        $stmt->bind_param('ss', $dari, $sampai);
        $stmt->execute();
        $result = $stmt->get_result();
        $dots = [];
        while ($r = $result->fetch_assoc()) {
            $dots[$r['tgl']] = (int)$r['total'];
        }
        $stmt->close();
        $db->close();
        responseOk('OK', $dots);
    }

    // Detail 1 booking
    if (isset($_GET['id'])) {
        $id   = (int)$_GET['id'];
        $stmt = $db->prepare("
            SELECT b.*,
                   p.nama AS nama_pelanggan, p.no_hp,
                   p.is_diblokir, p.total_noshow,
                   k.merk, k.model, k.no_polisi, k.warna, k.tahun,
                   js.nama AS jenis_servis, js.harga_jasa,
                   sw.label AS slot_label, sw.jam_mulai, sw.jam_selesai,
                   s.id AS servis_id, s.status AS status_servis,
                   s.diagnosa, s.waktu_mulai, s.waktu_selesai,
                   m.nama AS nama_mekanik
            FROM booking b
            JOIN pelanggan p  ON p.id = b.pelanggan_id
            JOIN kendaraan k  ON k.id = b.kendaraan_id
            LEFT JOIN jenis_servis js ON js.id = b.jenis_servis_id
            LEFT JOIN slot_waktu sw   ON sw.id = b.slot_id
            LEFT JOIN servis s        ON s.booking_id = b.id
            LEFT JOIN mekanik m       ON m.id = s.mekanik_id
            WHERE b.id = ? LIMIT 1
        ");
        $stmt->bind_param('i', $id);
        $stmt->execute();
        $row = $stmt->get_result()->fetch_assoc();
        $stmt->close();
        if (!$row) responseError('Booking tidak ditemukan', 404);

        // Sertakan request sparepart dari pelanggan (jika ada)
        $stmtSp = $db->prepare("
            SELECT bsr.id, bsr.sparepart_id, sp.nama, sp.satuan,
                   bsr.jumlah, bsr.harga_jual, bsr.subtotal,
                   bsr.catatan, bsr.status, bsr.catatan_kasir
            FROM booking_sparepart_request bsr
            JOIN sparepart sp ON sp.id = bsr.sparepart_id
            WHERE bsr.booking_id = ?
            ORDER BY bsr.id ASC
        ");
        $stmtSp->bind_param('i', $id);
        $stmtSp->execute();
        $spRows = [];
        $resSp  = $stmtSp->get_result();
        while ($r = $resSp->fetch_assoc()) {
            $r['harga_jual'] = (float)$r['harga_jual'];
            $r['subtotal']   = (float)$r['subtotal'];
            $r['jumlah']     = (int)$r['jumlah'];
            $spRows[] = $r;
        }
        $stmtSp->close();

        $row['sparepart_request'] = $spRows;
        $db->close();
        responseOk('OK', $row);
    }

    // List booking per tanggal
    $tanggal = $_GET['tanggal'] ?? date('Y-m-d');
    $status  = $_GET['status']  ?? null;

    $where  = ['b.tanggal_servis = ?'];
    $params = [$tanggal];
    $types  = 's';
    if ($status) { $where[] = 'b.status = ?'; $params[] = $status; $types .= 's'; }

    $stmt = $db->prepare("
        SELECT b.id, b.no_booking, b.tanggal_servis,
               b.status, b.tipe, b.keluhan, b.created_at,
               p.nama AS nama_pelanggan, p.no_hp,
               k.merk, k.model, k.no_polisi,
               js.nama AS jenis_servis,
               sw.label AS slot_label, sw.jam_mulai,
               s.id AS servis_id, s.status AS status_servis,
               (SELECT COUNT(*) FROM booking_sparepart_request
                WHERE booking_id = b.id AND status = 'menunggu') AS part_request_menunggu
        FROM booking b
        JOIN pelanggan p  ON p.id = b.pelanggan_id
        JOIN kendaraan k  ON k.id = b.kendaraan_id
        LEFT JOIN jenis_servis js ON js.id = b.jenis_servis_id
        LEFT JOIN slot_waktu sw   ON sw.id = b.slot_id
        LEFT JOIN servis s        ON s.booking_id = b.id
        WHERE " . implode(' AND ', $where) . "
        ORDER BY sw.jam_mulai ASC, b.created_at ASC
    ");
    $stmt->bind_param($types, ...$params);
    $stmt->execute();
    $rows = [];
    $result = $stmt->get_result();
    while ($r = $result->fetch_assoc()) $rows[] = $r;
    $stmt->close();

    // Summary status
    $stmt = $db->prepare("
        SELECT status, COUNT(*) AS total
        FROM booking WHERE tanggal_servis = ?
        GROUP BY status
    ");
    $stmt->bind_param('s', $tanggal);
    $stmt->execute();
    $res     = $stmt->get_result();
    $summary = [];
    while ($r = $res->fetch_assoc()) $summary[$r['status']] = (int)$r['total'];
    $stmt->close();

    responseOk('OK', [
        'booking' => $rows,
        'summary' => $summary,
        'tanggal' => $tanggal,
    ]);
}

// ── PUT: update status booking ────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'PUT') {
    $id     = (int)($_GET['id'] ?? 0);
    $body   = getRequestBody();
    $action = trim($body['action'] ?? '');
    if (!$id) responseError('ID booking wajib diisi');

    $stmt = $db->prepare("SELECT id, status, pelanggan_id FROM booking WHERE id=? LIMIT 1");
    $stmt->bind_param('i', $id);
    $stmt->execute();
    $booking = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if (!$booking) responseError('Booking tidak ditemukan', 404);

    switch ($action) {
        case 'konfirmasi':
            if ($booking['status'] !== 'menunggu')
                responseError('Hanya booking berstatus "menunggu" yang bisa dikonfirmasi');
            $s = 'dikonfirmasi';
            $stmt = $db->prepare("UPDATE booking SET status=? WHERE id=?");
            $stmt->bind_param('si', $s, $id);
            $stmt->execute(); $stmt->close();

            // ── Notifikasi FCM ────────────────────────────────
            // Ambil detail booking (no_booking + tanggal) untuk isi pesan
            $stmtD = $db->prepare("SELECT no_booking, tanggal_servis FROM booking WHERE id=? LIMIT 1");
            $stmtD->bind_param('i', $id);
            $stmtD->execute();
            $bDetail = $stmtD->get_result()->fetch_assoc();
            $stmtD->close();
            if ($bDetail) {
                $tglFmt = date('d M Y', strtotime($bDetail['tanggal_servis']));
                kirimNotifikasi(
                    $db,
                    (int)$booking['pelanggan_id'],
                    'booking_konfirmasi',
                    'Booking Dikonfirmasi ✅',
                    "Booking #{$bDetail['no_booking']} untuk tanggal $tglFmt telah dikonfirmasi. Harap hadir tepat waktu.",
                    $id
                );
            }
            // ─────────────────────────────────────────────────

            responseOk('Booking dikonfirmasi');

        case 'aktifkan':
            if ($booking['status'] !== 'dikonfirmasi')
                responseError('Hanya booking "dikonfirmasi" yang bisa diaktifkan');
            $s = 'aktif';
            $stmt = $db->prepare("UPDATE booking SET status=? WHERE id=?");
            $stmt->bind_param('si', $s, $id);
            $stmt->execute(); $stmt->close();

            // Buat record servis jika belum ada, ambil ID-nya bagaimanapun
            $stmt = $db->prepare("SELECT id FROM servis WHERE booking_id=? LIMIT 1");
            $stmt->bind_param('i', $id);
            $stmt->execute();
            $row = $stmt->get_result()->fetch_assoc();
            $stmt->close();
            if ($row) {
                $servisId = (int)$row['id'];
            } else {
                $stmt = $db->prepare("INSERT INTO servis (booking_id, kasir_id) VALUES (?,?)");
                $stmt->bind_param('ii', $id, $kasirId);
                $stmt->execute();
                $servisId = $stmt->insert_id;
                $stmt->close();
            }

            // ── Auto-import sparepart request pelanggan ke servis_sparepart ──
            // Ambil semua request dari booking ini (semua status, termasuk menunggu)
            $stmtReq = $db->prepare("
                SELECT bsr.sparepart_id, bsr.jumlah, bsr.harga_jual, bsr.subtotal
                FROM booking_sparepart_request bsr
                WHERE bsr.booking_id = ?
            ");
            $stmtReq->bind_param('i', $id);
            $stmtReq->execute();
            $partRequests = $stmtReq->get_result()->fetch_all(MYSQLI_ASSOC);
            $stmtReq->close();

            if (!empty($partRequests)) {
                $stmtIns = $db->prepare("
                    INSERT IGNORE INTO servis_sparepart
                      (servis_id, sparepart_id, jumlah, harga_jual, subtotal,
                       sumber, status_persetujuan)
                    VALUES (?, ?, ?, ?, ?, 'request', 'disetujui')
                ");
                foreach ($partRequests as $req) {
                    $stmtIns->bind_param(
                        'iiidd',
                        $servisId,
                        $req['sparepart_id'],
                        $req['jumlah'],
                        $req['harga_jual'],
                        $req['subtotal']
                    );
                    $stmtIns->execute();
                }
                $stmtIns->close();

                // Tandai semua request sebagai disetujui di tabel request
                $stmtUpd = $db->prepare("
                    UPDATE booking_sparepart_request
                    SET status = 'disetujui'
                    WHERE booking_id = ? AND status = 'menunggu'
                ");
                $stmtUpd->bind_param('i', $id);
                $stmtUpd->execute();
                $stmtUpd->close();
            }
            // ─────────────────────────────────────────────────────────────────

            $db->close();
            responseOk('Booking diaktifkan, servis dimulai', [
                'servis_id'       => $servisId,
                'part_diimport'   => count($partRequests),
            ]);

        case 'no_show':
            $result = prosesNoShow($id, "kasir:$kasirId");
            $db->close();
            responseOk($result['pesan'], $result);

        case 'batal':
            if (!in_array($booking['status'], ['menunggu','dikonfirmasi']))
                responseError('Booking tidak dapat dibatalkan');
            $s = 'dibatalkan';
            $catatan = trim($body['catatan'] ?? '') ?: null;

            $stmt = $db->prepare("
                DELETE ss FROM servis_sparepart ss
                JOIN servis sv ON sv.id = ss.servis_id
                WHERE sv.booking_id = ?
            ");
            $stmt->bind_param('i', $id);
            $stmt->execute(); $stmt->close();

            $stmt = $db->prepare("UPDATE booking SET status=?, catatan_kasir=? WHERE id=?");
            $stmt->bind_param('ssi', $s, $catatan, $id);
            $stmt->execute(); $stmt->close();

            // ── Notifikasi FCM ────────────────────────────────
            $stmtD = $db->prepare("SELECT no_booking, tanggal_servis FROM booking WHERE id=? LIMIT 1");
            $stmtD->bind_param('i', $id);
            $stmtD->execute();
            $bDetail = $stmtD->get_result()->fetch_assoc();
            $stmtD->close();
            if ($bDetail) {
                $tglFmt = date('d M Y', strtotime($bDetail['tanggal_servis']));
                $pesanBatal = "Booking #{$bDetail['no_booking']} tanggal $tglFmt telah dibatalkan.";
                if ($catatan) $pesanBatal .= " Keterangan: $catatan";
                kirimNotifikasi(
                    $db,
                    (int)$booking['pelanggan_id'],
                    'booking_dibatalkan',
                    'Booking Dibatalkan ❌',
                    $pesanBatal,
                    $id
                );
            }
            // ─────────────────────────────────────────────────

            responseOk('Booking dibatalkan');

        case 'walkin':
            $stmt = $db->prepare("UPDATE booking SET tipe='walk_in' WHERE id=?");
            $stmt->bind_param('i', $id);
            $stmt->execute(); $stmt->close();
            responseOk('Booking dikonversi ke walk-in');

        // review_sparepart tidak lagi digunakan — sparepart request otomatis
        // diimport ke servis_sparepart saat booking diaktifkan (action: aktifkan).
        // Kasir cukup mengelola sparepart langsung dari halaman kelola servis.

        default:
            responseError('Action tidak valid');
    }
}

// ── POST: walk-in baru ────────────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $body        = getRequestBody();
    $pelangganId = (int)($body['pelanggan_id']  ?? 0);
    $kendaraanId = (int)($body['kendaraan_id']  ?? 0);
    $jenisId     = !empty($body['jenis_servis_id']) ? (int)$body['jenis_servis_id'] : null;
    $keluhan     = trim($body['keluhan'] ?? '') ?: null;

    // Sparepart langsung (opsional) — array of { sparepart_id, jumlah }
    $sparepartList = isset($body['sparepart']) && is_array($body['sparepart'])
        ? $body['sparepart']
        : [];

    // Mode buat pelanggan baru sekaligus
    $namaBaru = trim($body['nama_baru']  ?? '');
    $hpBaru   = trim($body['hp_baru']   ?? '');

    if (!$pelangganId && (!$namaBaru || !$hpBaru))
        responseError('Pilih pelanggan atau isi nama + no HP pelanggan baru');

    // Buat pelanggan baru jika belum ada
    if (!$pelangganId) {
        $stmt = $db->prepare("SELECT id FROM pelanggan WHERE no_hp=? LIMIT 1");
        $stmt->bind_param('s', $hpBaru);
        $stmt->execute();
        $exist = $stmt->get_result()->fetch_assoc();
        $stmt->close();

        if ($exist) {
            $pelangganId = (int)$exist['id'];
        } else {
            $passDefault = password_hash($hpBaru, PASSWORD_BCRYPT);
            $stmt = $db->prepare("INSERT INTO pelanggan (nama, no_hp, password) VALUES (?,?,?)");
            $stmt->bind_param('sss', $namaBaru, $hpBaru, $passDefault);
            if (!$stmt->execute()) responseError('Gagal membuat pelanggan baru', 500);
            $pelangganId = $stmt->insert_id;
            $stmt->close();
        }
    }

    // Mode buat kendaraan baru sekaligus
    if (!$kendaraanId) {
        $merk     = trim($body['merk']      ?? '');
        $model    = trim($body['model']     ?? '');
        $noPolisi = strtoupper(trim($body['no_polisi'] ?? ''));
        $warna    = trim($body['warna']     ?? '') ?: null;

        if (!$merk || !$model || !$noPolisi)
            responseError('Data kendaraan tidak lengkap');

        $stmt = $db->prepare("SELECT id FROM kendaraan WHERE no_polisi=? LIMIT 1");
        $stmt->bind_param('s', $noPolisi);
        $stmt->execute();
        $existK = $stmt->get_result()->fetch_assoc();
        $stmt->close();

        if ($existK) {
            $kendaraanId = (int)$existK['id'];
        } else {
            $stmt = $db->prepare("
                INSERT INTO kendaraan (pelanggan_id, merk, model, no_polisi, warna)
                VALUES (?,?,?,?,?)
            ");
            $stmt->bind_param('issss', $pelangganId, $merk, $model, $noPolisi, $warna);
            if (!$stmt->execute()) responseError('Gagal menyimpan kendaraan', 500);
            $kendaraanId = $stmt->insert_id;
            $stmt->close();
        }
    }

    // Generate no_booking walk-in (basis tanggal_servis = hari ini)
    $stmtCount = $db->prepare("SELECT COUNT(*) AS c FROM booking WHERE DATE(tanggal_servis) = CURDATE()");
    $stmtCount->execute();
    $seq       = $stmtCount->get_result()->fetch_assoc()['c'] + 1;
    $stmtCount->close();
    $noBooking = 'WI-' . date('Ymd') . '-' . str_pad($seq, 3, '0', STR_PAD_LEFT);

    // Jaga-jaga jika tetap ada tabrakan nomor
    $cek = $db->prepare("SELECT id FROM booking WHERE no_booking = ? LIMIT 1");
    while (true) {
        $cek->bind_param('s', $noBooking);
        $cek->execute();
        if ($cek->get_result()->num_rows === 0) break;
        $seq++;
        $noBooking = 'WI-' . date('Ymd') . '-' . str_pad($seq, 3, '0', STR_PAD_LEFT);
    }
    $cek->close();

    $stmt = $db->prepare("
        INSERT INTO booking
          (no_booking, pelanggan_id, kendaraan_id, jenis_servis_id,
           tanggal_booking, tanggal_servis, keluhan, status, tipe)
        VALUES (?, ?, ?, ?, CURDATE(), CURDATE(), ?, 'aktif', 'walk_in')
    ");
    $stmt->bind_param('siiis',
        $noBooking, $pelangganId, $kendaraanId, $jenisId, $keluhan);
    if (!$stmt->execute()) responseError('Gagal membuat walk-in', 500);
    $bookingId = $stmt->insert_id;
    $stmt->close();

    // Buat servis
    $stmt = $db->prepare("INSERT INTO servis (booking_id, kasir_id) VALUES (?,?)");
    $stmt->bind_param('ii', $bookingId, $kasirId);
    $stmt->execute();
    $servisId = $stmt->insert_id;
    $stmt->close();

    // ── Insert sparepart langsung ke servis_sparepart (jika ada) ──
    $sparepartInserted = 0;
    $sparepartErrors   = [];

    if (!empty($sparepartList)) {
        $stmtSp = $db->prepare("
            SELECT id, harga_jual, stok FROM sparepart
            WHERE id = ? AND is_aktif = 1 LIMIT 1
        ");
        $stmtIns = $db->prepare("
            INSERT INTO servis_sparepart
            (servis_id, sparepart_id, jumlah, harga_jual, subtotal, sumber, status_persetujuan)
            VALUES (?, ?, ?, ?, ?, 'manual', 'disetujui')
        ");

        foreach ($sparepartList as $sp) {
            $spId    = (int)($sp['sparepart_id'] ?? 0);
            $jumlah  = (int)($sp['jumlah']       ?? 0);

            if ($spId <= 0 || $jumlah <= 0) continue;

            // Ambil harga & cek stok
            $stmtSp->bind_param('i', $spId);
            $stmtSp->execute();
            $spRow = $stmtSp->get_result()->fetch_assoc();

            if (!$spRow) {
                $sparepartErrors[] = "Sparepart ID $spId tidak ditemukan";
                continue;
            }
            if ($spRow['stok'] < $jumlah) {
                $sparepartErrors[] = "Stok sparepart ID $spId tidak cukup (tersedia: {$spRow['stok']})";
                continue;
            }

            $hargaJual = (float)$spRow['harga_jual'];
            $subtotal  = $hargaJual * $jumlah;

            $stmtIns->bind_param('iidd', $servisId, $spId, $jumlah, $hargaJual, $subtotal);
            // bind_param tidak support campuran i & d sekaligus untuk int jumlah, perbaiki types:
            // servis_id(i), sparepart_id(i), jumlah(i), harga_jual(d), subtotal(d)
            $stmtIns->bind_param('iiidd', $servisId, $spId, $jumlah, $hargaJual, $subtotal);
            if ($stmtIns->execute()) {
                $sparepartInserted++;
                // Kurangi stok — trigger trg_kurangi_stok_servis akan jalan otomatis
                // jika trigger belum ada, kurangi manual:
                // $db->query("UPDATE sparepart SET stok = stok - $jumlah WHERE id = $spId");
            } else {
                $sparepartErrors[] = "Gagal insert sparepart ID $spId";
            }
        }

        $stmtSp->close();
        $stmtIns->close();
    }

    $db->close();

    $responseData = [
        'booking_id'          => $bookingId,
        'servis_id'           => $servisId,
        'no_booking'          => $noBooking,
        'pelanggan_id'        => $pelangganId,
        'kendaraan_id'        => $kendaraanId,
        'sparepart_inserted'  => $sparepartInserted,
    ];
    if (!empty($sparepartErrors)) {
        $responseData['sparepart_errors'] = $sparepartErrors;
    }

    responseOk('Walk-in berhasil dibuat', $responseData);
}

responseError('Method tidak diizinkan', 405);