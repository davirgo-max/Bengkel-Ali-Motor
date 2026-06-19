import 'package:flutter/material.dart';
import '../auth/models/user_model.dart';
import 'screens/dashboard_owner_screen.dart';
import 'screens/laporan_screen.dart';
import 'screens/transaksi_owner_screen.dart';
import 'screens/mutasi_stok_screen.dart';

class OwnerNav extends StatefulWidget {
  final UserModel user;
  const OwnerNav({super.key, required this.user});

  @override
  State<OwnerNav> createState() => _OwnerNavState();
}

class _OwnerNavState extends State<OwnerNav> {
  int _idx = 0;

  void _navigateTo(int idx) => _onTabChanged(idx);

  void _onTabChanged(int idx) => setState(() => _idx = idx);

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardOwnerScreen(user: widget.user, onNavigate: _navigateTo),
      const LaporanScreen(),
      const TransaksiOwnerScreen(),
      const MutasiStokScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _idx, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: _onTabChanged,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Dashboard'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: 'Laporan'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Transaksi'),
          NavigationDestination(
              icon: Icon(Icons.swap_vert_outlined),
              selectedIcon: Icon(Icons.swap_vert),
              label: 'Stok'),
        ],
      ),
    );
  }
}
