<?php
// pelanggan/hari_libur.php — GET list tanggal libur (read-only)
// Dipakai Flutter untuk populate disabled dates di date picker
// GET ?tahun=YYYY&bulan=MM   → array tanggal libur + Ahad dalam rentang
// GET ?bulan_range=3         → 3 bulan ke depan dari hari ini (default)

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../middleware/auth.php';

setCORSHeaders();
if ($_SERVER['REQUEST_METHOD'] !== 'GET') responseError('Method tidak diizinkan', 405);

requireRole('pelanggan');

$db = getDB();

// Ambil rentang: default 3 bulan ke depan dari hari ini
$bulanRange = max(1, (int)($_GET['bulan_range'] ?? 3));
$mulai      = date('Y-m-d');
$akhir      = date('Y-m-d', strtotime("+$bulanRange months"));

if (!empty($_GET['tahun']) && !empty($_GET['bulan'])) {
    $tahun = (int)$_GET['tahun'];
    $bulan = (int)$_GET['bulan'];
    $mulai = sprintf('%04d-%02d-01', $tahun, $bulan);
    $akhir = date('Y-m-t', strtotime($mulai)); // akhir bulan
}

// Ambil hari libur nasional / manual dari DB
$stmt = $db->prepare("
    SELECT tanggal, keterangan
    FROM hari_libur
    WHERE tanggal BETWEEN ? AND ?
    ORDER BY tanggal ASC
");
$stmt->bind_param('ss', $mulai, $akhir);
$stmt->execute();
$result = $stmt->get_result();

$liburNasional = [];
while ($r = $result->fetch_assoc()) {
    $liburNasional[$r['tanggal']] = $r['keterangan'];
}
$stmt->close();
$db->close();

// Kumpulkan semua tanggal yang diblokir (libur + semua Ahad dalam rentang)
$blocked = [];

// Tambahkan libur dari DB
foreach ($liburNasional as $tgl => $ket) {
    $blocked[] = ['tanggal' => $tgl, 'alasan' => $ket, 'tipe' => 'libur_nasional'];
}

// Tambahkan semua hari Ahad dalam rentang
$cur = strtotime($mulai);
$end = strtotime($akhir);
while ($cur <= $end) {
    if (date('w', $cur) === '0') { // 0 = Minggu
        $tgl = date('Y-m-d', $cur);
        // Jangan duplikat jika Ahad kebetulan juga libur nasional
        if (!isset($liburNasional[$tgl])) {
            $blocked[] = ['tanggal' => $tgl, 'alasan' => 'Hari Ahad (bengkel tutup)', 'tipe' => 'ahad'];
        } else {
            // Update tipe menjadi keduanya
            foreach ($blocked as &$b) {
                if ($b['tanggal'] === $tgl) {
                    $b['tipe'] = 'libur_nasional+ahad';
                    break;
                }
            }
            unset($b);
        }
    }
    $cur = strtotime('+1 day', $cur);
}

// Sort by tanggal
usort($blocked, fn($a, $b) => strcmp($a['tanggal'], $b['tanggal']));

// Kirim juga sebagai flat array tanggal untuk kemudahan Flutter
$tanggalBlocked = array_column($blocked, 'tanggal');

responseOk('OK', [
    'mulai'            => $mulai,
    'akhir'            => $akhir,
    'blocked_dates'    => $blocked,
    'tanggal_blocked'  => $tanggalBlocked,
]);