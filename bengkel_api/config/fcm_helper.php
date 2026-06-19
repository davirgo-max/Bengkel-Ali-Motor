<?php
// config/fcm_helper.php
// ─────────────────────────────────────────────────────────────────
// Helper FCM V1 API (OAuth2 Service Account) + notifikasi in-app.
//
// SETUP:
//   1. Download Service Account JSON dari Firebase Console:
//      Project Settings → Service Accounts → Generate new private key
//   2. Simpan file JSON di: bengkel_api/config/service_account.json
//      (JANGAN taruh di folder public/web!)
//   3. Isi FCM_PROJECT_ID di bawah dengan project ID Firebase kamu
//
// Fungsi yang tersedia:
//   kirimNotifikasi($db, $pelangganId, $tipe, $judul, $pesan, $bookingId, $servisId)
//   simpanFcmToken($db, $pelangganId, $fcmToken, $deviceInfo)
// ─────────────────────────────────────────────────────────────────

// ── Isi dengan Firebase Project ID kamu ──────────────────────────
// Ambil dari: Firebase Console → Project Settings → General → Project ID
define('FCM_PROJECT_ID', 'bengkel-ali-motor');

// Path ke file Service Account JSON
define('FCM_SERVICE_ACCOUNT_PATH', __DIR__ . '/service_account.json');

// Endpoint FCM V1
define('FCM_V1_URL', 'https://fcm.googleapis.com/v1/projects/' . FCM_PROJECT_ID . '/messages:send');

// Cache file untuk access token (hindari minta token baru setiap request)
define('FCM_TOKEN_CACHE_PATH', __DIR__ . '/fcm_token_cache.json');


// ════════════════════════════════════════════════════════════════
// FUNGSI PUBLIK
// ════════════════════════════════════════════════════════════════

/**
 * Kirim notifikasi ke semua device aktif milik pelanggan.
 * Sekaligus INSERT baris ke tabel `notifikasi` (log in-app).
 *
 * FCM V1 tidak support multicast langsung — kirim satu per satu per token.
 * Dalam praktik bengkel kecil, 1 pelanggan biasanya hanya punya 1–2 device.
 *
 * @param mysqli   $db          Koneksi DB yang sudah terbuka
 * @param int      $pelangganId ID pelanggan tujuan
 * @param string   $tipe        Salah satu nilai enum notifikasi
 * @param string   $judul       Judul notifikasi
 * @param string   $pesan       Isi pesan
 * @param int|null $bookingId   FK opsional ke tabel booking
 * @param int|null $servisId    FK opsional ke tabel servis
 * @return bool    true jika berhasil kirim ke minimal 1 token
 */
function kirimNotifikasi(
    mysqli $db,
    int    $pelangganId,
    string $tipe,
    string $judul,
    string $pesan,
    ?int   $bookingId = null,
    ?int   $servisId  = null
): bool {

    // 1. INSERT dulu ke tabel notifikasi (in-app log)
    $stmt = $db->prepare("
        INSERT INTO notifikasi
            (pelanggan_id, booking_id, servis_id, tipe, judul, pesan, fcm_status)
        VALUES (?, ?, ?, ?, ?, ?, 'pending')
    ");
    $stmt->bind_param('iiisss', $pelangganId, $bookingId, $servisId, $tipe, $judul, $pesan);
    $stmt->execute();
    $notifId = (int)$db->insert_id;
    $stmt->close();

    // 2. Ambil semua FCM token aktif milik pelanggan
    $stmt = $db->prepare("
        SELECT id, fcm_token
        FROM   pelanggan_fcm_tokens
        WHERE  pelanggan_id = ?
          AND  is_aktif = 1
        ORDER  BY last_used_at DESC
    ");
    $stmt->bind_param('i', $pelangganId);
    $stmt->execute();
    $result = $stmt->get_result();
    $tokens = [];
    while ($row = $result->fetch_assoc()) {
        $tokens[] = $row;
    }
    $stmt->close();

    if (empty($tokens)) {
        _updateFcmStatus($db, $notifId, 'gagal', 'Tidak ada FCM token aktif');
        return false;
    }

    // 3. Dapatkan OAuth2 access token (di-cache agar tidak minta ulang setiap saat)
    $accessToken = _getAccessToken();
    if (!$accessToken) {
        _updateFcmStatus($db, $notifId, 'gagal', 'Gagal mendapatkan OAuth2 access token');
        return false;
    }

    // 4. Kirim ke setiap token satu per satu (FCM V1 tidak support multicast)
    $adaYangSukses = false;
    $lastRaw       = '';

    foreach ($tokens as $tokenRow) {
        $token = $tokenRow['fcm_token'];

        $payload = [
            'message' => [
                'token'        => $token,
                'notification' => [
                    'title' => $judul,
                    'body'  => $pesan,
                ],
                'android' => [
                    'priority'     => 'high',
                    'notification' => [
                        'sound'        => 'default',
                        'channel_id'   => 'bengkel_ali_channel',
                    ],
                ],
                'apns' => [   // iOS (siapkan untuk masa depan)
                    'payload' => [
                        'aps' => ['sound' => 'default'],
                    ],
                ],
                'data' => [   // data ekstra untuk Flutter onMessage handler
                    'tipe'      => $tipe,
                    'notifId'   => (string)$notifId,
                    'bookingId' => $bookingId ? (string)$bookingId : '',
                    'servisId'  => $servisId  ? (string)$servisId  : '',
                ],
            ],
        ];

        $ch = curl_init(FCM_V1_URL);
        curl_setopt_array($ch, [
            CURLOPT_POST           => true,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_HTTPHEADER     => [
                'Content-Type: application/json',
                'Authorization: Bearer ' . $accessToken,
            ],
            CURLOPT_POSTFIELDS     => json_encode($payload),
            CURLOPT_TIMEOUT        => 10,
        ]);
        $raw      = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        $lastRaw  = $raw;
        $response = json_decode($raw, true);

        if ($httpCode === 200) {
            $adaYangSukses = true;
        } else {
            // Token tidak valid → nonaktifkan
            $errorCode = $response['error']['details'][0]['errorCode'] ?? '';
            if (in_array($errorCode, ['UNREGISTERED', 'INVALID_ARGUMENT'])) {
                _nonaktifkanToken($db, $pelangganId, $token);
            }
        }
    }

    // 5. Update fcm_status berdasarkan hasil keseluruhan
    _updateFcmStatus(
        $db,
        $notifId,
        $adaYangSukses ? 'terkirim' : 'gagal',
        $lastRaw ?: 'Tidak ada respons dari FCM'
    );

    return $adaYangSukses;
}


/**
 * Simpan atau perbarui FCM token milik pelanggan.
 * Dipanggil dari: pelanggan/fcm_token.php
 */
function simpanFcmToken(mysqli $db, int $pelangganId, string $fcmToken, ?string $deviceInfo = null): void
{
    if (empty(trim($fcmToken))) return;

    // Cek apakah token sudah terdaftar (milik siapa pun)
    $stmt = $db->prepare("SELECT id FROM pelanggan_fcm_tokens WHERE fcm_token = ? LIMIT 1");
    $stmt->bind_param('s', $fcmToken);
    $stmt->execute();
    $existing = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if ($existing) {
        // Token sudah ada → update pemilik + aktifkan
        $stmt = $db->prepare("
            UPDATE pelanggan_fcm_tokens
            SET    pelanggan_id = ?,
                   is_aktif     = 1,
                   device_info  = COALESCE(?, device_info),
                   last_used_at = NOW()
            WHERE  id = ?
        ");
        $stmt->bind_param('isi', $pelangganId, $deviceInfo, $existing['id']);
        $stmt->execute();
        $stmt->close();
    } else {
        // Token baru → insert
        $stmt = $db->prepare("
            INSERT INTO pelanggan_fcm_tokens (pelanggan_id, fcm_token, device_info, is_aktif, last_used_at)
            VALUES (?, ?, ?, 1, NOW())
        ");
        $stmt->bind_param('iss', $pelangganId, $fcmToken, $deviceInfo);
        $stmt->execute();
        $stmt->close();
    }
}


// ════════════════════════════════════════════════════════════════
// PRIVATE HELPERS
// ════════════════════════════════════════════════════════════════

/**
 * Dapatkan OAuth2 access token dari Service Account JSON.
 * Token di-cache ke file selama masa berlaku (biasanya 1 jam).
 * Return string token, atau null jika gagal.
 */
function _getAccessToken(): ?string
{
    // Cek cache dulu
    if (file_exists(FCM_TOKEN_CACHE_PATH)) {
        $cache = json_decode(file_get_contents(FCM_TOKEN_CACHE_PATH), true);
        // Beri buffer 5 menit sebelum expired
        if (isset($cache['token'], $cache['expires_at']) && time() < ($cache['expires_at'] - 300)) {
            return $cache['token'];
        }
    }

    // Baca Service Account JSON
    if (!file_exists(FCM_SERVICE_ACCOUNT_PATH)) {
        error_log('[FCM] Service account file tidak ditemukan: ' . FCM_SERVICE_ACCOUNT_PATH);
        return null;
    }

    $sa = json_decode(file_get_contents(FCM_SERVICE_ACCOUNT_PATH), true);
    if (!$sa || empty($sa['private_key']) || empty($sa['client_email'])) {
        error_log('[FCM] Service account JSON tidak valid');
        return null;
    }

    // Buat JWT untuk request token
    $now = time();
    $jwtHeader  = _base64url(json_encode(['alg' => 'RS256', 'typ' => 'JWT']));
    $jwtPayload = _base64url(json_encode([
        'iss'   => $sa['client_email'],
        'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
        'aud'   => 'https://oauth2.googleapis.com/token',
        'iat'   => $now,
        'exp'   => $now + 3600,
    ]));

    $jwtUnsigned = "$jwtHeader.$jwtPayload";
    $privateKey  = openssl_pkey_get_private($sa['private_key']);
    if (!$privateKey) {
        error_log('[FCM] Gagal load private key dari service account');
        return null;
    }

    openssl_sign($jwtUnsigned, $signature, $privateKey, 'SHA256');
    $jwt = "$jwtUnsigned." . _base64url($signature);

    // Tukar JWT dengan access token
    $ch = curl_init('https://oauth2.googleapis.com/token');
    curl_setopt_array($ch, [
        CURLOPT_POST           => true,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POSTFIELDS     => http_build_query([
            'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            'assertion'  => $jwt,
        ]),
        CURLOPT_TIMEOUT        => 10,
    ]);
    $raw  = curl_exec($ch);
    $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    if ($code !== 200) {
        error_log('[FCM] Gagal dapat access token: ' . $raw);
        return null;
    }

    $resp = json_decode($raw, true);
    $token = $resp['access_token'] ?? null;
    if (!$token) return null;

    // Simpan ke cache
    file_put_contents(FCM_TOKEN_CACHE_PATH, json_encode([
        'token'      => $token,
        'expires_at' => $now + (int)($resp['expires_in'] ?? 3600),
    ]));

    return $token;
}

/** Base64 URL-safe encode (tanpa padding) untuk JWT */
function _base64url(string $data): string
{
    return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
}

function _updateFcmStatus(mysqli $db, int $notifId, string $status, string $response): void
{
    $stmt = $db->prepare("UPDATE notifikasi SET fcm_status = ?, fcm_response = ? WHERE id = ?");
    $stmt->bind_param('ssi', $status, $response, $notifId);
    $stmt->execute();
    $stmt->close();
}

function _nonaktifkanToken(mysqli $db, int $pelangganId, string $token): void
{
    if (empty($token)) return;
    $stmt = $db->prepare("
        UPDATE pelanggan_fcm_tokens
        SET    is_aktif = 0
        WHERE  pelanggan_id = ? AND fcm_token = ?
    ");
    $stmt->bind_param('is', $pelangganId, $token);
    $stmt->execute();
    $stmt->close();
}