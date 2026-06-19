// lib/features/auth/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/state/auth_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final username = _userCtrl.text.trim();
    final password = _passCtrl.text;
    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = 'Username dan password wajib diisi');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await AuthService.instance.login(username, password);
    if (!mounted) return;
    setState(() => _loading = false);

    if (result['success'] == true) {
      final user = result['user'];
      AuthState.instance.setUser(user);
      if (!mounted) return;
      context.go(AuthState.instance.homePathFor(user));
    } else {
      setState(() => _error = result['message'] as String?);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 760;

    final formPanel = Container(
      width: isNarrow ? double.infinity : 420,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 64),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Masuk',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Gunakan akun staff yang diberikan admin',
            style: TextStyle(fontSize: 13, color: Color(0xFF888899)),
          ),
          const SizedBox(height: 36),

          const Text(
            'Username',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF333344),
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _userCtrl,
            autofocus: true,
            onSubmitted: (_) => _login(),
            decoration: const InputDecoration(
              hintText: 'Masukkan username',
              prefixIcon: Icon(Icons.person_outline, size: 18),
            ),
          ),
          const SizedBox(height: 18),

          const Text(
            'Password',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF333344),
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _passCtrl,
            obscureText: _obscure,
            onSubmitted: (_) => _login(),
            decoration: InputDecoration(
              hintText: 'Masukkan password',
              prefixIcon: const Icon(Icons.lock_outline, size: 18),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 18,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 12),

          if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFCEBEB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 16,
                    color: Color(0xFFA32D2D),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFA32D2D),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: _loading ? null : _login,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Masuk'),
            ),
          ),

          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'Lupa password? Hubungi admin sistem.',
              style: TextStyle(fontSize: 12, color: Color(0xFF888899)),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );

    final brandPanel = Container(
      color: AppTheme.primary,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.car_repair, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 24),
          const Text(
            'Bengkel Ali Motor',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Dashboard Staff',
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 48),
          _infoRow(
            Icons.admin_panel_settings,
            'Admin',
            'Kelola data master & akun',
          ),
          const SizedBox(height: 14),
          _infoRow(
            Icons.point_of_sale,
            'Kasir',
            'Proses booking, servis & transaksi',
          ),
          const SizedBox(height: 14),
          _infoRow(Icons.bar_chart, 'Owner', 'Pantau laporan & verifikasi kas'),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: AppTheme.canvasBg,
      body: isNarrow
          ? SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: 280, child: brandPanel),
                  formPanel,
                ],
              ),
            )
          : Row(
              children: [
                Expanded(child: brandPanel),
                formPanel,
              ],
            ),
    );
  }

  Widget _infoRow(IconData icon, String title, String sub) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 48),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              sub,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
