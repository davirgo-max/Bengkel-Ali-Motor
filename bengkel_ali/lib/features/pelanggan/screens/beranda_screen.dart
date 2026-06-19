import 'package:flutter/material.dart';
import '../../auth/models/user_model.dart';
import '../services/pelanggan_service.dart';
import '../models/pelanggan_models.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../core/utils/format_helper.dart';
import 'sparepart_screen.dart';
import 'booking_screen.dart';
import 'status_servis_screen.dart';
import 'notifikasi_screen.dart';

class BerandaScreen extends StatefulWidget {
  final UserModel user;
  const BerandaScreen({super.key, required this.user});

  @override
  State<BerandaScreen> createState() => _BerandaScreenState();
}

class _BerandaScreenState extends State<BerandaScreen> {
  List<BookingModel> _bookingAktif = [];
  int _unreadNotif = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final svc = PelangganService.instance;

    final bookingRes = await svc.getBooking();
    final notifRes = await svc.getNotifikasi();

    if (mounted) {
      setState(() {
        _bookingAktif = bookingRes
            .where(
                (b) => !['selesai', 'dibatalkan', 'no_show'].contains(b.status))
            .take(3)
            .toList();
        _unreadNotif = notifRes['success'] == true
            ? (notifRes['data']?['unread_count'] ?? 0) as int
            : 0;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          slivers: [
            // ── App Bar ──────────────────────────────────
            SliverAppBar(
              expandedHeight: 130,
              pinned: true,
              backgroundColor: Colors.blue.shade700,
              actions: [
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined,
                          color: Colors.white),
                      onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const NotifikasiScreen()))
                          .then((_) => _loadData()),
                    ),
                    if (_unreadNotif > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                              color: Colors.red, shape: BoxShape.circle),
                          child: Text('$_unreadNotif',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 10)),
                        ),
                      ),
                  ],
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade800, Colors.blue.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 70, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Halo, ${widget.user.nama.split(' ').first}! 👋',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Selamat datang di Bengkel Ali Motor',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()))
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Shortcut Menu ─────────────
                          _buildShortcutMenu(context),
                          const SizedBox(height: 24),

                          // ── Booking Aktif ──────────────
                          if (_bookingAktif.isNotEmpty) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Booking Aktif',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                                TextButton(
                                  onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const StatusServisScreen())),
                                  child: const Text('Lihat semua'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ..._bookingAktif
                                .map((b) => _BookingCard(booking: b)),
                          ] else
                            _buildEmptyBooking(context),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Shortcut menu pakai Row biasa, bukan GridView ──────────
  // GridView di dalam Column tidak scrollable → overflow
  Widget _buildShortcutMenu(BuildContext context) {
    final items = [
      (
        Icons.calendar_today,
        'Booking\nServis',
        Colors.blue,
        () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const BookingScreen()))
      ),
      (
        Icons.build,
        'Status\nServis',
        Colors.orange,
        () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const StatusServisScreen()))
      ),
      (
        Icons.inventory_2,
        'Info\nSuku Cadang',
        Colors.teal,
        () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const SparepartScreen()))
      ),
      (
        Icons.history,
        'Riwayat\nServis',
        Colors.purple,
        () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const StatusServisScreen()))
      ),
    ];

    return Row(
      children: items.map((item) {
        return Expanded(
          child: GestureDetector(
            onTap: item.$4,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: item.$3.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(item.$1, color: item.$3, size: 26),
                ),
                const SizedBox(height: 6),
                Text(
                  item.$2,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, height: 1.3),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyBooking(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.calendar_today_outlined,
              size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text('Belum ada booking aktif',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Buat booking servis sekarang',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const BookingScreen())),
            icon: const Icon(Icons.add),
            label: const Text('Booking Sekarang'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final BookingModel booking;
  const _BookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.two_wheeler, color: Colors.blue.shade700),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${booking.merk} ${booking.model}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(booking.noPolisi,
                      style:
                          TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(FormatHelper.tanggal(booking.tanggalServis),
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            StatusBadge(status: booking.statusServis ?? booking.status),
          ],
        ),
      ),
    );
  }
}
