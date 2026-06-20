import 'package:flutter/material.dart';
import '../../../shared/widgets/status_badge.dart';
import '../models/kasir_models.dart';
import '../services/kasir_service.dart';
import 'kelola_pelanggan_screen.dart';
import 'servis_kasir_screen.dart';

class BookingKasirScreen extends StatefulWidget {
  const BookingKasirScreen({super.key});
  @override
  State<BookingKasirScreen> createState() => _BookingKasirScreenState();
}

class _BookingKasirScreenState extends State<BookingKasirScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  late ScrollController _stripCtrl;
  DateTime _tanggal = DateTime.now();
  bool _loading = false;
  List<KasirBookingModel> _booking = [];
  Map<String, int> _dots = {};
  int _kuotaHarian = 0;
  bool _loadingKuota = true;

  static const int _kStrip = 7; // jumlah hari di strip
  static const int _kCenter = 3; // index hari aktif (tengah)

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _stripCtrl = ScrollController();
    _load();
    _loadDots();
    _loadKuota();
  }

  Future<void> _loadDots() async {
    final dates = _stripDates;
    final dari = _fmtDate(dates.first);
    final sampai = _fmtDate(dates.last);
    final result = await KasirService.instance.getBookingSummary(dari, sampai);
    if (!mounted) return;
    setState(() => _dots = result);
  }

  Future<void> _loadKuota() async {
    setState(() => _loadingKuota = true);
    try {
      final res = await KasirService.instance.getPengaturan();
      if (!mounted) return;
      if (res['success'] == true && res['data'] != null) {
        setState(() {
          _kuotaHarian =
              int.tryParse(res['data']['kuota_booking_harian'].toString()) ?? 0;
          _loadingKuota = false;
        });
      } else {
        setState(() => _loadingKuota = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingKuota = false);
    }
  }

  @override
  void dispose() {
    _tab.dispose();
    _stripCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await KasirService.instance
          .getBookingList(tanggal: _fmtDate(_tanggal));
      if (!mounted) return;
      setState(() {
        final rawData = res['data'];
        final bookingList = rawData is Map ? rawData['booking'] : rawData;
        _booking = (res['success'] == true && bookingList is List)
            ? bookingList.map((e) => KasirBookingModel.fromJson(e)).toList()
            : [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _booking = [];
        _loading = false;
      });
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

  // 7 hari: 3 sebelum, aktif, 3 sesudah
  List<DateTime> get _stripDates => List.generate(
        _kStrip,
        (i) => DateTime(
          _tanggal.year,
          _tanggal.month,
          _tanggal.day + (i - _kCenter),
        ),
      );

  void _gantiTanggal(DateTime d) {
    setState(() => _tanggal = d);
    _load();
    _loadDots();
    if (_isSameDay(d, DateTime.now())) _loadKuota();
  }

  Future<void> _pilihTanggal() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tanggal,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _tanggal = picked);
      _load();
    }
  }

  List<KasirBookingModel> get _menunggu =>
      _booking.where((b) => b.status == 'menunggu').toList();
  List<KasirBookingModel> get _aktif => _booking
      .where((b) => ['dikonfirmasi', 'aktif'].contains(b.status))
      .toList();
  List<KasirBookingModel> get _selesai => _booking
      .where((b) => ['selesai', 'dibatalkan', 'no_show'].contains(b.status))
      .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: GestureDetector(
          onTap: _pilihTanggal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_today, size: 16),
              const SizedBox(width: 6),
              Text(_displayDate(_tanggal),
                  style: const TextStyle(fontSize: 15)),
              const Icon(Icons.arrow_drop_down, size: 20),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.people),
            tooltip: 'Data Pelanggan',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const KelolaPelangganScreen()),
            ),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(86),
          child: Column(
            children: [
              // ── Date strip ─────────────────────────────────
              SizedBox(
                height: 56,
                child: ListView.builder(
                  controller: _stripCtrl,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: _kStrip,
                  itemBuilder: (_, i) {
                    final d = _stripDates[i];
                    final isActive = i == _kCenter;
                    final isToday = _isSameDay(d, DateTime.now());
                    final dotCount = _dots[_fmtDate(d)] ?? 0;
                    return GestureDetector(
                      onTap: () => _gantiTanggal(d),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 44,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 3, vertical: 4),
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.white.withOpacity(0.25)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: isToday && !isActive
                              ? Border.all(color: Colors.white38, width: 0.5)
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _shortDay(d),
                              style: TextStyle(
                                fontSize: 10,
                                color: isActive ? Colors.white : Colors.white60,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${d.day}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isActive
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                dotCount.clamp(0, 3),
                                (_) => Container(
                                  width: 4,
                                  height: 4,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.85),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              // ── Tab bar ────────────────────────────────────
              TabBar(
                controller: _tab,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                indicatorColor: Colors.white,
                tabs: [
                  Tab(text: 'Menunggu (${_menunggu.length})'),
                  Tab(text: 'Aktif (${_aktif.length})'),
                  Tab(text: 'Selesai (${_selesai.length})'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Banner Kapasitas Booking Hari Ini ────────────
          if (_isSameDay(_tanggal, DateTime.now()))
            _KapasitasBanner(
              terisi: _booking
                  .where((b) => !['dibatalkan', 'no_show'].contains(b.status))
                  .length,
              kuota: _kuotaHarian,
              loading: _loadingKuota,
            ),
          // ── Tab Content ──────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tab,
                    children: [
                      _BookingTabContent(
                        list: _menunggu,
                        emptyMsg: 'Tidak ada booking menunggu',
                        onRefresh: _load,
                        onAksi: _showAksiDialog,
                      ),
                      _BookingTabContent(
                        list: _aktif,
                        emptyMsg: 'Tidak ada servis aktif',
                        onRefresh: _load,
                        onAksi: _showAksiDialog,
                      ),
                      _BookingTabContent(
                        list: _selesai,
                        emptyMsg: 'Belum ada yang selesai hari ini',
                        onRefresh: _load,
                        onAksi: _showAksiDialog,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  String _shortDay(DateTime d) {
    const n = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];
    return n[d.weekday % 7];
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _showAksiDialog(KasirBookingModel b) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AksiBookingSheet(
        booking: b,
        onAksi: (aksi) async {
          Navigator.pop(context);
          await _prosesAksi(b, aksi);
        },
      ),
    );
  }

  Future<void> _prosesAksi(KasirBookingModel b, String aksi) async {
    if (aksi == 'lihat_servis') {
      if (b.servisId != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetailServisScreen(servisId: b.servisId!),
          ),
        ).then((_) => _load());
      }
      return;
    }

    // Map aksi ke action API
    final actionMap = {
      'konfirmasi': 'konfirmasi',
      'aktifkan': 'aktifkan',
      'no_show': 'no_show',
    };
    final action = actionMap[aksi];
    if (action == null) return;

    // Konfirmasi no-show
    if (aksi == 'no_show') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Tandai No-Show?'),
          content: Text(
              'Pelanggan ${b.namaPelanggan} akan ditandai no-show dan menerima penalti.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('No-Show'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    final res = await KasirService.instance.updateStatusBooking(b.id, action);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          res['message'] ?? (res['success'] == true ? 'Berhasil' : 'Gagal')),
      backgroundColor: res['success'] == true ? Colors.green : Colors.red,
    ));
    if (res['success'] == true) _load();
  }
}

// ── Banner Kapasitas Booking Harian ──────────────────────
class _KapasitasBanner extends StatelessWidget {
  final int terisi;
  final int kuota;
  final bool loading;

  const _KapasitasBanner({
    required this.terisi,
    required this.kuota,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: const LinearProgressIndicator(),
      );
    }

    final sisa = (kuota - terisi).clamp(0, kuota);
    final persen = kuota > 0 ? (terisi / kuota).clamp(0.0, 1.0) : 0.0;
    final hampirPenuh = persen >= 0.8;
    final penuh = terisi >= kuota && kuota > 0;

    final Color warnaBanner = penuh
        ? Colors.red.shade50
        : hampirPenuh
            ? Colors.orange.shade50
            : Colors.green.shade50;
    final Color warnaBar = penuh
        ? Colors.red.shade600
        : hampirPenuh
            ? Colors.orange.shade600
            : Colors.green.shade600;
    final Color warnaText = penuh
        ? Colors.red.shade800
        : hampirPenuh
            ? Colors.orange.shade800
            : Colors.green.shade800;

    return Container(
      color: warnaBanner,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                penuh
                    ? Icons.block
                    : hampirPenuh
                        ? Icons.warning_amber_rounded
                        : Icons.event_available,
                size: 16,
                color: warnaText,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  penuh
                      ? 'Kapasitas hari ini PENUH ($terisi/$kuota slot)'
                      : 'Kapasitas hari ini: $terisi/$kuota slot · Sisa $sisa slot',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: warnaText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: persen,
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(warnaBar),
            ),
          ),
        ],
      ),
    );
  }
}

// ── List booking per tab ─────────────────────────────────
class _BookingTabContent extends StatelessWidget {
  final List<KasirBookingModel> list;
  final String emptyMsg;
  final Future<void> Function() onRefresh;
  final void Function(KasirBookingModel) onAksi;

  const _BookingTabContent({
    required this.list,
    required this.emptyMsg,
    required this.onRefresh,
    required this.onAksi,
  });

  @override
  Widget build(BuildContext context) {
    if (list.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.inbox_outlined, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(emptyMsg, style: TextStyle(color: Colors.grey.shade500)),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: list.length,
        itemBuilder: (_, i) =>
            _BookingKasirCard(booking: list[i], onTap: () => onAksi(list[i])),
      ),
    );
  }
}

// ── Card booking kasir ────────────────────────────────────
class _BookingKasirCard extends StatelessWidget {
  final KasirBookingModel booking;
  final VoidCallback onTap;
  const _BookingKasirCard({required this.booking, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(booking.noBooking,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo.shade700)),
              ),
              const SizedBox(width: 8),
              if (booking.tipe == 'walk_in')
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Walk-in',
                      style: TextStyle(
                          fontSize: 10, color: Colors.purple.shade700)),
                ),
              const Spacer(),
              StatusBadge(status: booking.status),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Icon(Icons.person, size: 16, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Text(booking.namaPelanggan,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(width: 8),
              Text(booking.noHp,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.two_wheeler, size: 16, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Text('${booking.merk} ${booking.model} • ${booking.noPolisi}',
                  style: const TextStyle(fontSize: 13)),
            ]),
            if (booking.slotLabel != null) ...[
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.schedule, size: 16, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Text(booking.slotLabel!,
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.indigo.shade700,
                        fontWeight: FontWeight.w500)),
              ]),
            ],
            if (booking.keluhan != null && booking.keluhan!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Text('💬 ${booking.keluhan}',
                    style:
                        TextStyle(fontSize: 12, color: Colors.amber.shade900)),
              ),
            ],
            if (booking.adaPartRequest) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.build_circle_outlined,
                        size: 13, color: Colors.orange.shade700),
                    const SizedBox(width: 4),
                    Text(
                      '${booking.partRequestMenunggu} sparepart request menunggu review',
                      style: TextStyle(
                          fontSize: 11, color: Colors.orange.shade800),
                    ),
                  ],
                ),
              ),
            ],
            if (booking.bisaDikonfirmasi || booking.bisaDiaktifkan) ...[
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                if (booking.bisaDikonfirmasi)
                  _AksiBtn('Konfirmasi', Colors.blue, onTap),
                if (booking.bisaDiaktifkan) ...[
                  _AksiBtn('Aktifkan', Colors.green, onTap),
                  const SizedBox(width: 8),
                  _AksiBtn('No-Show', Colors.red, onTap),
                ],
              ]),
            ],
          ]),
        ),
      ),
    );
  }
}

class _AksiBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _AksiBtn(this.label, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

// ── Bottom sheet aksi booking ─────────────────────────────
class _AksiBookingSheet extends StatelessWidget {
  final KasirBookingModel booking;
  final void Function(String) onAksi;
  const _AksiBookingSheet({required this.booking, required this.onAksi});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(booking.noBooking,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('${booking.namaPelanggan} • ${booking.merk} ${booking.model}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const Divider(height: 20),
            if (booking.bisaDikonfirmasi)
              _SheetBtn(Icons.check_circle, 'Konfirmasi Booking', Colors.blue,
                  () => onAksi('konfirmasi')),
            if (booking.bisaDiaktifkan)
              _SheetBtn(Icons.play_circle, 'Aktifkan (Motor Masuk)',
                  Colors.green, () => onAksi('aktifkan')),
            if (booking.bisaNoShow)
              _SheetBtn(Icons.cancel, 'Tandai No-Show', Colors.red,
                  () => onAksi('no_show')),
            if (booking.adaPartRequest)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    border: Border.all(color: Colors.orange.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.build_circle,
                          color: Colors.orange.shade700, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Pelanggan meminta ${booking.partRequestMenunggu} sparepart — '
                          'akan otomatis masuk ke servis saat booking diaktifkan.',
                          style: TextStyle(
                              fontSize: 12, color: Colors.orange.shade800),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (booking.adaServis)
              _SheetBtn(Icons.build, 'Lihat Detail Servis', Colors.orange,
                  () => onAksi('lihat_servis')),
            const SizedBox(height: 8),
          ]),
    );
  }
}

class _SheetBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SheetBtn(this.icon, this.label, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
            color: color.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(label,
          style: TextStyle(fontWeight: FontWeight.w500, color: color)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}
