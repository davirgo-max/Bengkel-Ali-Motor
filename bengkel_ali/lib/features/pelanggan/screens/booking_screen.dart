import 'package:flutter/material.dart';
import '../services/pelanggan_service.dart';
import '../models/pelanggan_models.dart';
import '../../../core/utils/format_helper.dart';
import '../../../shared/widgets/status_badge.dart';
import 'form_booking_screen.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});
  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<BookingModel> _aktif = [];
  List<BookingModel> _riwayat = [];
  bool _loading = true;

  // Status yang dianggap "aktif" (belum selesai/batal)
  static const _statusAktif = {
    'menunggu',
    'dikonfirmasi',
    'aktif',
  };

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final all = await PelangganService.instance.getBooking();
    if (!mounted) return;
    setState(() {
      _aktif = all.where((b) => _statusAktif.contains(b.status)).toList()
        ..sort((a, b) => a.tanggalServis.compareTo(b.tanggalServis));
      _riwayat = all.where((b) => !_statusAktif.contains(b.status)).toList()
        ..sort((a, b) => b.tanggalServis.compareTo(a.tanggalServis));
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Servis'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: 'Aktif (${_aktif.length})'),
            Tab(text: 'Riwayat (${_riwayat.length})'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FormBookingScreen()),
        ).then((_) => _load()),
        icon: const Icon(Icons.add),
        label: const Text('Booking Baru'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tab,
              children: [
                _BookingList(
                  list: _aktif,
                  emptyIcon: Icons.event_available,
                  emptyMsg: 'Tidak ada booking aktif',
                  onRefresh: _load,
                ),
                _BookingList(
                  list: _riwayat,
                  emptyIcon: Icons.history,
                  emptyMsg: 'Belum ada riwayat booking',
                  onRefresh: _load,
                ),
              ],
            ),
    );
  }
}

// ── List wrapper dengan pull-to-refresh ───────────────────
class _BookingList extends StatelessWidget {
  final List<BookingModel> list;
  final IconData emptyIcon;
  final String emptyMsg;
  final Future<void> Function() onRefresh;

  const _BookingList({
    required this.list,
    required this.emptyIcon,
    required this.emptyMsg,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (list.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.55,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(emptyIcon, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text(emptyMsg,
                      style:
                          TextStyle(color: Colors.grey.shade500, fontSize: 15)),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: list.length,
        itemBuilder: (_, i) =>
            _BookingTile(booking: list[i], onChanged: onRefresh),
      ),
    );
  }
}

// ── Tile satu booking ─────────────────────────────────────
class _BookingTile extends StatefulWidget {
  final BookingModel booking;
  final Future<void> Function() onChanged;
  const _BookingTile({required this.booking, required this.onChanged});

  @override
  State<_BookingTile> createState() => _BookingTileState();
}

class _BookingTileState extends State<_BookingTile> {
  Color _statusColor() {
    switch (widget.booking.status) {
      case 'menunggu':
        return Colors.orange.shade600;
      case 'dikonfirmasi':
        return Colors.blue.shade600;
      case 'aktif':
        return Colors.green.shade600;
      case 'selesai':
        return Colors.teal.shade600;
      case 'dibatalkan':
        return Colors.red.shade400;
      case 'no_show':
        return Colors.grey.shade500;
      default:
        return Colors.grey.shade400;
    }
  }

  Future<void> _batal(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Batalkan Booking?'),
        content: Text('Booking ${widget.booking.noBooking} akan dibatalkan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Tidak')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Ya, Batalkan',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final res = await PelangganService.instance.batalBooking(widget.booking.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['message'] as String? ?? ''),
        backgroundColor: res['success'] == true ? Colors.green : Colors.red,
      ));
      if (res['success'] == true) widget.onChanged();
    }
  }

  bool _expanded = false;
  bool _loadingPart = false;
  List<BookingSparepartRequestModel> _partList = [];
  bool _partLoaded = false;

  Future<void> _loadSparepart() async {
    if (_partLoaded) return;
    setState(() => _loadingPart = true);
    final res =
        await PelangganService.instance.getBookingDetail(widget.booking.id);
    if (!mounted) return;
    final rawPart = res['data']?['sparepart_request'];
    if (rawPart is List) {
      _partList =
          rawPart.map((e) => BookingSparepartRequestModel.fromJson(e)).toList();
    }
    setState(() {
      _loadingPart = false;
      _partLoaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final bisaBatal = ['menunggu', 'dikonfirmasi'].contains(booking.status);
    final color = _statusColor();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              children: [
                Container(width: 5, color: color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                booking.noBooking,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                            StatusBadge(status: booking.status),
                          ],
                        ),
                        const Divider(height: 14),

                        _InfoRow(
                          icon: Icons.two_wheeler,
                          text:
                              '${booking.merk} ${booking.model} \u2022 ${booking.noPolisi}',
                        ),

                        const SizedBox(height: 5),
                        _InfoRow(
                          icon: Icons.calendar_today,
                          text: FormatHelper.tanggal(booking.tanggalServis),
                        ),

                        if (booking.jenisServis != null) ...[
                          const SizedBox(height: 5),
                          _InfoRow(
                            icon: Icons.build,
                            text: booking.jenisServis!,
                          ),
                        ],

                        if (booking.statusServis != null &&
                            booking.status == 'aktif') ...[
                          const SizedBox(height: 5),
                          _InfoRow(
                            icon: Icons.settings,
                            text:
                                'Servis: ${_labelServis(booking.statusServis!)}',
                            color: Colors.green.shade700,
                          ),
                        ],

                        if (booking.catatanKasir != null &&
                            booking.catatanKasir!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.info_outline,
                                    size: 14, color: Colors.orange.shade700),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    booking.catatanKasir!,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange.shade800),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Tombol toggle sparepart request
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () async {
                            final willExpand = !_expanded;
                            setState(() => _expanded = willExpand);
                            if (willExpand) await _loadSparepart();
                          },
                          child: Row(
                            children: [
                              Icon(Icons.build_circle_outlined,
                                  size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                _expanded
                                    ? 'Sembunyikan sparepart'
                                    : 'Lihat sparepart request',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                    decoration: TextDecoration.underline),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                _expanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                size: 14,
                                color: Colors.grey.shade600,
                              ),
                            ],
                          ),
                        ),

                        // Panel sparepart request
                        if (_expanded) ...[
                          const SizedBox(height: 8),
                          if (_loadingPart)
                            const Center(
                                child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2)))
                          else if (_partList.isEmpty)
                            Text(
                              'Tidak ada sparepart yang diminta saat booking.',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade500),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                border: Border.all(color: Colors.grey.shade200),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Sparepart Request',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey.shade700)),
                                  const SizedBox(height: 6),
                                  ..._partList.map((p) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 6),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(p.namaPart,
                                                      style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w500)),
                                                  Text(
                                                    '${p.jumlah} ${p.satuan} \u2022 Rp ${p.hargaJual.toStringAsFixed(0)}',
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors
                                                            .grey.shade600),
                                                  ),
                                                  if (p.catatan != null &&
                                                      p.catatan!.isNotEmpty)
                                                    Text(
                                                      'Catatan: ${p.catatan}',
                                                      style: TextStyle(
                                                          fontSize: 11,
                                                          fontStyle:
                                                              FontStyle.italic,
                                                          color: Colors
                                                              .blue.shade700),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            _SparepartStatusBadge(p.status),
                                          ],
                                        ),
                                      )),
                                ],
                              ),
                            ),
                        ],

                        // Tombol batal
                        if (bisaBatal) ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              onPressed: () => _batal(context),
                              icon: const Icon(Icons.cancel_outlined, size: 16),
                              label: const Text('Batalkan'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _labelServis(String s) {
    switch (s) {
      case 'antrian':
        return 'Dalam Antrian';
      case 'dikerjakan':
        return 'Sedang Dikerjakan';
      case 'menunggu_part':
        return 'Menunggu Part';
      case 'selesai_servis':
        return 'Selesai Servis';
      case 'selesai':
        return 'Lunas';
      default:
        return s;
    }
  }
}

class _SparepartStatusBadge extends StatelessWidget {
  final String status;
  const _SparepartStatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;
    switch (status) {
      case 'disetujui':
        bg = Colors.green.shade100;
        fg = Colors.green.shade800;
        label = 'Disetujui';
        break;
      case 'ditolak':
        bg = Colors.red.shade100;
        fg = Colors.red.shade800;
        label = 'Ditolak';
        break;
      case 'diganti':
        bg = Colors.blue.shade100;
        fg = Colors.blue.shade800;
        label = 'Diganti';
        break;
      default:
        bg = Colors.orange.shade100;
        fg = Colors.orange.shade800;
        label = 'Menunggu';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label,
          style:
              TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  const _InfoRow({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.grey.shade600;
    return Row(children: [
      Icon(icon, size: 15, color: c),
      const SizedBox(width: 6),
      Expanded(
        child: Text(text,
            style: TextStyle(fontSize: 13, color: color),
            overflow: TextOverflow.ellipsis),
      ),
    ]);
  }
}
