// lib/features/auth/screens/register_screen.dart

import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _namaCtrl  = TextEditingController();
  final _hpCtrl    = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _passConfirmCtrl = TextEditingController();
  final _alamatCtrl = TextEditingController();

  bool _isLoading = false;
  bool _obscure   = true;

  @override
  void dispose() {
    for (final c in [_namaCtrl,_hpCtrl,_emailCtrl,_passCtrl,_passConfirmCtrl,_alamatCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _doRegister() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final result = await AuthService.instance.register(
      nama:     _namaCtrl.text.trim(),
      noHp:     _hpCtrl.text.trim(),
      password: _passCtrl.text.trim(),
      email:    _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      alamat:   _alamatCtrl.text.trim().isEmpty ? null : _alamatCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registrasi berhasil! Silakan login.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] as String),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Akun'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildField(_namaCtrl, 'Nama Lengkap', Icons.person,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null),
              const SizedBox(height: 14),
              _buildField(_hpCtrl, 'No HP (08xx)', Icons.phone,
                type: TextInputType.phone,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                  if (v.trim().length < 10) return 'No HP tidak valid';
                  return null;
                }),
              const SizedBox(height: 14),
              _buildField(_emailCtrl, 'Email', Icons.email,
                type: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                  final valid = RegExp(r'^[\w-.]+@[\w-]+\.[a-z]{2,}$').hasMatch(v.trim());
                  return valid ? null : 'Format email tidak valid';
                }),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passCtrl,
                obscureText: _obscure,
                decoration: _inputDeco('Password', Icons.lock,
                  suffix: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                  if (v.trim().length < 6) return 'Minimal 6 karakter';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passConfirmCtrl,
                obscureText: _obscure,
                decoration: _inputDeco('Konfirmasi Password', Icons.lock_outline),
                validator: (v) {
                  if (v != _passCtrl.text) return 'Password tidak cocok';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _buildField(_alamatCtrl, 'Alamat (opsional)', Icons.location_on,
                maxLines: 2),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _doRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isLoading
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('Daftar', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType type = TextInputType.text,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      maxLines: maxLines,
      decoration: _inputDeco(label, icon),
      validator: validator,
    );
  }

  InputDecoration _inputDeco(String label, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.blue.shade700),
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}
