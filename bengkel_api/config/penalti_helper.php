<?php
// config/penalti_helper.php
// Helper untuk proses penalti no-show — dipanggil dari kasir/booking

require_once __DIR__ . '/database.php';

/**
 * Tabel aturan blokir berdasarkan no-show dalam 14 hari:
 * 2x → 3 hari, 3x → 7 hari, 4x → 14 hari, 5x+ → permanen
 */
function hitungBlokirHari(int $noshowDalam14): ?int {
    return match(true) {
        $noshowDalam14 >= 5 => null,  // null = permanen
        $noshowDalam14 >= 4 => 14,
        $noshowDalam14 >= 3 => 7,
        $noshowDalam14 >= 2 => 3,
        default             => 0,     // belum kena blokir
    };
}

/**
 * Proses no-show: update status booking, hitung penalti, blokir jika perlu.
 * Return array ['diblokir' => bool, 'blokir_hari' => int|null, 'pesan' => string]
 */
function prosesNoShow(int $bookingId, string $dilakukanOleh = 'sistem'): array {
    $db = getDB();

    // Ambil data booking
    $stmt = $db->prepare("
        SELECT b.id, b.pelanggan_id, b.status, b.tanggal_servis, b.slot_id
        FROM booking b WHERE b.id = ? LIMIT 1
    ");
    $stmt->bind_param('i', $bookingId);
    $stmt->execute();
    $booking = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$booking) return ['diblokir' => false, 'pesan' => 'Booking tidak ditemukan'];
    if ($booking['status'] === 'no_show') {
        return ['diblokir' => false, 'pesan' => 'Sudah ditandai no-show sebelumnya'];
    }

    $pelangganId = (int)$booking['pelanggan_id'];

    // 1. Update status booking → no_show
    $stmt = $db->prepare("UPDATE booking SET status='no_show' WHERE id=?");
    $stmt->bind_param('i', $bookingId);
    $stmt->execute(); $stmt->close();

    // 2. Tambah total_noshow pelanggan
    $stmt = $db->prepare("UPDATE pelanggan SET total_noshow = total_noshow + 1 WHERE id=?");
    $stmt->bind_param('i', $pelangganId);
    $stmt->execute(); $stmt->close();

    // 3. Hitung no-show dalam 14 hari terakhir
    $stmt = $db->prepare("
        SELECT COUNT(*) AS total
        FROM booking b
        JOIN penalti_noshow pn ON pn.booking_id = b.id
        WHERE b.pelanggan_id = ?
        AND pn.created_at >= DATE_SUB(NOW(), INTERVAL 14 DAY)
    ");
    $stmt->bind_param('i', $pelangganId);
    $stmt->execute();
    $noshowDalam14 = (int)$stmt->get_result()->fetch_assoc()['total'] + 1; // +1 ini
    $stmt->close();

    // 4. Ambil total no-show keseluruhan
    $stmt = $db->prepare("SELECT total_noshow FROM pelanggan WHERE id=? LIMIT 1");
    $stmt->bind_param('i', $pelangganId);
    $stmt->execute();
    $totalNoshow = (int)$stmt->get_result()->fetch_assoc()['total_noshow'];
    $stmt->close();

    // 5. Hitung apakah perlu diblokir
    $blokirHari = hitungBlokirHari($noshowDalam14);
    $diblokir   = $blokirHari !== 0; // 0 = belum kena blokir
    $blokirSampai = null;
    $now          = date('Y-m-d H:i:s');

    if ($diblokir) {
        if ($blokirHari === null) {
            // Permanen
            $blokirSampai = null;
            $alasan       = "Diblokir permanen: $totalNoshow kali no-show ($noshowDalam14 kali dalam 14 hari terakhir)";
        } else {
            $blokirSampai = date('Y-m-d H:i:s', strtotime("+$blokirHari days"));
            $alasan       = "Diblokir $blokirHari hari: $noshowDalam14 kali no-show dalam 14 hari terakhir";
        }

        // Update blokir di tabel pelanggan
        $stmt = $db->prepare("
            UPDATE pelanggan
            SET is_diblokir=1, blokir_sampai=?, blokir_alasan=?
            WHERE id=?
        ");
        $stmt->bind_param('ssi', $blokirSampai, $alasan, $pelangganId);
        $stmt->execute(); $stmt->close();

        // Log blokir
        $stmt = $db->prepare("
            INSERT INTO log_blokir_pelanggan (pelanggan_id, aksi, alasan, dilakukan_oleh)
            VALUES (?, 'blokir', ?, ?)
        ");
        $stmt->bind_param('iss', $pelangganId, $alasan, $dilakukanOleh);
        $stmt->execute(); $stmt->close();
    }

    // 6. Simpan log penalti
    $stmt = $db->prepare("
        INSERT INTO penalti_noshow
          (pelanggan_id, booking_id, noshow_ke, noshow_dalam_14, blokir_hari, blokir_mulai, blokir_sampai, dibuat_oleh)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ");
    $stmt->bind_param('iiiiiiss',
        $pelangganId, $bookingId, $totalNoshow,
        $noshowDalam14, $blokirHari, $now, $blokirSampai, $dilakukanOleh
    );
    $stmt->execute(); $stmt->close();
    $db->close();

    $pesan = $diblokir
        ? ($blokirHari === null
            ? "Akun diblokir PERMANEN ($noshowDalam14 no-show dalam 14 hari)"
            : "Akun diblokir $blokirHari hari ($noshowDalam14 no-show dalam 14 hari)")
        : "No-show dicatat ($noshowDalam14 dalam 14 hari, belum kena blokir)";

    return [
        'diblokir'    => $diblokir,
        'blokir_hari' => $blokirHari,
        'blokir_sampai' => $blokirSampai,
        'noshow_dalam_14' => $noshowDalam14,
        'pesan'       => $pesan,
    ];
}

/**
 * Cek apakah pelanggan sedang diblokir.
 * Jika blokir sudah expired → otomatis buka blokir.
 * Return ['diblokir' => bool, 'alasan' => string, 'sampai' => string|null]
 */
function cekStatusBlokir(int $pelangganId, mysqli $db): array {
    $stmt = $db->prepare("
        SELECT is_diblokir, blokir_sampai, blokir_alasan
        FROM pelanggan WHERE id=? LIMIT 1
    ");
    $stmt->bind_param('i', $pelangganId);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$row || !$row['is_diblokir']) {
        return ['diblokir' => false];
    }

    // Cek apakah blokir sudah expired
    if ($row['blokir_sampai'] !== null) {
        if (strtotime($row['blokir_sampai']) <= time()) {
            // Expired → buka blokir otomatis
            $stmt = $db->prepare("
                UPDATE pelanggan
                SET is_diblokir=0, blokir_sampai=NULL, blokir_alasan=NULL
                WHERE id=?
            ");
            $stmt->bind_param('i', $pelangganId);
            $stmt->execute(); $stmt->close();

            $stmt = $db->prepare("
                INSERT INTO log_blokir_pelanggan (pelanggan_id, aksi, alasan, dilakukan_oleh)
                VALUES (?, 'buka_blokir', 'Masa blokir berakhir', 'sistem')
            ");
            $stmt->bind_param('i', $pelangganId);
            $stmt->execute(); $stmt->close();

            return ['diblokir' => false];
        }
    }

    $sampaiStr = $row['blokir_sampai']
        ? date('d/m/Y H:i', strtotime($row['blokir_sampai']))
        : 'PERMANEN';

    return [
        'diblokir' => true,
        'alasan'   => $row['blokir_alasan'],
        'sampai'   => $sampaiStr,
    ];
}

/**
 * Cek batas booking per akun:
 * - Maks 1 booking baru hari ini
 * - Maks 2 booking aktif sekaligus
 */
function cekBatasBooking(int $pelangganId, mysqli $db): array {
    // Cek booking hari ini
    $stmt = $db->prepare("
        SELECT COUNT(*) AS total FROM booking
        WHERE pelanggan_id = ?
        AND DATE(created_at) = CURDATE()
        AND status NOT IN ('dibatalkan')
    ");
    $stmt->bind_param('i', $pelangganId);
    $stmt->execute();
    $hariIni = (int)$stmt->get_result()->fetch_assoc()['total'];
    $stmt->close();

    if ($hariIni >= 1) {
        return [
            'boleh'  => false,
            'alasan' => 'Kamu sudah membuat 1 booking hari ini. Maksimal 1 booking baru per hari.',
        ];
    }

    // Cek booking aktif
    $stmt = $db->prepare("
        SELECT COUNT(*) AS total FROM booking
        WHERE pelanggan_id = ?
        AND status IN ('menunggu','dikonfirmasi','aktif')
    ");
    $stmt->bind_param('i', $pelangganId);
    $stmt->execute();
    $aktif = (int)$stmt->get_result()->fetch_assoc()['total'];
    $stmt->close();

    if ($aktif >= 2) {
        return [
            'boleh'  => false,
            'alasan' => "Kamu sudah memiliki $aktif booking aktif. Maksimal 2 booking aktif sekaligus.",
        ];
    }

    return ['boleh' => true];
}
