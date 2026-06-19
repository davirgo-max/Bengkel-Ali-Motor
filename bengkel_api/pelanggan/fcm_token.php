<?php
// pelanggan/fcm_token.php
// POST → simpan / perbarui FCM token device pelanggan yang login
//
// Body JSON:
//   { "fcm_token": "eXY...", "device_info": "Samsung Galaxy A32, Android 12" }

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../config/response.php';
require_once __DIR__ . '/../config/fcm_helper.php';
require_once __DIR__ . '/../middleware/auth.php';

setCORSHeaders();

$auth        = requireRole('pelanggan');
$pelangganId = (int)$auth['user_id'];

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    responseError('Method tidak diizinkan', 405);
}

$body       = getRequestBody();
$fcmToken   = trim($body['fcm_token']   ?? '');
$deviceInfo = trim($body['device_info'] ?? '') ?: null;

if (empty($fcmToken)) {
    responseError('fcm_token wajib diisi');
}

$db = getDB();
simpanFcmToken($db, $pelangganId, $fcmToken, $deviceInfo);
$db->close();

responseOk('FCM token berhasil disimpan');