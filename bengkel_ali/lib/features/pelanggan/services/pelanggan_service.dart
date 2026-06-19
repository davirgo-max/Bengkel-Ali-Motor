// lib/features/pelanggan/services/pelanggan_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../auth/services/auth_service.dart';
import '../../../core/constants/app_constants.dart';
import '../models/pelanggan_models.dart';

class PelangganService {
  PelangganService._();
  static final PelangganService instance = PelangganService._();

  Future<Map<String, String>> _headers() async {
    final token = await AuthService.instance.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> _get(String url) async {
    try {
      final res = await http
          .get(Uri.parse(url), headers: await _headers())
          .timeout(const Duration(seconds: 10));
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': 'Koneksi gagal: $e'};
    }
  }

  Future<Map<String, dynamic>> _post(
      String url, Map<String, dynamic> body) async {
    try {
      final res = await http
          .post(Uri.parse(url),
              headers: await _headers(), body: jsonEncode(body))
          .timeout(const Duration(seconds: 10));
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': 'Koneksi gagal: $e'};
    }
  }

  Future<Map<String, dynamic>> _put(
      String url, Map<String, dynamic> body) async {
    try {
      final res = await http
          .put(Uri.parse(url),
              headers: await _headers(), body: jsonEncode(body))
          .timeout(const Duration(seconds: 10));
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': 'Koneksi gagal: $e'};
    }
  }

  Future<Map<String, dynamic>> _delete(String url) async {
    try {
      final res = await http
          .delete(Uri.parse(url), headers: await _headers())
          .timeout(const Duration(seconds: 10));
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': 'Koneksi gagal: $e'};
    }
  }

  // ── SPAREPART ─────────────────────────────────────────
  Future<Map<String, dynamic>> getSparepart(
      {String? search, int? kategoriId}) async {
    var url = '${AppConstants.baseUrl}/pelanggan/sparepart.php';
    final p = <String>[];
    if (search != null && search.isNotEmpty) p.add('search=$search');
    if (kategoriId != null) p.add('kategori_id=$kategoriId');
    if (p.isNotEmpty) url += '?${p.join('&')}';
    return _get(url);
  }

  Future<Map<String, dynamic>> getSparepartDetail(int id) =>
      _get('${AppConstants.baseUrl}/pelanggan/sparepart.php?id=$id');

  // ── SPAREPART UNTUK BOOKING (hanya stok > 0 & aktif) ──
  // Endpoint yang sama dengan getSparepart, namun dipanggil
  // khusus di form booking. Backend bisa filter tersedia=1.
  Future<List<SparepartModel>> getSparepartTersedia(
      {String? search, int? kategoriId}) async {
    var url = '${AppConstants.baseUrl}/pelanggan/sparepart.php?tersedia=1';
    if (search != null && search.isNotEmpty) {
      url += '&search=${Uri.encodeComponent(search)}';
    }
    if (kategoriId != null) url += '&kategori_id=$kategoriId';
    final res = await _get(url);
    if (res['success'] != true) return [];
    // sparepart.php mengembalikan data: { sparepart: [...], kategori: [...] }
    final data = res['data'];
    final list = data is Map ? data['sparepart'] : data;
    if (list is! List) return [];
    return list.map((e) => SparepartModel.fromJson(e)).toList();
  }

  Future<List<KategoriModel>> getKategoriSparepart() async {
    // Coba endpoint dedicated dulu, fallback ke sparepart.php
    final res =
        await _get('${AppConstants.baseUrl}/pelanggan/kategori_sparepart.php');
    if (res['success'] == true && res['data'] is List) {
      return (res['data'] as List)
          .map((e) => KategoriModel.fromJson(e))
          .toList();
    }
    // Fallback: ambil dari field 'kategori' di sparepart.php
    final res2 = await _get(
        '${AppConstants.baseUrl}/pelanggan/sparepart.php?tersedia=1');
    if (res2['success'] != true) return [];
    final data = res2['data'];
    if (data is! Map) return [];
    final list = data['kategori'];
    if (list is! List) return [];
    return list.map((e) => KategoriModel.fromJson(e)).toList();
  }

  // ── KENDARAAN ─────────────────────────────────────────
  Future<List<KendaraanModel>> getKendaraan() async {
    final res = await _get('${AppConstants.baseUrl}/kendaraan/index.php');
    if (res['success'] != true) return [];
    return (res['data'] as List)
        .map((e) => KendaraanModel.fromJson(e))
        .toList();
  }

  Future<Map<String, dynamic>> tambahKendaraan(Map<String, dynamic> data) =>
      _post('${AppConstants.baseUrl}/kendaraan/index.php', data);

  Future<Map<String, dynamic>> hapusKendaraan(int id) =>
      _delete('${AppConstants.baseUrl}/kendaraan/index.php?id=$id');

  // ── JENIS SERVIS ──────────────────────────────────────
  Future<List<JenisServisModel>> getJenisServis() async {
    final res =
        await _get('${AppConstants.baseUrl}/pelanggan/jenis_servis.php');
    if (res['success'] != true) return [];
    return (res['data'] as List)
        .map((e) => JenisServisModel.fromJson(e))
        .toList();
  }

  // ── HARI LIBUR ────────────────────────────────────────
  Future<List<String>> getHariLibur() async {
    try {
      final res =
          await _get('${AppConstants.hariLiburPelanggan}?bulan_range=3');
      if (res['success'] != true) return [];
      final data = res['data'] as Map<String, dynamic>?;
      if (data == null) return [];
      return (data['tanggal_blocked'] as List)
          .map((e) => e.toString())
          .toList();
    } catch (e) {
      return [];
    }
  }

  // ── RESPON SPAREPART ──────────────────────────────────
  Future<Map<String, dynamic>> responSparepart({
    required int servisId,
    required String keputusan, // 'setuju' | 'tolak'
    int? sparepartDipilihId,
    String? catatanPelanggan,
  }) =>
      _put('${AppConstants.statusServisUrl}?id=$servisId', {
        'action': 'respon_sparepart',
        'keputusan': keputusan,
        if (sparepartDipilihId != null) 'sparepart_dipilih': sparepartDipilihId,
        if (catatanPelanggan != null && catatanPelanggan.isNotEmpty)
          'catatan_pelanggan': catatanPelanggan,
      });

  // ── SLOT WAKTU ────────────────────────────────────────
  Future<SlotResponse?> getSlotWaktu({
    required String tanggal,
    int? jenisServisId,
  }) async {
    var url =
        '${AppConstants.baseUrl}/pelanggan/slot_waktu.php?tanggal=$tanggal';
    if (jenisServisId != null) url += '&jenis_servis_id=$jenisServisId';
    final res = await _get(url);
    if (res['success'] != true) return null;
    return SlotResponse.fromJson(res['data'] as Map<String, dynamic>);
  }

  // ── BOOKING ───────────────────────────────────────────
  Future<List<BookingModel>> getBooking({String? status}) async {
    var url = '${AppConstants.baseUrl}/pelanggan/booking.php';
    if (status != null) url += '?status=$status';
    final res = await _get(url);
    if (res['success'] != true) return [];
    return (res['data'] as List).map((e) => BookingModel.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>> getBookingDetail(int id) =>
      _get('${AppConstants.baseUrl}/pelanggan/booking.php?id=$id');

  /// Buat booking. Jika [sparepartItems] tidak kosong, payload akan
  /// menyertakan array `sparepart_request` ke server.
  Future<Map<String, dynamic>> buatBooking(
    Map<String, dynamic> data, {
    List<BookingSparepartItem>? sparepartItems,
  }) {
    final payload = Map<String, dynamic>.from(data);
    if (sparepartItems != null && sparepartItems.isNotEmpty) {
      payload['sparepart_request'] =
          sparepartItems.map((e) => e.toJson()).toList();
    }
    return _post('${AppConstants.baseUrl}/pelanggan/booking.php', payload);
  }

  Future<Map<String, dynamic>> batalBooking(int id) =>
      _delete('${AppConstants.baseUrl}/pelanggan/booking.php?id=$id');

  Future<Map<String, dynamic>> rescheduleBooking(
          int id, String tanggalBaru, int slotId) =>
      _put('${AppConstants.baseUrl}/pelanggan/booking.php?id=$id',
          {'tanggal_servis': tanggalBaru, 'slot_id': slotId});

  // ── REQUEST SPAREPART BOOKING ─────────────────────────
  // Ambil daftar request sparepart milik booking tertentu
  // (untuk ditampilkan di detail booking / status servis).
  Future<List<BookingSparepartRequestModel>> getBookingSparepartRequest(
      int bookingId) async {
    final res = await _get(
        '${AppConstants.baseUrl}/pelanggan/booking_sparepart.php?booking_id=$bookingId');
    if (res['success'] != true) return [];
    return (res['data'] as List)
        .map((e) => BookingSparepartRequestModel.fromJson(e))
        .toList();
  }

  // ── STATUS SERVIS ─────────────────────────────────────
  Future<Map<String, dynamic>> getStatusServis({int? id}) {
    final url = id != null
        ? '${AppConstants.baseUrl}/pelanggan/status_servis.php?id=$id'
        : '${AppConstants.baseUrl}/pelanggan/status_servis.php';
    return _get(url);
  }

  // ── NOTIFIKASI ────────────────────────────────────────
  Future<Map<String, dynamic>> getNotifikasi() =>
      _get('${AppConstants.baseUrl}/pelanggan/notifikasi.php');

  Future<void> tandaiDibaca(int id) =>
      _put('${AppConstants.baseUrl}/pelanggan/notifikasi.php?id=$id', {});

  Future<void> tandaiSemuaDibaca() => _put(
      '${AppConstants.baseUrl}/pelanggan/notifikasi.php',
      {'action': 'read_all'});

  // ── PROFIL ────────────────────────────────────────────
  Future<Map<String, dynamic>> getProfil() =>
      _get('${AppConstants.baseUrl}/pelanggan/profil.php');

  Future<Map<String, dynamic>> updateProfil(Map<String, dynamic> data) =>
      _put('${AppConstants.baseUrl}/pelanggan/profil.php', data);

  Future<Map<String, dynamic>> gantiPassword({
    required String passLama,
    required String passBaru,
  }) =>
      _put('${AppConstants.baseUrl}/pelanggan/profil.php', {
        'action': 'ganti_password',
        'password_lama': passLama,
        'password_baru': passBaru,
      });
}
