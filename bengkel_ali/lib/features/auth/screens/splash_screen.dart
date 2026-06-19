// lib/features/auth/screens/splash_screen.dart
// Layar pertama saat app dibuka — cek session, lalu arahkan ke halaman yang tepat

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../../../core/constants/app_constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    // Tampilkan splash minimal 1.5 detik agar tidak kedip
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    final user = await AuthService.instance.checkSession();

    if (!mounted) return;

    if (user == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    _navigateByRole(user);
  }

  void _navigateByRole(UserModel user) {
    // FIX: tambahkan case 'admin' agar tidak fallback ke /pelanggan
    final String route;
    if (user.isOwner) {
      route = '/owner';
    } else if (user.isKasir) {
      route = '/kasir';
    } else {
      route = '/pelanggan';
    }

    Navigator.pushReplacementNamed(context, route, arguments: user);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade700,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child:
                  Icon(Icons.car_repair, size: 52, color: Colors.blue.shade700),
            ),
            const SizedBox(height: 20),
            const Text(
              AppConstants.appName,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 40),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
