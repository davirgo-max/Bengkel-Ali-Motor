// lib/features/kasir/screens/dashboard_kasir_screen.dart

import 'package:flutter/material.dart';
import '../../auth/models/user_model.dart';
import '../../auth/services/auth_service.dart';
import '../../../core/utils/format_helper.dart';
import '../../../core/constants/app_constants.dart';
import '../services/kasir_service.dart';
import 'booking_kasir_screen.dart';
import 'form_walkin_screen.dart';
import 'jual_sparepart_screen.dart';

class DashboardKasirScreen extends StatefulWidget {
  final UserModel user;
  const DashboardKasirScreen({super.key, required this.user});

  @override
  State<DashboardKasirScreen> createState() => _DashboardKasirScreenState();
}

class _DashboardKasirScreenState extends State<DashboardKasirScreen> {
  bool _loading = true;
  Map<String, dynamic>? _dashboardData;
  final _today = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final svc = KasirService.instance;

    final dashRes = await svc.getDashboard();

    if (!mounted) return;

    setState(() {
      _dashboardData = dashRes['success'] == true
          ? dashRes['data'] as Map<String, dynamic>?
          : null;
      _loading = false;
    });
  }

  Future<void> _autoNoShow() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Auto No-Show'),
        content: const Text(
            'Proses semua booking yang sudah lewat waktu dan belum hadir?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Proses'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final res = await KasirService.instance.autoScanNoShow();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res['message'] as String? ?? ''),
      backgroundColor: res['success'] == true ? Colors.orange : Colors.red,
    ));
    if (res['success'] == true) _loadData();
  }

  String _fmtToday() {
    const hari = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu'
    ];
    const bulan = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des'
    ];
    final d = _today;
    return '${hari[d.weekday - 1]}, ${d.day} ${bulan[d.month]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          slivers: [
            // ── AppBar ──────────────────────────────────
            SliverAppBar(
              expandedHeight: 120,
              pinned: true,
              backgroundColor: Colors.indigo.shade700,
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  tooltip: 'Logout',
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Logout?'),
                        content: const Text('Apakah kamu yakin ingin keluar?'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Batal')),
                          ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red),
                              child: const Text('Logout',
                                  style: TextStyle(color: Colors.white))),
                        ],
                      ),
                    );
                    if (ok != true || !context.mounted) return;
                    await AuthService.instance.logout();
                    if (context.mounted) {
                      Navigator.pushReplacementNamed(context, '/login');
                    }
                  },
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.indigo.shade800, Colors.indigo.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('Halo, ${widget.user.nama.split(' ').first}! 👋',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      Text(_fmtToday(),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),

            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Ringkasan Hari Ini ───────────
                      _sectionTitle('Ringkasan Hari Ini'),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.6,
                        children: [
                          _StatCard(
                            label: 'Total Booking',
                            value: (_dashboardData?['booking']?['total'] ?? 0)
                                .toString(),
                            icon: Icons.calendar_today,
                            color: Colors.blue,
                          ),
                          _StatCard(
                            label: 'Servis Aktif',
                            value: (_dashboardData?['servis']?['aktif'] ?? 0)
                                .toString(),
                            icon: Icons.build,
                            color: Colors.orange,
                          ),
                          _StatCard(
                            label: 'Selesai',
                            value: (_dashboardData?['servis']
                                        ?['selesai_servis'] ??
                                    0)
                                .toString(),
                            icon: Icons.check_circle,
                            color: Colors.green,
                          ),
                          _StatCard(
                            label: 'Pemasukan',
                            value: FormatHelper.currency(
                              double.tryParse((_dashboardData?['pemasukan']
                                              ?['total'] ??
                                          0)
                                      .toString()) ??
                                  0,
                            ),
                            icon: Icons.payments,
                            color: Colors.teal,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ── Aksi Cepat ───────────────────
                      _sectionTitle('Aksi Cepat'),
                      Row(
                        children: [
                          _QuickAction(
                            icon: Icons.person_add,
                            label: 'Walk-in\nBaru',
                            color: Colors.purple,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const FormWalkInScreen()),
                            ).then((_) => _loadData()),
                          ),
                          const SizedBox(width: 12),
                          _QuickAction(
                            icon: Icons.storefront_outlined,
                            label: 'Jual\nSparepart',
                            color: Colors.orange,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const JualSparepartScreen()),
                            ).then((_) => _loadData()),
                          ),
                          const SizedBox(width: 12),
                          _QuickAction(
                            icon: Icons.calendar_today,
                            label: 'Lihat\nBooking',
                            color: Colors.teal,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const BookingKasirScreen()),
                            ).then((_) => _loadData()),
                          ),
                          const SizedBox(width: 12),
                          _QuickAction(
                            icon: Icons.schedule_send,
                            label: 'Auto\nNo-Show',
                            color: Colors.red,
                            onTap: _autoNoShow,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppConstants.bottomPadding),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(t,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      );
}

// ── Stat Card ────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(label,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ),
                Icon(icon, color: color, size: 20),
              ],
            ),
            Text(value,
                style: TextStyle(
                    fontSize: value.length > 8 ? 14 : 22,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ],
        ),
      ),
    );
  }
}

// ── Quick Action ─────────────────────────────────────────
class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 6),
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w600,
                      height: 1.3)),
            ],
          ),
        ),
      ),
    );
  }
}
