// lib/features/admin/screens/admin_shell.dart
//
// Dipakai oleh semua screen admin sebagai wrapper layout.
// Menyediakan sidebar dengan navigasi antar halaman admin.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/app_shell.dart';
//import '../../../core/constants/app_theme.dart';

const Color _adminFg = Color(0xFF3C3489);
const Color _adminBg = Color(0xFFEEEDFE);

class AdminShell extends StatelessWidget {
  final String currentRoute;
  final String pageTitle;
  final List<Widget> actions;
  final Widget child;

  const AdminShell({
    super.key,
    required this.currentRoute,
    required this.pageTitle,
    this.actions = const [],
    required this.child,
  });

  static const _nav = [
    NavEntry.item(
      icon: Icons.dashboard_outlined,
      label: 'Dashboard',
      route: '/admin/dashboard',
    ),
    NavEntry.section('Master Data'),
    NavEntry.item(
      icon: Icons.inventory_2_outlined,
      label: 'Sparepart',
      route: '/admin/sparepart',
    ),
    NavEntry.item(
      icon: Icons.build_outlined,
      label: 'Mekanik',
      route: '/admin/mekanik',
    ),
    NavEntry.item(
      icon: Icons.miscellaneous_services_outlined,
      label: 'Jenis Servis',
      route: '/admin/jenis-servis',
    ),
    NavEntry.item(
      icon: Icons.event_busy_outlined,
      label: 'Hari Libur',
      route: '/admin/hari-libur',
    ),
    NavEntry.section('Manajemen'),
    NavEntry.item(
      icon: Icons.manage_accounts_outlined,
      label: 'Akun Staff',
      route: '/admin/akun',
    ),
    NavEntry.item(
      icon: Icons.people_outline,
      label: 'Pelanggan',
      route: '/admin/pelanggan',
    ),
    NavEntry.section('Konfigurasi'),
    NavEntry.item(
      icon: Icons.store_outlined,
      label: 'Pengaturan Bengkel',
      route: '/admin/pengaturan',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppShell(
      roleLabel: 'Admin',
      roleBg: _adminBg,
      roleFg: _adminFg,
      nav: _nav,
      currentRoute: currentRoute,
      onNavigate: (route) => context.go(route),
      pageTitle: pageTitle,
      actions: actions,
      child: child,
    );
  }
}
