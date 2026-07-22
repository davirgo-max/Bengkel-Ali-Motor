import 'package:flutter/foundation.dart';
// lib/features/kasir/services/kasir_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../auth/services/auth_service.dart';
import '../../../core/constants/app_constants.dart';
import '../models/kasir_models.dart';

class KasirService {
  KasirService._();
  static final KasirService instance = KasirService._();

  // ── Helper ────────────────────────────────────────────
  Future<Map<String, String>> _headers() async {
    final token = await AuthService.instance.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> _get(String url) async {
    try {
      debugPrint('[DEBUG KASIR] URL: $url');
      final res = await http
          .get(Uri.parse(url), headers: await _headers())
          .timeout(const Duration(seconds: 10));
      debugPrint('[DEBUG KASIR] Status: ${res.statusCode}');
      debugPrint('[DEBUG KASIR] Body: ${res.body}');
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[DEBUG KASIR] ERROR: $e');
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

  // ── DASHBOARD ─────────────────────────────────────────
  Future<Map<String, dynamic>> getDashboard({String? tanggal}) {
    final tgl = tanggal ?? _today();
    return _get('${AppConstants.baseUrl}/kasir/dashboard.php?tanggal=$tgl');
  }

  // ── BOOKING ───────────────────────────────────────────
  Future<Map<String, dynamic>> getBookingList({
    String? tanggal,
    String? status,
  }) {
    final tgl = tanggal ?? _today();
    var url = '${AppConstants.baseUrl}/kasir/booking.php?tanggal=$tgl';
    if (status != null) url += '&status=$status';
    return _get(url);
  }

  Future<Map<String, int>> getBookingSummary(String dari, String sampai) async {
    final res = await _get(
        '${AppConstants.baseUrl}/kasir/booking.php?mode=summary&dari=$dari&sampai=$sampai');
    if (res['success'] != true) return {};
    final data = res['data'];
    if (data is! Map) return {};
    return data.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
  }

  Future<Map<String, dynamic>> getBookingDetail(int id) =>
      _get('${AppConstants.baseUrl}/kasir/booking.php?id=$id');

  Future<Map<String, dynamic>> updateStatusBooking(int id, String action,
          {String? catatan}) =>
      _put('${AppConstants.baseUrl}/kasir/booking.php?id=$id', {
        'action': action,
        'catatan': catatan,
      });

  Future<Map<String, dynamic>> buatWalkIn(Map<String, dynamic> data) =>
      _post('${AppConstants.baseUrl}/kasir/booking.php', data);

  /// Review request sparepart pelanggan per booking.
  /// [items] berisi list map: { 'id': int, 'status': 'disetujui'|'ditolak'|'diganti', 'catatan_kasir': String? }
  Future<Map<String, dynamic>> reviewSparepartRequest(
    int bookingId,
    List<Map<String, dynamic>> items,
  ) =>
      _put('${AppConstants.baseUrl}/kasir/booking.php?id=$bookingId', {
        'action': 'review_sparepart',
        'items': items,
      });

  // ── SERVIS ────────────────────────────────────────────
  Future<List<KasirServisModel>> getServisList({String? tanggal}) async {
    try {
      final tgl = tanggal ?? _today();
      final res =
          await _get('${AppConstants.baseUrl}/kasir/servis.php?tanggal=$tgl');
      if (res['success'] != true) return [];
      final rawData = res['data'];
      if (rawData is! List) return [];
      return rawData.map((e) => KasirServisModel.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getJenisServis() async {
    final res =
        await _get('${AppConstants.baseUrl}/pelanggan/jenis_servis.php');
    if (res['success'] != true) return [];
    return List<Map<String, dynamic>>.from(res['data'] as List);
  }

  Future<Map<String, dynamic>> getServisDetail(int id) =>
      _get('${AppConstants.baseUrl}/kasir/servis.php?id=$id');

  Future<Map<String, dynamic>> updateStatusServis(int id, String status) =>
      _put('${AppConstants.baseUrl}/kasir/servis.php?id=$id', {
        'action': 'update_status',
        'status': status,
      });

  Future<Map<String, dynamic>> updateInfoServis(int id,
          {String? diagnosa, String? catatanMekanik, int? mekanikId}) =>
      _put('${AppConstants.baseUrl}/kasir/servis.php?id=$id', {
        'action': 'update_info',
        'diagnosa': diagnosa,
        'catatan_mekanik': catatanMekanik,
        'mekanik_id': mekanikId,
      });

  Future<Map<String, dynamic>> updateJenisServis(int servisId,
          {required int jenisServisId}) =>
      _put('${AppConstants.baseUrl}/kasir/servis.php?id=$servisId', {
        'action': 'update_jenis_servis',
        'jenis_servis_id': jenisServisId,
      });

  Future<Map<String, dynamic>> selesaiDiagnosa({
    required int servisId,
    required String lanjutKe, // 'dikerjakan' | 'menunggu_part'
    // Kasir sudah konfirmasi sparepart rekomendasi/manual ke pelanggan di
    // luar aplikasi (telepon/langsung) -- kalau true, semua sparepart
    // rekomendasi/manual yang masih 'menunggu' di-auto-approve di server.
    bool konfirmasiLuarAplikasi = false,
  }) =>
      _put('${AppConstants.kasirServisUrl}?id=$servisId', {
        'action': 'selesai_diagnosa',
        'lanjut_ke': lanjutKe,
        'konfirmasi_luar_aplikasi': konfirmasiLuarAplikasi,
      });

  Future<Map<String, dynamic>> tambahSparepart({
    required int servisId,
    required int sparepartId,
    required int jumlah,
    // 'rekomendasi' = perlu persetujuan pelanggan dulu (status_persetujuan = menunggu)
    // 'manual'      = langsung disetujui tanpa konfirmasi pelanggan
    String sumber = 'rekomendasi',
  }) =>
      _post('${AppConstants.baseUrl}/kasir/servis.php', {
        'servis_id': servisId,
        'sparepart_id': sparepartId,
        'jumlah': jumlah,
        'sumber': sumber,
      });

  Future<Map<String, dynamic>> hapusSparepart(int partId) =>
      _delete('${AppConstants.baseUrl}/kasir/servis.php?part_id=$partId');

  // ── TRANSAKSI ─────────────────────────────────────────
  Future<Map<String, dynamic>> getRiwayatTransaksi({String? tanggal}) {
    final tgl = tanggal ?? _today();
    return _get('${AppConstants.baseUrl}/kasir/transaksi.php?tanggal=$tgl');
  }

  Future<Map<String, dynamic>> prosesBayar(Map<String, dynamic> data) =>
      _post('${AppConstants.baseUrl}/kasir/transaksi.php', data);

  Future<Map<String, dynamic>> buatTransaksiSparepart({
    required List<Map<String, dynamic>> items,
    required String metodeBayar,
    required double jumlahBayar,
  }) =>
      _post('${AppConstants.baseUrl}/kasir/jual_sparepart.php', {
        'items': items,
        'metode_bayar': metodeBayar,
        'jumlah_bayar': jumlahBayar,
      });

  Future<Map<String, dynamic>> getDetailNota(int transaksiId) =>
      _get('${AppConstants.baseUrl}/kasir/transaksi.php?id=$transaksiId');

  Future<Map<String, dynamic>> getTransaksiByServis(int servisId) =>
      _get('${AppConstants.baseUrl}/kasir/transaksi.php?servis_id=$servisId');

  // ── PELANGGAN (kasir) ─────────────────────────────────
  Future<Map<String, dynamic>> cariPelanggan(String keyword) =>
      _get('${AppConstants.baseUrl}/kasir/pelanggan.php?search=$keyword');

  Future<Map<String, dynamic>> getDetailPelanggan(int id) =>
      _get('${AppConstants.baseUrl}/kasir/pelanggan.php?id=$id');

  Future<Map<String, dynamic>> getRiwayatPelanggan(int id) => _get(
      '${AppConstants.baseUrl}/kasir/pelanggan.php?id=$id&include=riwayat');

  // ── SPAREPART SEARCH (untuk tambah di servis) ─────────
  Future<List<SparepartCariModel>> cariSparepart(String keyword) async {
    final res = await _get(
        '${AppConstants.baseUrl}/kasir/sparepart_cari.php?search=$keyword');
    if (res['success'] != true) return [];
    return (res['data'] as List)
        .map((e) => SparepartCariModel.fromJson(e))
        .toList();
  }

  Future<Map<String, dynamic>> blokirAksi(
    int pelangganId,
    String aksi, {
    int? hari,
    String? alasan,
  }) =>
      _put('${AppConstants.baseUrl}/kasir/pelanggan.php', {
        'pelanggan_id': pelangganId,
        'aksi': aksi,
        if (hari != null) 'hari': hari,
        if (alasan != null) 'alasan': alasan,
      });

  // ── NO-SHOW ───────────────────────────────────────────
  Future<Map<String, dynamic>> prosesNoShow(int bookingId) =>
      _post('${AppConstants.baseUrl}/kasir/proses_noshow.php', {
        'booking_id': bookingId,
      });

  Future<Map<String, dynamic>> autoScanNoShow() =>
      _post('${AppConstants.baseUrl}/kasir/proses_noshow.php', {
        'action': 'auto_scan',
      });

  // ── BELI STOK ─────────────────────────────────────────
  /// Catat pembelian stok baru.
  /// [items] berisi list map: { 'sparepart_id': int, 'jumlah': int, 'harga_beli': double }
  Future<Map<String, dynamic>> beliStok({
    required List<Map<String, dynamic>> items,
    String? supplier,
    String? keterangan,
    String? tanggal,
  }) =>
      _post(AppConstants.kasirPembelianStokUrl, {
        'items': items,
        if (supplier != null && supplier.isNotEmpty) 'supplier': supplier,
        if (keterangan != null && keterangan.isNotEmpty)
          'keterangan': keterangan,
        'tanggal': tanggal ?? _today(),
      });

  /// Ambil riwayat pembelian stok. Bisa filter by tanggal atau range.
  Future<List<PembelianStok>> getRiwayatPembelian({
    String? dari,
    String? sampai,
  }) async {
    final tgl = dari ?? _today();
    final tglSampai = sampai ?? tgl;
    final res = await _get(
        '${AppConstants.kasirPembelianStokUrl}?dari=$tgl&sampai=$tglSampai');
    if (res['success'] != true) return [];
    return (res['data'] as List).map((e) => PembelianStok.fromJson(e)).toList();
  }

  /// Ambil pengaturan bengkel (termasuk kuota_booking_harian).
  Future<Map<String, dynamic>> getPengaturan() =>
      _get('${AppConstants.baseUrl}/kasir/pengaturan.php');

  /// Simpan pengaturan bengkel. Kirim seluruh field (backend meng-overwrite
  /// semua kolom), bukan cuma kuota_booking_harian saja.
  Future<Map<String, dynamic>> updatePengaturan(Map<String, dynamic> data) =>
      _put('${AppConstants.baseUrl}/kasir/pengaturan.php', data);

  // ── INFO SUKU CADANG (view-only, dipakai di Aksi Cepat) ────
  // Pakai endpoint pelanggan/sparepart.php yang sama -- sudah dibuka juga
  // untuk role kasir di backend. Ini murni katalog (tidak ada data
  // pribadi), jadi aman dipakai bareng.
  Future<Map<String, dynamic>> getInfoSparepart({
    String? search,
    int? kategoriId,
  }) async {
    var url = '${AppConstants.baseUrl}/pelanggan/sparepart.php';
    final p = <String>[];
    if (search != null && search.isNotEmpty) p.add('search=$search');
    if (kategoriId != null) p.add('kategori_id=$kategoriId');
    if (p.isNotEmpty) url += '?${p.join('&')}';
    return _get(url);
  }

  Future<Map<String, dynamic>> getInfoSparepartDetail(int id) =>
      _get('${AppConstants.baseUrl}/pelanggan/sparepart.php?id=$id');

  // ── UPLOAD BUKTI TRANSFER ─────────────────────────────
  Future<Map<String, dynamic>> uploadBuktiBayar({
    required int transaksiId,
    required File foto,
  }) async {
    final token = await AuthService.instance.getToken();
    final uri =
        Uri.parse('${AppConstants.baseUrl}/kasir/transaksi.php?upload_bukti=1');
    final req = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['transaksi_id'] = transaksiId.toString()
      ..files.add(await http.MultipartFile.fromPath('bukti_bayar', foto.path));
    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return {'success': false, 'message': 'Response tidak valid'};
    }
  }

  // ── Helper tanggal ────────────────────────────────────
  String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
