<?php
// pelanggan/booking.php — dengan sistem anti-booking fiktif + sparepart request opsional

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../middleware/auth.php';
require_once __DIR__ . '/../config/penalti_helper.php';

setCORSHeaders();

$auth        = requireRole('pelanggan');
$pelangganId = $auth['user_id'];
$db          = getDB();

// ── GET ───────────────────────────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    if (isset($_GET['id'])) {
        $id   = (int)$_GET['id'];
        $stmt = $db->prepare("
            SELECT b.id, b.no_booking, b.tanggal_booking, b.tanggal_servis,
                   b.keluhan, b.status, b.tipe, b.catatan_kasir,
                   sw.label AS slot_label, sw.jam_mulai, sw.jam_selesai,
                   k.merk, k.model, k.no_polisi,
                   js.nama AS jenis_servis, js.harga_jasa,
                   s.status AS status_servis, s.diagnosa,
                   s.waktu_mulai, s.waktu_selesai,
                   m.nama AS mekanik
            FROM booking b
            JOIN kendaraan k  ON k.id  = b.kendaraan_id
            LEFT JOIN slot_waktu sw   ON sw.id = b.slot_id
            LEFT JOIN jenis_servis js ON js.id = b.jenis_servis_id
            LEFT JOIN servis s        ON s.booking_id = b.id
            LEFT JOIN mekanik m       ON m.id = s.mekanik_id
            WHERE b.id = ? AND b.pelanggan_id = ?
            LIMIT 1
        ");
        $stmt->bind_param('ii', $id, $pelangganId);
        $stmt->execute();
        $row = $stmt->get_result()->fetch_assoc();
        $stmt->close();
        if (!$row) responseError('Booking tidak ditemukan', 404);

        // ── Sertakan sparepart request pelanggan (jika ada) ──
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
        // ─────────────────────────────────────────────────────

        responseOk('OK', $row);
    }

    $where  = ['b.pelanggan_id = ?'];
    $params = [$pelangganId];
    $types  = 'i';
    if (!empty($_GET['status'])) {
        $where[]  = 'b.status = ?';
        $params[] = $_GET['status'];
        $types   .= 's';
    }
    $stmt = $db->prepare("
        SELECT b.id, b.no_booking, b.tanggal_servis, b.status, b.tipe,
               sw.label AS slot_label, sw.jam_mulai,
               k.merk, k.model, k.no_polisi,
               js.nama AS jenis_servis,
               s.status AS status_servis
        FROM booking b
        JOIN kendaraan k  ON k.id  = b.kendaraan_id
        LEFT JOIN slot_waktu sw   ON sw.id = b.slot_id
        LEFT JOIN jenis_servis js ON js.id = b.jenis_servis_id
        LEFT JOIN servis s        ON s.booking_id = b.id
        WHERE " . implode(' AND ', $where) . "
        ORDER BY b.tanggal_servis DESC, b.created_at DESC
    ");
    $stmt->bind_param($types, ...$params);
    $stmt->execute();
    $result = $stmt->get_result();
    $rows = [];
    while ($r = $result->fetch_assoc()) $rows[] = $r;
    $result->free();
    $stmt->close();
    responseOk('OK', $rows);
}

// ── POST: buat booking baru ───────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $body        = getRequestBody();
    $kendaraanId = (int)($body['kendaraan_id']     ?? 0);
    $jenisId     = !empty($body['jenis_servis_id']) ? (int)$body['jenis_servis_id'] : null;
    $slotId      = !empty($body['slot_id'])         ? (int)$body['slot_id']         : null;
    $tglServis   = trim($body['tanggal_servis']     ?? '');
    $keluhan     = trim($body['keluhan']            ?? '') ?: null;

    // ── Sparepart request (opsional) ──────────────────────
    // Berupa array: [{ sparepart_id, jumlah, harga_jual, subtotal, catatan? }, ...]
    $sparepartRequest = [];
    if (!empty($body['sparepart_request']) && is_array($body['sparepart_request'])) {
        $sparepartRequest = $body['sparepart_request'];
    }

    if (!$kendaraanId || !$tglServis) responseError('Kendaraan dan tanggal servis wajib diisi');
    if (!$slotId)                      responseError('Pilih slot waktu terlebih dahulu');
    if ($tglServis < date('Y-m-d'))    responseError('Tanggal servis tidak boleh masa lalu');

    // ── CEK HARI AHAD ────────────────────────────────────────
    $hariServis = (int)date('w', strtotime($tglServis)); // 0=Minggu
    if ($hariServis === 0) {
        responseError('Bengkel tutup setiap hari Ahad. Pilih hari lain.', 422);
    }
    
    // ── CEK HARI LIBUR ───────────────────────────────────────
    $stmtLibur = $db->prepare("SELECT keterangan FROM hari_libur WHERE tanggal = ? LIMIT 1");
    $stmtLibur->bind_param('s', $tglServis);
    $stmtLibur->execute();
    $liburRow = $stmtLibur->get_result()->fetch_assoc();
    $stmtLibur->close();
    if ($liburRow) {
        responseError('Bengkel tutup: ' . $liburRow['keterangan'] . '. Pilih tanggal lain.', 422);
    }

    // ── CEK 1: Status blokir ──────────────────────────────
    $blokir = cekStatusBlokir($pelangganId, $db);
    if ($blokir['diblokir']) {
        $pesanBlokir = $blokir['sampai'] === 'PERMANEN'
            ? 'Akun kamu diblokir permanen karena terlalu sering no-show. Hubungi bengkel untuk membuka blokir.'
            : "Akun kamu diblokir hingga {$blokir['sampai']} karena no-show. Alasan: {$blokir['alasan']}";
        responseError($pesanBlokir, 403);
    }

    // ── CEK 2: Batas booking per akun ────────────────────
    $batas = cekBatasBooking($pelangganId, $db);
    if (!$batas['boleh']) {
        responseError($batas['alasan'], 429);
    }

    // ── CEK 2b: Kuota booking harian ──────────────────────
    $stmtKuota = $db->prepare("SELECT kuota_booking_harian FROM pengaturan_bengkel WHERE id=1 LIMIT 1");
    $stmtKuota->execute();
    $pengaturanRow = $stmtKuota->get_result()->fetch_assoc();
    $stmtKuota->close();
    $kuotaHarian = (int)($pengaturanRow['kuota_booking_harian'] ?? 0);

    if ($kuotaHarian > 0) {
        $stmtTerisi = $db->prepare("
            SELECT COUNT(*) AS total FROM booking
            WHERE tanggal_servis = ? AND status NOT IN ('dibatalkan','no_show')
        ");
        $stmtTerisi->bind_param('s', $tglServis);
        $stmtTerisi->execute();
        $terisi = (int)$stmtTerisi->get_result()->fetch_assoc()['total'];
        $stmtTerisi->close();

        if ($terisi >= $kuotaHarian) {
            responseError(
                "Kuota booking untuk tanggal $tglServis sudah penuh ($terisi/$kuotaHarian). Silakan pilih tanggal lain.",
                429
            );
        }
    }

    // ── CEK 3: Kendaraan milik pelanggan ─────────────────
    $stmt = $db->prepare("SELECT id FROM kendaraan WHERE id=? AND pelanggan_id=? LIMIT 1");
    $stmt->bind_param('ii', $kendaraanId, $pelangganId);
    $stmt->execute();
    if ($stmt->get_result()->num_rows === 0) responseError('Kendaraan tidak ditemukan');
    $stmt->close();

    // ── CEK 4: Slot tersedia (server-side re-validasi) ───
    $slotJumlah = 1;
    if ($jenisId) {
        $stmt = $db->prepare("SELECT estimasi_menit FROM jenis_servis WHERE id=? LIMIT 1");
        $stmt->bind_param('i', $jenisId);
        $stmt->execute();
        $js = $stmt->get_result()->fetch_assoc();
        $stmt->close();
        if ($js) $slotJumlah = (int)ceil((int)$js['estimasi_menit'] / 30);
    }

    $allSlots = [];
    $res      = $db->query("SELECT id FROM slot_waktu WHERE is_aktif=1 ORDER BY jam_mulai");
    while ($r = $res->fetch_assoc()) $allSlots[] = (int)$r['id'];

    $startIdx = array_search($slotId, $allSlots);
    if ($startIdx === false) responseError('Slot tidak valid');

    $slotsYangDiblokir = array_slice($allSlots, $startIdx, $slotJumlah);

    $stmt = $db->prepare("
        SELECT b.slot_id, b.slot_jumlah
        FROM booking b
        WHERE b.tanggal_servis = ?
        AND b.slot_id IS NOT NULL
        AND b.status NOT IN ('dibatalkan','no_show')
    ");
    $stmt->bind_param('s', $tglServis);
    $stmt->execute();
    $existing = $stmt->get_result();
    $blocked  = [];
    while ($row = $existing->fetch_assoc()) {
        $idx = array_search((int)$row['slot_id'], $allSlots);
        if ($idx !== false) {
            for ($x = 0; $x < (int)$row['slot_jumlah']; $x++) {
                if (isset($allSlots[$idx + $x])) {
                    $blocked[$allSlots[$idx + $x]] = true;
                }
            }
        }
    }
    $stmt->close();

    foreach ($slotsYangDiblokir as $sid) {
        if (isset($blocked[$sid])) responseError('Slot sudah tidak tersedia, pilih slot lain');
    }

    // ── CEK 5: Validasi sparepart request (jika ada) ─────
    // Pastikan setiap sparepart_id valid, aktif, dan stok mencukupi
    $validatedParts = [];
    if (!empty($sparepartRequest)) {
        foreach ($sparepartRequest as $item) {
            $spId   = (int)($item['sparepart_id'] ?? 0);
            $jumlah = max(1, (int)($item['jumlah'] ?? 1));
            if (!$spId) continue; // skip baris tidak valid

            $stmt = $db->prepare("
                SELECT id, nama, satuan, harga_jual, stok
                FROM sparepart
                WHERE id = ? AND is_aktif = 1
                LIMIT 1
            ");
            $stmt->bind_param('i', $spId);
            $stmt->execute();
            $sp = $stmt->get_result()->fetch_assoc();
            $stmt->close();

            if (!$sp) responseError("Sparepart ID $spId tidak ditemukan atau tidak aktif");
            if ($sp['stok'] < $jumlah) {
                responseError("Stok {$sp['nama']} tidak mencukupi (tersedia: {$sp['stok']})");
            }

            $hargaSnapshot = (float)$sp['harga_jual'];
            $validatedParts[] = [
                'sparepart_id' => $spId,
                'jumlah'       => $jumlah,
                'harga_jual'   => $hargaSnapshot,
                'subtotal'     => $hargaSnapshot * $jumlah,
                'catatan'      => trim($item['catatan'] ?? '') ?: null,
            ];
        }
    }

    // ── BUAT BOOKING (dalam transaksi) ────────────────────
    $jumlahPartRequest = 0;
    $db->begin_transaction();
    try {
        $tglFmt = date('Ymd', strtotime($tglServis));
        // Hitung sequence berdasarkan tanggal_servis (sama dengan basis prefix),
        // bukan created_at — supaya booking untuk tanggal servis yang sama tapi
        // dibuat di hari berbeda tidak saling tabrakan nomor.
        $stmtCount = $db->prepare("SELECT COUNT(*) AS c FROM booking WHERE DATE(tanggal_servis) = ?");
        $stmtCount->bind_param('s', $tglServis);
        $stmtCount->execute();
        $seq = $stmtCount->get_result()->fetch_assoc()['c'] + 1;
        $stmtCount->close();
        $noBooking = 'BK-' . $tglFmt . '-' . str_pad($seq, 3, '0', STR_PAD_LEFT);

        // Jaga-jaga jika tetap ada tabrakan (race condition / data lama),
        // naikkan sequence sampai didapat nomor yang benar-benar unik.
        $cek = $db->prepare("SELECT id FROM booking WHERE no_booking = ? LIMIT 1");
        while (true) {
            $cek->bind_param('s', $noBooking);
            $cek->execute();
            if ($cek->get_result()->num_rows === 0) break;
            $seq++;
            $noBooking = 'BK-' . $tglFmt . '-' . str_pad($seq, 3, '0', STR_PAD_LEFT);
        }
        $cek->close();
        $status     = ($tglServis === date('Y-m-d')) ? 'dikonfirmasi' : 'menunggu';

        $stmt = $db->prepare("
            INSERT INTO booking
              (no_booking, pelanggan_id, kendaraan_id, jenis_servis_id,
               tanggal_booking, tanggal_servis, slot_id, slot_jumlah,
               keluhan, status, tipe)
            VALUES (?, ?, ?, ?, CURDATE(), ?, ?, ?, ?, ?, 'booking')
        ");
        $stmt->bind_param('siiisisss',
            $noBooking, $pelangganId, $kendaraanId, $jenisId,
            $tglServis, $slotId, $slotJumlah, $keluhan, $status);
        if (!$stmt->execute()) throw new Exception('Gagal membuat booking');
        $newId = $stmt->insert_id;
        $stmt->close();

        // Update last_booking_date
        $stmt = $db->prepare("UPDATE pelanggan SET last_booking_date=CURDATE() WHERE id=?");
        $stmt->bind_param('i', $pelangganId);
        $stmt->execute();
        $stmt->close();

        // ── Insert sparepart request (jika ada) ───────────
        if (!empty($validatedParts)) {
            $stmtPart = $db->prepare("
                INSERT INTO booking_sparepart_request
                  (booking_id, sparepart_id, jumlah, harga_jual, subtotal, catatan, status)
                VALUES (?, ?, ?, ?, ?, ?, 'menunggu')
            ");
            foreach ($validatedParts as $part) {
                $stmtPart->bind_param(
                    'iiidds',
                    $newId,
                    $part['sparepart_id'],
                    $part['jumlah'],
                    $part['harga_jual'],
                    $part['subtotal'],
                    $part['catatan']
                );
                if (!$stmtPart->execute()) {
                    throw new Exception('Gagal menyimpan request sparepart');
                }
                $jumlahPartRequest++;
            }
            $stmtPart->close();
        }

        $db->commit();
    } catch (Exception $e) {
        $db->rollback();
        responseError($e->getMessage(), 500);
    }

    $db->close();
    responseOk('Booking berhasil dibuat', [
        'id'                    => $newId,
        'no_booking'            => $noBooking,
        'status'                => $status,
        'slot_id'               => $slotId,
        'jumlah_part_request'   => $jumlahPartRequest,
    ]);
}

// ── PUT: reschedule ───────────────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'PUT') {
    $id      = (int)($_GET['id'] ?? 0);
    $body    = getRequestBody();
    $tglBaru = trim($body['tanggal_servis'] ?? '');
    $slotId  = !empty($body['slot_id']) ? (int)$body['slot_id'] : null;

    if (!$id || !$tglBaru || !$slotId) responseError('ID, tanggal baru, dan slot wajib diisi');
    if ($tglBaru < date('Y-m-d'))       responseError('Tanggal tidak boleh masa lalu');

    $blokir = cekStatusBlokir($pelangganId, $db);
    if ($blokir['diblokir']) responseError('Akun diblokir, tidak dapat reschedule', 403);

    $stmt = $db->prepare("SELECT id, status FROM booking WHERE id=? AND pelanggan_id=? LIMIT 1");
    $stmt->bind_param('ii', $id, $pelangganId);
    $stmt->execute();
    $booking = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$booking) responseError('Booking tidak ditemukan', 404);
    if (!in_array($booking['status'], ['menunggu','dikonfirmasi']))
        responseError('Booking dengan status "' . $booking['status'] . '" tidak dapat dijadwalkan ulang');

    // ── Kuota booking harian di tanggal tujuan ────────────
    $stmtKuota = $db->prepare("SELECT kuota_booking_harian FROM pengaturan_bengkel WHERE id=1 LIMIT 1");
    $stmtKuota->execute();
    $pengaturanRow = $stmtKuota->get_result()->fetch_assoc();
    $stmtKuota->close();
    $kuotaHarian = (int)($pengaturanRow['kuota_booking_harian'] ?? 0);

    if ($kuotaHarian > 0) {
        // Booking ini sendiri (di tanggal lama) tidak ikut dihitung karena
        // akan berpindah keluar dari tanggal lama.
        $stmtTerisi = $db->prepare("
            SELECT COUNT(*) AS total FROM booking
            WHERE tanggal_servis = ? AND status NOT IN ('dibatalkan','no_show') AND id != ?
        ");
        $stmtTerisi->bind_param('si', $tglBaru, $id);
        $stmtTerisi->execute();
        $terisi = (int)$stmtTerisi->get_result()->fetch_assoc()['total'];
        $stmtTerisi->close();

        if ($terisi >= $kuotaHarian) {
            responseError(
                "Kuota booking untuk tanggal $tglBaru sudah penuh ($terisi/$kuotaHarian). Silakan pilih tanggal lain.",
                429
            );
        }
    }

    $stmt = $db->prepare("UPDATE booking SET tanggal_servis=?, slot_id=? WHERE id=?");
    $stmt->bind_param('sii', $tglBaru, $slotId, $id);
    $stmt->execute(); $stmt->close(); $db->close();
    responseOk('Jadwal berhasil diubah');
}

// ── DELETE: batalkan ──────────────────────────────────────
if ($_SERVER['REQUEST_METHOD'] === 'DELETE') {
    $id = (int)($_GET['id'] ?? 0);
    if (!$id) responseError('ID booking wajib diisi');

    $stmt = $db->prepare("SELECT id, status FROM booking WHERE id=? AND pelanggan_id=? LIMIT 1");
    $stmt->bind_param('ii', $id, $pelangganId);
    $stmt->execute();
    $booking = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$booking) responseError('Booking tidak ditemukan', 404);
    if (!in_array($booking['status'], ['menunggu','dikonfirmasi']))
        responseError('Booking tidak dapat dibatalkan pada status "' . $booking['status'] . '"');

    $status = 'dibatalkan';
    $stmt = $db->prepare("UPDATE booking SET status=? WHERE id=?");
    $stmt->bind_param('si', $status, $id);
    $stmt->execute(); $stmt->close(); $db->close();
    responseOk('Booking berhasil dibatalkan');
}

responseError('Method tidak diizinkan', 405);