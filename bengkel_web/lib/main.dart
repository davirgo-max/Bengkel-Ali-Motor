// lib/main.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/constants/app_theme.dart';
import 'core/state/auth_state.dart';
import 'features/auth/screens/login_screen.dart';

// Admin screens
import 'features/admin/screens/dashboard_admin_screen.dart';
import 'features/admin/screens/kelola_sparepart_screen.dart';
import 'features/admin/screens/kelola_mekanik_screen.dart';
import 'features/admin/screens/kelola_jenis_servis_screen.dart';
import 'features/admin/screens/kelola_staff_screen.dart';
import 'features/admin/screens/kelola_pelanggan_admin_screen.dart';
import 'features/admin/screens/hari_libur_screen.dart';
import 'features/admin/screens/pengaturan_bengkel_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  await AuthState.instance.init();
  runApp(const BengkelWebApp());
}

class BengkelWebApp extends StatelessWidget {
  const BengkelWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Bengkel Ali Motor — Dashboard Staff',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
    );
  }
}

// ─── Router ──────────────────────────────────────────────────────────────────

final _router = GoRouter(
  refreshListenable: AuthState.instance,
  initialLocation: '/login',
  redirect: (context, state) {
    final auth = AuthState.instance;
    if (!auth.initialized) return null;

    final loggedIn = auth.isLoggedIn;
    final onLogin = state.matchedLocation == '/login';

    if (!loggedIn && !onLogin) return '/login';
    if (loggedIn && onLogin) return auth.homePathFor(auth.user!);
    return null;
  },
  routes: [
    // ── Auth ──────────────────────────────────────────────
    GoRoute(
      path: '/login',
      builder: (_, __) => const LoginScreen(),
    ),

    // ── Admin ─────────────────────────────────────────────
    GoRoute(
      path: '/admin/dashboard',
      builder: (_, __) => const DashboardAdminScreen(),
    ),
    GoRoute(
      path: '/admin/sparepart',
      builder: (_, __) => const KelolaSparepartScreen(),
    ),
    GoRoute(
      path: '/admin/mekanik',
      builder: (_, __) => const KelolaMekanikScreen(),
    ),
    GoRoute(
      path: '/admin/jenis-servis',
      builder: (_, __) => const KelolaJenisServisScreen(),
    ),
    GoRoute(
      path: '/admin/akun',
      builder: (_, __) => const KelolaStaffScreen(),
    ),
    GoRoute(
      path: '/admin/pelanggan',
      builder: (_, __) => const KelolaPelangganAdminScreen(),
    ),
    GoRoute(
      path: '/admin/hari-libur',
      builder: (_, __) => const HariLiburScreen(),
    ),
    GoRoute(
      path: '/admin/pengaturan',
      builder: (_, __) => const PengaturanBengkelScreen(),
    ),
  ],
);
