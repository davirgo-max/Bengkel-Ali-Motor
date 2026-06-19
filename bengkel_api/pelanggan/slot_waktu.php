<?php
// pelanggan/slot_waktu.php — UPDATED: cek hari Ahad + hari libur sebelum tampil slot

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../middleware/auth.php';

setCORSHeaders();
if ($_SERVER['REQUEST_METHOD'] !== 'GET') responseError('Method tidak diizinkan', 405);

requireRole('pelanggan');

$tanggal = trim($_GET['tanggal']          ?? '');
$jenisId = !empty($_GET['jenis_servis_id']) ? (int)$_GET['jenis_servis_id'] : null;

if (!$tanggal) responseError('Parameter tanggal wajib diisi');
if ($tanggal < date('Y-m-d')) responseError('Tanggal tidak boleh masa lalu');

// ── CEK 1: Hari Ahad ─────────────────────────────────────
$hari = (int)date('w', strtotime($tanggal)); // 0 = Minggu
if ($hari === 0) {
    responseError('Bengkel tutup setiap hari Ahad. Silakan pilih hari lain.', 422);
}

$db = getDB();

// ── CEK 2: Hari Libur ────────────────────────────────────
$stmt = $db->prepare("SELECT keterangan FROM hari_libur WHERE tanggal = ? LIMIT 1");
$stmt->bind_param('s', $tanggal);
$stmt->execute();
$libur = $stmt->get_result()->fetch_assoc();
$stmt->close();

if ($libur) {
    $db->close();
    responseError('Bengkel tutup: ' . $libur['keterangan'] . '. Silakan pilih hari lain.', 422);
}

// ── Hitung slot dibutuhkan ────────────────────────────────
$slotDibutuhkan = 1;
if ($jenisId) {
    $stmt = $db->prepare("SELECT estimasi_menit FROM jenis_servis WHERE id = ? LIMIT 1");
    $stmt->bind_param('i', $jenisId);
    $stmt->execute();
    $js = $stmt->get_result()->fetch_assoc();
    $stmt->close();
    if ($js) {
        $slotDibutuhkan = (int)ceil((int)$js['estimasi_menit'] / 30);
    }
}

// ── Ambil semua slot aktif ────────────────────────────────
$allSlots = [];
$result   = $db->query("SELECT id, jam_mulai, jam_selesai, label FROM slot_waktu WHERE is_aktif=1 ORDER BY jam_mulai");
while ($r = $result->fetch_assoc()) $allSlots[] = $r;

// ── Ambil slot yang sudah terpakai di tanggal ini ────────
$stmt = $db->prepare("
    SELECT b.slot_id, b.slot_jumlah
    FROM booking b
    WHERE b.tanggal_servis = ?
    AND b.slot_id IS NOT NULL
    AND b.status NOT IN ('dibatalkan','no_show')
");
$stmt->bind_param('s', $tanggal);
$stmt->execute();
$existingResult = $stmt->get_result();

$blocked = [];
while ($row = $existingResult->fetch_assoc()) {
    foreach ($allSlots as $idx => $s) {
        if ((int)$s['id'] === (int)$row['slot_id']) {
            for ($x = 0; $x < (int)$row['slot_jumlah']; $x++) {
                if (isset($allSlots[$idx + $x])) {
                    $blocked[(int)$allSlots[$idx + $x]['id']] = true;
                }
            }
            break;
        }
    }
}
$stmt->close();

// ── Tandai tiap slot tersedia atau tidak ─────────────────
$now      = date('H:i:s');
$isToday  = ($tanggal === date('Y-m-d'));
$total    = count($allSlots);
$output   = [];

foreach ($allSlots as $idx => $slot) {
    $cukup      = ($idx + $slotDibutuhkan) <= $total;
    $nowPlus30  = date('H:i:s', strtotime('+30 minutes'));
    $sudahLewat = $isToday && $slot['jam_mulai'] <= $nowPlus30;

    $bebas = true;
    if ($cukup && !$sudahLewat) {
        for ($x = 0; $x < $slotDibutuhkan; $x++) {
            if (isset($allSlots[$idx + $x]) &&
                isset($blocked[(int)$allSlots[$idx + $x]['id']])) {
                $bebas = false;
                break;
            }
        }
    }

    $tersedia = $cukup && $bebas && !$sudahLewat;

    $alasan = null;
    if (!$tersedia) {
        if ($sudahLewat) {
            $alasan = 'Waktu sudah lewat';
        } elseif (!$cukup) {
            $alasan = 'Waktu tidak cukup untuk jenis servis ini';
        } else {
            $alasan = 'Slot sudah dipesan';
        }
    }

    $output[] = [
        'id'          => (int)$slot['id'],
        'jam_mulai'   => $slot['jam_mulai'],
        'jam_selesai' => $slot['jam_selesai'],
        'label'       => $slot['label'],
        'tersedia'    => $tersedia,
        'alasan'      => $alasan,
    ];
}

$db->close();

responseOk('OK', [
    'tanggal'          => $tanggal,
    'slot_dibutuhkan'  => $slotDibutuhkan,
    'estimasi_selesai' => ($slotDibutuhkan * 30) . ' menit',
    'slots'            => $output,
]);