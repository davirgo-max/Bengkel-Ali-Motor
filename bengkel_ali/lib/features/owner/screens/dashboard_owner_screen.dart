// lib/features/owner/screens/dashboard_owner_screen.dart

import 'package:flutter/material.dart';
import '../../auth/models/user_model.dart';
import '../../auth/services/auth_service.dart';
import '../../../core/utils/format_helper.dart';
import '../../../core/constants/app_constants.dart';
import '../services/owner_service.dart';
import '../models/owner_models.dart';

class DashboardOwnerScreen extends StatefulWidget {
  final UserModel user;
  final void Function(int)? onNavigate;

  const DashboardOwnerScreen({
    super.key,
    required this.user,
    this.onNavigate,
  });

  @override
  State<DashboardOwnerScreen> createState() => _DashboardOwnerScreenState();
}

class _DashboardOwnerScreenState extends State<DashboardOwnerScreen> {
  bool _loading = true;
  DashboardOwnerData? _data;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final svc = OwnerService.instance;
    final tgl = _fmtDate(_selectedDate);

    // ── Dashboard (wajib) ──────────────────────────────
    DashboardOwnerData? dashboard;
    try {
      dashboard = await svc.getDashboard(tanggal: tgl);
    } catch (e) {
      debugPrint('[Dashboard] getDashboard error: $e');
    }
    if (!mounted) return;

    setState(() {
      _data = dashboard;
      _loading = false;
    });
  }

  Future<void> _pilihTanggal() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadData();
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _displayDate(DateTime d) {
    const b = [
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
    return '${d.day} ${b[d.month]} ${d.year}';
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
              expandedHeight: 130,
              pinned: true,
              backgroundColor: Colors.deepPurple.shade700,
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
                      colors: [
                        Colors.deepPurple.shade800,
                        Colors.deepPurple.shade600
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text('Dashboard Owner 👑',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      GestureDetector(
                        onTap: _pilihTanggal,
                        child: Row(children: [
                          Text(_displayDate(_selectedDate),
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13)),
                          const SizedBox(width: 4),
                          const Icon(Icons.edit_calendar,
                              color: Colors.white54, size: 14),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_data == null)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off,
                          size: 56, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'Gagal memuat data dashboard.\nPeriksa koneksi dan coba lagi.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _loadData,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Coba Lagi'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple.shade700,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Pemasukan ────────────────────
                      _sectionTitle('Pemasukan Hari Ini'),
                      Card(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(children: [
                            _infoRow(
                                'Total Pemasukan',
                                FormatHelper.currency(
                                    _data?.totalPemasukan ?? 0),
                                Colors.teal,
                                bold: true),
                            const Divider(height: 16),
                            _infoRow(
                                'Cash',
                                FormatHelper.currency(
                                    _data?.pemasukanCash ?? 0),
                                Colors.black87),
                            _infoRow(
                                'Transfer',
                                FormatHelper.currency(
                                    _data?.pemasukanTransfer ?? 0),
                                Colors.black87),
                            _infoRow(
                                'Jml Transaksi',
                                '${_data?.jumlahTransaksi ?? 0}x',
                                Colors.black87),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Stat Cards ───────────────────
                      _sectionTitle('Aktivitas Hari Ini'),
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
                            value: '${_data?.totalBooking ?? 0}',
                            icon: Icons.calendar_today,
                            color: Colors.blue,
                          ),
                          _StatCard(
                            label: 'Servis Selesai',
                            value: '${_data?.servisSelesai ?? 0}',
                            icon: Icons.check_circle,
                            color: Colors.green,
                          ),
                          _StatCard(
                            label: 'Menunggu Bayar',
                            value: '${_data?.menungguBayar ?? 0}',
                            icon: Icons.pending_actions,
                            color: Colors.orange,
                          ),
                          _StatCard(
                            label: 'No-Show',
                            value: '${_data?.noShow ?? 0}',
                            icon: Icons.person_off,
                            color: Colors.red,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Aksi Cepat ───────────────────
                      _sectionTitle('Aksi Cepat'),
                      Row(children: [
                        _QuickAction(
                          icon: Icons.bar_chart,
                          label: 'Laporan',
                          color: Colors.blue,
                          onTap: () => widget.onNavigate?.call(1),
                        ),
                        const SizedBox(width: 12),
                        _QuickAction(
                          icon: Icons.account_balance_wallet,
                          label: 'Verifikasi Kas',
                          color: Colors.teal,
                          onTap: () => widget.onNavigate?.call(2),
                        ),
                        const SizedBox(width: 12),
                        _QuickAction(
                          icon: Icons.manage_accounts,
                          label: 'Kelola',
                          color: Colors.deepPurple,
                          onTap: () => widget.onNavigate?.call(3),
                        ),
                      ]),
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

  Widget _infoRow(String label, String value, Color color,
          {bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                    color: color)),
          ],
        ),
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
                    fontSize: 22, fontWeight: FontWeight.bold, color: color)),
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
