// lib/core/constants/app_constants.dart

class AppConstants {
  AppConstants._();

  // ── Ganti IP sesuai server ────────────────────────────────
  static const String baseUrl = 'http://192.168.1.11/bengkel_api';
  static const String uploadUrl = 'http://192.168.1.11/bengkel_api/uploads';

  // ── Auth ──────────────────────────────────────────────────
  static const String loginUrl = '$baseUrl/auth/login.php';
  static const String meUrl = '$baseUrl/auth/me.php';

  // ── Admin ─────────────────────────────────────────────────
  static const String adminDashboardUrl = '$baseUrl/admin/dashboard.php';
  static const String adminPengaturanBengkelUrl =
      '$baseUrl/admin/pengaturan_bengkel.php';
  static const String adminSparepartUrl = '$baseUrl/admin/sparepart.php';
  static const String adminSparepartUploadUrl =
      '$baseUrl/admin/sparepart_upload.php';
  static const String adminMekanikUrl = '$baseUrl/admin/mekanik.php';
  static const String adminJenisServisUrl = '$baseUrl/admin/jenis_servis.php';
  static const String adminAkunOwnerUrl = '$baseUrl/admin/akun_owner.php';
  static const String adminAkunKasirUrl = '$baseUrl/admin/akun_kasir.php';
  static const String adminPelangganUrl = '$baseUrl/admin/pelanggan.php';
  static const String adminBlokirUrl = '$baseUrl/admin/kelola_blokir.php';
  static const String adminHariLiburUrl = '$baseUrl/admin/hari_libur.php';
  static const String adminStokMenipisUrl = '$baseUrl/admin/stok_menipis.php';

  // Legacy
  static const String ownerLaporanUrl = '$baseUrl/owner/laporan.php';

  // ── Storage Keys ──────────────────────────────────────────
  static const String keyToken = 'web_token';
  static const String keyRole = 'web_role';
  static const String keyUser = 'web_user';

  // ── App ───────────────────────────────────────────────────
  static const String appName = 'Bengkel Ali Motor';
}
