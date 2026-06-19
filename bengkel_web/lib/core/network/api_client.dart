// lib/core/network/api_client.dart
//
// Klien HTTP generik dengan penanganan error yang aman.
// Semua service (admin/kasir/owner) memakai ini agar konsisten:
// - selalu menyisipkan header Authorization
// - selalu menangani exception (timeout, koneksi putus, dll)
// - selalu mengembalikan Map<String,dynamic> berisi {success, message, data?}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.keyToken);
  }

  Map<String, String> _headers(String? token) => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  Map<String, dynamic> _safeDecode(http.Response res) {
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'success': false, 'message': 'Format respons tidak dikenal'};
    } catch (_) {
      return {
        'success': false,
        'message': 'Gagal membaca respons server (kode ${res.statusCode})',
      };
    }
  }

  Future<Map<String, dynamic>> get(
    String url, {
    Map<String, String>? query,
  }) async {
    try {
      final token = await _getToken();
      final uri = Uri.parse(url).replace(queryParameters: query);
      final res = await http
          .get(uri, headers: _headers(token))
          .timeout(const Duration(seconds: 15));
      return _safeDecode(res);
    } catch (e) {
      return {'success': false, 'message': 'Tidak dapat terhubung ke server'};
    }
  }

  Future<Map<String, dynamic>> post(
    String url,
    Map<String, dynamic> body, {
    Map<String, String>? query,
  }) async {
    try {
      final token = await _getToken();
      final uri = Uri.parse(url).replace(queryParameters: query);
      final res = await http
          .post(uri, headers: _headers(token), body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
      return _safeDecode(res);
    } catch (e) {
      return {'success': false, 'message': 'Tidak dapat terhubung ke server'};
    }
  }

  Future<Map<String, dynamic>> put(
    String url,
    Map<String, dynamic> body, {
    Map<String, String>? query,
  }) async {
    try {
      final token = await _getToken();
      final uri = Uri.parse(url).replace(queryParameters: query);
      final res = await http
          .put(uri, headers: _headers(token), body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
      return _safeDecode(res);
    } catch (e) {
      return {'success': false, 'message': 'Tidak dapat terhubung ke server'};
    }
  }

  Future<Map<String, dynamic>> delete(
    String url, {
    Map<String, String>? query,
  }) async {
    try {
      final token = await _getToken();
      final uri = Uri.parse(url).replace(queryParameters: query);
      final res = await http
          .delete(uri, headers: _headers(token))
          .timeout(const Duration(seconds: 15));
      return _safeDecode(res);
    } catch (e) {
      return {'success': false, 'message': 'Tidak dapat terhubung ke server'};
    }
  }

  /// Upload file (multipart) — dipakai untuk foto sparepart.
  Future<Map<String, dynamic>> upload(
    String url, {
    required Map<String, String> fields,
    required String fileField,
    required List<int> fileBytes,
    required String fileName,
  }) async {
    try {
      final token = await _getToken();
      final uri = Uri.parse(url);
      final req = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer ${token ?? ''}'
        ..fields.addAll(fields)
        ..files.add(
          http.MultipartFile.fromBytes(
            fileField,
            fileBytes,
            filename: fileName,
          ),
        );
      final streamed = await req.send().timeout(const Duration(seconds: 30));
      final res = await http.Response.fromStream(streamed);
      return _safeDecode(res);
    } catch (e) {
      return {
        'success': false,
        'message': 'Upload gagal: tidak dapat terhubung ke server',
      };
    }
  }
}
