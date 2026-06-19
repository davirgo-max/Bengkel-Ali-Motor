// lib/features/auth/services/auth_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../models/user_model.dart';
import '../../../core/constants/app_constants.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  // ── Login ─────────────────────────────────────────────────
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
    required String tipe,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(AppConstants.loginUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': username,
              'password': password,
              'tipe': tipe,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (body['success'] == true) {
        final data = body['data'] as Map<String, dynamic>;
        final token = data['token'] as String;
        final role = data['role'] as String;
        final user = UserModel.fromJson(
          data['user'] as Map<String, dynamic>,
          role,
        );

        await _saveSession(token: token, user: user);

        // Kirim FCM token ke server (hanya untuk pelanggan)
        if (role == 'pelanggan') {
          await _kirimFcmToken(token);
        }

        return {'success': true, 'user': user};
      }

      return {'success': false, 'message': body['message'] ?? 'Login gagal'};
    } catch (e) {
      return {
        'success': false,
        'message':
            'Tidak dapat terhubung ke server. Pastikan XAMPP aktif dan IP benar.'
      };
    }
  }

  // ── Kirim FCM token ke server ─────────────────────────────
  Future<void> _kirimFcmToken(String authToken) async {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) return;

      // Ambil info device untuk kolom device_info di DB
      String? deviceInfo;
      try {
        final di = DeviceInfoPlugin();
        if (Platform.isAndroid) {
          final android = await di.androidInfo;
          deviceInfo =
              '${android.brand} ${android.model}, Android ${android.version.release}';
        } else if (Platform.isIOS) {
          final ios = await di.iosInfo;
          deviceInfo = '${ios.name}, iOS ${ios.systemVersion}';
        }
      } catch (_) {
        // device_info gagal tidak masalah, kirim tanpa info device
      }

      await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/pelanggan/fcm_token.php'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
            body: jsonEncode({
              'fcm_token': fcmToken,
              if (deviceInfo != null) 'device_info': deviceInfo, // ← tambahan
            }),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Gagal kirim FCM token tidak boleh ganggu proses login
    }
  }

  // ── Register pelanggan ────────────────────────────────────
  Future<Map<String, dynamic>> register({
    required String nama,
    required String noHp,
    required String password,
    String? email,
    String? alamat,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(AppConstants.registerUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'nama': nama,
              'no_hp': noHp,
              'password': password,
              'email': email,
              'alamat': alamat,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': body['success'] ?? false,
        'message': body['message'] ?? 'Registrasi gagal',
      };
    } catch (e) {
      return {'success': false, 'message': 'Tidak dapat terhubung ke server.'};
    }
  }

  // ── Lupa Password: kirim OTP ──────────────────────────────
  Future<Map<String, dynamic>> forgotPassword({
    required String identifier, // no_hp atau email
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(AppConstants.forgotPasswordUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'identifier': identifier}),
          )
          .timeout(const Duration(seconds: 10));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': body['success'] ?? false,
        'message': body['message'] ?? 'Gagal mengirim OTP',
        'dev_otp': body['dev_otp'], // null saat production
      };
    } catch (e) {
      return {'success': false, 'message': 'Tidak dapat terhubung ke server.'};
    }
  }

  // ── Reset Password: verifikasi OTP & update password ─────
  Future<Map<String, dynamic>> resetPassword({
    required String identifier,
    required String otp,
    required String passwordBaru,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(AppConstants.resetPasswordUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'identifier': identifier,
              'otp': otp,
              'password_baru': passwordBaru,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'success': body['success'] ?? false,
        'message': body['message'] ?? 'Gagal reset password',
      };
    } catch (e) {
      return {'success': false, 'message': 'Tidak dapat terhubung ke server.'};
    }
  }

  // ── Cek session saat app dibuka ───────────────────────────
  Future<UserModel?> checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.keyToken);
    final userJson = prefs.getString(AppConstants.keyUser);

    if (token == null || userJson == null) return null;

    try {
      final response = await http.get(
        Uri.parse(AppConstants.meUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 8));

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['success'] == true) {
        final data = body['data'] as Map<String, dynamic>;
        final role = data['role'] as String;
        final user =
            UserModel.fromJson(data['user'] as Map<String, dynamic>, role);

        // Refresh FCM token saat session masih valid (hanya pelanggan)
        if (role == 'pelanggan') {
          await _kirimFcmToken(token);
        }

        return user;
      }

      await logout();
      return null;
    } catch (_) {
      final map = jsonDecode(userJson) as Map<String, dynamic>;
      final role = prefs.getString(AppConstants.keyRole) ?? 'pelanggan';
      return UserModel.fromJson(map, role);
    }
  }

  // ── Logout ────────────────────────────────────────────────
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keyToken);
    await prefs.remove(AppConstants.keyRole);
    await prefs.remove(AppConstants.keyUser);
  }

  // ── Ambil token tersimpan ─────────────────────────────────
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.keyToken);
  }

  // ── Simpan session ────────────────────────────────────────
  Future<void> _saveSession({
    required String token,
    required UserModel user,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyToken, token);
    await prefs.setString(AppConstants.keyRole, user.role);
    await prefs.setString(AppConstants.keyUser, jsonEncode(user.toJson()));
  }
}
