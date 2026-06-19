import 'package:flutter/material.dart';
import '../auth/models/user_model.dart';
import 'screens/dashboard_kasir_screen.dart';
import 'screens/booking_kasir_screen.dart';
import 'screens/servis_kasir_screen.dart';
import 'screens/sparepart_screen.dart';
import 'screens/transaksi_kasir_screen.dart';

class KasirNav extends StatefulWidget {
  final UserModel user;
  const KasirNav({super.key, required this.user});

  @override
  State<KasirNav> createState() => _KasirNavState();
}

class _KasirNavState extends State<KasirNav> {
  int _idx = 0;

  late final List<Widget> _screens = [
    DashboardKasirScreen(user: widget.user),
    const BookingKasirScreen(),
    const ServisKasirScreen(),
    const SparepartScreen(),
    const TransaksiKasirScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _idx, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Dashboard'),
          NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined),
              selectedIcon: Icon(Icons.calendar_today),
              label: 'Booking'),
          NavigationDestination(
              icon: Icon(Icons.build_outlined),
              selectedIcon: Icon(Icons.build),
              label: 'Servis'),
          NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront),
              label: 'Sparepart'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Transaksi'),
        ],
      ),
    );
  }
}
