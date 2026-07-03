import 'package:flutter/foundation.dart';
// lib/features/owner/services/owner_service.dart
// Setelah refactor: hanya laporan, dashboard, dan verifikasi kas.
// Akun kasir, sparepart, blokir, hari libur, mekanik → pindah ke admin_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../auth/services/auth_service.dart';
import '../../../core/constants/app_constants.dart';
import '../models/owner_models.dart';

class OwnerService {
  OwnerService._();
  static final OwnerService instance = OwnerService._();

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
      final res = await http
          .get(Uri.parse(url), headers: await _headers())
          .timeout(const Duration(seconds: 10));
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': 'Koneksi gagal: $e'};
    }
  }

  // Future<Map<String, dynamic>> _put(
  //     String url, Map<String, dynamic> body) async {
  //   try {
  //     final res = await http
  //         .put(Uri.parse(url),
  //             headers: await _headers(), body: jsonEncode(body))
  //         .timeout(const Duration(seconds: 10));
  //     return jsonDecode(res.body) as Map<String, dynamic>;
  //   } catch (e) {
  //     return {'success': false, 'message': 'Koneksi gagal: $e'};
  //   }
  // }

  // ── DASHBOARD ─────────────────────────────────────────
  Future<DashboardOwnerData?> getDashboard({String? tanggal}) async {
    try {
      final tgl = tanggal ?? _today();
      final res = await _get(
          '${AppConstants.baseUrl}/kasir/dashboard.php?tanggal=$tgl');
      debugPrint(
          '[getDashboard] success=${res['success']}, data type=${res['data']?.runtimeType}');
      if (res['success'] != true) return null;
      final rawData = res['data'];
      if (rawData == null) {
        debugPrint('[getDashboard] rawData is null!');
        return null;
      }
      final data = Map<String, dynamic>.from(rawData as Map);
      try {
        final stokRes =
            await _get('${AppConstants.adminStokMenipisUrl}?count_only=1');
        data['stok_menipis'] =
            stokRes['success'] == true ? (stokRes['data']?['total'] ?? 0) : 0;
      } catch (_) {
        data['stok_menipis'] = data['stok_menipis'] ?? 0;
      }
      debugPrint('[getDashboard] final data keys: ${data.keys.toList()}');
      final result = DashboardOwnerData.fromJson(data);
      debugPrint('[getDashboard] parsed OK: tanggal=${result.tanggal}');
      return result;
    } catch (e, st) {
      debugPrint('[getDashboard] EXCEPTION: $e\n$st');
      return null;
    }
  }

  // ── TRANSAKSI ─────────────────────────────────────────
  Future<Map<String, dynamic>> getTransaksi({String? tanggal}) =>
      _get('${AppConstants.ownerTransaksiUrl}'
          '?tanggal=${tanggal ?? _today()}');

  Future<Map<String, dynamic>> getDetailTransaksi(int id) =>
      _get('${AppConstants.ownerTransaksiUrl}?id=$id');

  // ── MUTASI STOK ───────────────────────────────────────
  Future<Map<String, dynamic>> getMutasiStok({
    required String dari,
    required String sampai,
    int? sparepartId,
  }) =>
      _get('${AppConstants.ownerMutasiStokUrl}'
          '?dari=$dari&sampai=$sampai'
          '${sparepartId != null ? '&sparepart_id=$sparepartId' : ''}');

  Future<Map<String, dynamic>> getRingkasanMutasi({
    required String dari,
    required String sampai,
  }) =>
      _get('${AppConstants.ownerMutasiStokUrl}'
          '?ringkasan=1&dari=$dari&sampai=$sampai');

  // ── LAPORAN ───────────────────────────────────────────
  Future<Map<String, dynamic>> getLaporanServis({
    String? tglMulai,
    String? tglSelesai,
    String? periode,
    int? mekanikId,
    int? jenisServisId,
  }) {
    var url =
        '${AppConstants.ownerLaporanServisUrl}?periode=${periode ?? 'hari_ini'}';
    if (tglMulai != null) url += '&tgl_mulai=$tglMulai';
    if (tglSelesai != null) url += '&tgl_selesai=$tglSelesai';
    if (mekanikId != null) url += '&mekanik_id=$mekanikId';
    if (jenisServisId != null) url += '&jenis_servis_id=$jenisServisId';
    return _get(url);
  }

  Future<Map<String, dynamic>> getLaporanSparepart({
    String? tglMulai,
    String? tglSelesai,
    String? periode,
  }) {
    var url = '${AppConstants.ownerLaporanUrl}?tipe=sparepart';
    if (periode != null) url += '&periode=$periode';
    if (tglMulai != null) url += '&tgl_mulai=$tglMulai';
    if (tglSelesai != null) url += '&tgl_selesai=$tglSelesai';
    return _get(url);
  }

  Future<Map<String, dynamic>> getLaporanKeuangan({
    String? tglMulai,
    String? tglSelesai,
    String? periode,
  }) {
    var url = '${AppConstants.ownerLaporanUrl}?tipe=keuangan';
    if (periode != null) url += '&periode=$periode';
    if (tglMulai != null) url += '&tgl_mulai=$tglMulai';
    if (tglSelesai != null) url += '&tgl_selesai=$tglSelesai';
    return _get(url);
  }

  // ── Helper ────────────────────────────────────────────
  String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
