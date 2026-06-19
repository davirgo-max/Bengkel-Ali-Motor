// lib/features/auth/services/auth_service.dart

import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final _api = ApiClient.instance;

  // ── Session ──────────────────────────────────────────────

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.keyToken);
  }

  Future<UserModel?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(AppConstants.keyUser);
    if (s == null) return null;
    try {
      return UserModel.fromJsonString(s);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveSession(String token, UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyToken, token);
    await prefs.setString(AppConstants.keyUser, user.toJsonString());
    await prefs.setString(AppConstants.keyRole, user.role);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keyToken);
    await prefs.remove(AppConstants.keyUser);
    await prefs.remove(AppConstants.keyRole);
  }

  // ── Login ────────────────────────────────────────────────

  /// Returns: {'success': true, 'user': UserModel} or {'success': false, 'message': '...'}
  Future<Map<String, dynamic>> login(String username, String password) async {
    // PENTING: backend butuh 'tipe':'user' agar mencari di tabel users
    // (admin/kasir/owner), bukan tabel pelanggan.
    final body = await _api.post(AppConstants.loginUrl, {
      'username': username,
      'password': password,
      'tipe': 'user',
    });

    if (body['success'] != true) {
      return {'success': false, 'message': body['message'] ?? 'Login gagal'};
    }

    final data = body['data'] as Map<String, dynamic>?;
    if (data == null) {
      return {'success': false, 'message': 'Respons server tidak valid'};
    }

    final token = data['token'] as String?;
    final role = data['role'] as String?;
    final userJson = data['user'] as Map<String, dynamic>?;

    if (token == null || role == null || userJson == null) {
      return {'success': false, 'message': 'Respons server tidak lengkap'};
    }

    // Hanya izinkan admin, kasir, owner login di web
    if (!['admin', 'kasir', 'owner'].contains(role)) {
      return {
        'success': false,
        'message': 'Akun ini tidak memiliki akses ke dashboard web',
      };
    }

    final user = UserModel.fromJson(userJson, role);
    await _saveSession(token, user);
    return {'success': true, 'user': user};
  }

  // ── Check session ────────────────────────────────────────

  Future<UserModel?> checkSession() async {
    final token = await getToken();
    if (token == null) return null;

    final body = await _api.get(AppConstants.meUrl);
    if (body['success'] != true) {
      // Token ditolak server (expired/invalid) → hapus sesi lokal.
      // Tapi jika gagalnya karena tidak ada koneksi, body tetap berisi
      // success:false dengan pesan koneksi — bedakan dengan cek data.
      if (body['message'] == 'Tidak dapat terhubung ke server') {
        return await getUser(); // offline — pakai cache
      }
      await logout();
      return null;
    }
    return await getUser();
  }
}
