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

  Future<Map<String, dynamic>> get(String url, {Map<String, String>? query}) async {
    try {
      final token = await _getToken();
      final uri   = Uri.parse(url).replace(queryParameters: query);
      final res   = await http.get(uri, headers: _headers(token))
                              .timeout(const Duration(seconds: 12));
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': 'Tidak dapat terhubung ke server'};
    }
  }

  Future<Map<String, dynamic>> post(String url, Map<String, dynamic> body) async {
    try {
      final token = await _getToken();
      final res   = await http.post(
        Uri.parse(url),
        headers: _headers(token),
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 12));
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': 'Tidak dapat terhubung ke server'};
    }
  }

  Future<Map<String, dynamic>> put(String url, Map<String, dynamic> body,
      {Map<String, String>? query}) async {
    try {
      final token = await _getToken();
      final uri   = Uri.parse(url).replace(queryParameters: query);
      final res   = await http.put(uri, headers: _headers(token), body: jsonEncode(body))
                              .timeout(const Duration(seconds: 12));
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': 'Tidak dapat terhubung ke server'};
    }
  }

  Future<Map<String, dynamic>> delete(String url, {Map<String, String>? query}) async {
    try {
      final token = await _getToken();
      final uri   = Uri.parse(url).replace(queryParameters: query);
      final res   = await http.delete(uri, headers: _headers(token))
                              .timeout(const Duration(seconds: 12));
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      return {'success': false, 'message': 'Tidak dapat terhubung ke server'};
    }
  }
}
