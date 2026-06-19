// lib/core/state/auth_state.dart
//
// Menyimpan status login saat ini dan memberi tahu GoRouter (lewat
// ChangeNotifier) kapan harus mengevaluasi ulang redirect — misalnya
// setelah login berhasil atau setelah logout.

import 'package:flutter/foundation.dart';
import '../../features/auth/models/user_model.dart';
import '../../features/auth/services/auth_service.dart';

class AuthState extends ChangeNotifier {
  AuthState._();
  static final AuthState instance = AuthState._();

  UserModel? _user;
  bool _initialized = false;

  UserModel? get user => _user;
  bool get initialized => _initialized;
  bool get isLoggedIn => _user != null;

  Future<void> init() async {
    _user = await AuthService.instance.checkSession();
    _initialized = true;
    notifyListeners();
  }

  void setUser(UserModel? user) {
    _user = user;
    notifyListeners();
  }

  Future<void> logout() async {
    await AuthService.instance.logout();
    _user = null;
    notifyListeners();
  }

  /// Path beranda sesuai role, dipakai untuk redirect setelah login.
  String homePathFor(UserModel u) {
    return '/admin/dashboard';
  }
}
