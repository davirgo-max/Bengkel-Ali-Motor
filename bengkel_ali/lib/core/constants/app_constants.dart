// lib/core/constants/app_constants.dart

class AppConstants {
  AppConstants._();

  // ── Base URL ──────────────────────────────────────────────
  // Ganti IP ini dengan IP laptop kamu yang muncul di ipconfig
  // Emulator Android TIDAK bisa pakai 'localhost' untuk akses XAMPP
  static const String baseUrl = 'http://192.168.1.11/bengkel_api';
  static const String uploadUrl = 'http://192.168.1.11/bengkel_api/uploads';

  // ── Auth ──────────────────────────────────────────────────
  static const String loginUrl = '$baseUrl/auth/login.php';
  static const String registerUrl = '$baseUrl/auth/register.php';
  static const String meUrl = '$baseUrl/auth/me.php';
  static const String forgotPasswordUrl = '$baseUrl/auth/forgot_password.php';
  static const String resetPasswordUrl = '$baseUrl/auth/reset_password.php';

  // ── Pelanggan ─────────────────────────────────────────────
  static const String sparepartUrl = '$baseUrl/pelanggan/sparepart.php';
  static const String jenisServisUrl = '$baseUrl/pelanggan/jenis_servis.php';
  static const String slotWaktuUrl = '$baseUrl/pelanggan/slot_waktu.php';
  static const String cekKuotaUrl = '$baseUrl/pelanggan/cek_kuota.php';
  static const String bookingUrl = '$baseUrl/pelanggan/booking.php';
  static const String statusServisUrl = '$baseUrl/pelanggan/status_servis.php';
  static const String notifikasiUrl = '$baseUrl/pelanggan/notifikasi.php';
  static const String profilUrl = '$baseUrl/pelanggan/profil.php';
  static const String hariLiburPelanggan = '$baseUrl/pelanggan/hari_libur.php';

  // ── Kendaraan ─────────────────────────────────────────────
  static const String kendaraanUrl = '$baseUrl/kendaraan/index.php';

  // ── Kasir ─────────────────────────────────────────────────
  static const String kasirDashboardUrl = '$baseUrl/kasir/dashboard.php';
  static const String kasirBookingUrl = '$baseUrl/kasir/booking.php';
  static const String kasirServisUrl = '$baseUrl/kasir/servis.php';
  static const String kasirTransaksiUrl = '$baseUrl/kasir/transaksi.php';
  static const String kasirKasHarianUrl = '$baseUrl/kasir/kas_harian.php';
  static const String kasirPelangganUrl = '$baseUrl/kasir/pelanggan.php';
  static const String kasirSparepartUrl = '$baseUrl/kasir/sparepart_cari.php';
  static const String kasirPembelianStokUrl =
      '$baseUrl/kasir/pembelian_stok.php';
  static const String kasirNoShowUrl = '$baseUrl/kasir/proses_noshow.php';
  static const String kasirPengaturanUrl = '$baseUrl/kasir/pengaturan.php';

  // ── Owner ─────────────────────────────────────────────────
  static const String ownerTransaksiUrl = '$baseUrl/kasir/transaksi.php';
  static const String ownerMutasiStokUrl = '$baseUrl/owner/mutasi_stok.php';
  static const String ownerVerifikasiKasUrl =
      '$baseUrl/owner/verifikasi_kas.php';
  static const String ownerLaporanUrl = '$baseUrl/owner/laporan.php';
  static const String ownerLaporanServisUrl =
      '$baseUrl/owner/laporan_servis.php';
  static const String adminStokMenipisUrl = '$baseUrl/admin/stok_menipis.php';

  // ── Storage Keys (SharedPreferences) ──────────────────────
  static const String keyToken = 'auth_token';
  static const String keyRole = 'auth_role';
  static const String keyUser = 'auth_user';

  // ── App Info ──────────────────────────────────────────────
  static const String appName = 'Bengkel Ali Motor';
  static const double bottomPadding = 24.0;
}
