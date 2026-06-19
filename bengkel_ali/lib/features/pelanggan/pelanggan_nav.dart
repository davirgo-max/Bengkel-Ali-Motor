import 'package:flutter/material.dart';
import '../auth/models/user_model.dart';
import 'screens/beranda_screen.dart';
import 'screens/booking_screen.dart';
import 'screens/status_servis_screen.dart';
import 'screens/profil_screen.dart';

class PelangganNav extends StatefulWidget {
  final UserModel user;
  const PelangganNav({super.key, required this.user});

  @override
  State<PelangganNav> createState() => _PelangganNavState();
}

class _PelangganNavState extends State<PelangganNav> {
  int _currentIndex = 0;

  late final List<Widget> _screens = [
    BerandaScreen(user: widget.user),
    const BookingScreen(),
    const StatusServisScreen(),
    ProfilScreen(user: widget.user),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home), label: 'Beranda'),
          NavigationDestination(icon: Icon(Icons.calendar_today_outlined),
              selectedIcon: Icon(Icons.calendar_today), label: 'Booking'),
          NavigationDestination(icon: Icon(Icons.build_outlined),
              selectedIcon: Icon(Icons.build), label: 'Status Servis'),
          NavigationDestination(icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}
