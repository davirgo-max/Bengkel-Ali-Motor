import 'package:flutter/material.dart';
import '../../../core/utils/currency_format.dart';
import '../../../core/utils/format_helper.dart';
import '../services/owner_service.dart';

class LaporanScreen extends StatefulWidget {
  const LaporanScreen({super.key});
  @override
  State<LaporanScreen> createState() => _LaporanScreenState();
}

class _LaporanScreenState extends State<LaporanScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  String _periode = 'hari_ini';
  DateTime? _tglMulai;
  DateTime? _tglSelesai;

  // Data tiap tab
  Map<String, dynamic>? _dataServis;
  Map<String, dynamic>? _dataSparepart;
  Map<String, dynamic>? _dataKeuangan;

  bool _loadingServis = false;
  bool _loadingSparepart = false;
  bool _loadingKeuangan = false;

  // Filter khusus tab Servis (mekanik & jenis servis)
  int? _filterMekanikId;
  int? _filterJenisServisId;
  List<Map<String, dynamic>> _opsiMekanik = [];
  List<Map<String, dynamic>> _opsiJenisServis = [];

  final _periodeOptions = const {
    'hari_ini': 'Hari Ini',
    'minggu_ini': 'Minggu Ini',
    'bulan_ini': 'Bulan Ini',
    'custom': 'Pilih Tanggal',
  };

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this)
      ..addListener(() {
        if (!_tab.indexIsChanging) _loadTab(_tab.index);
      });
    _loadAll();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // ── Helpers tanggal ──────────────────────────────────────

  String _fmtParam(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtLabel(DateTime d) {
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

  Map<String, String?> get _paramTanggal {
    if (_periode == 'custom' && _tglMulai != null && _tglSelesai != null) {
      return {
        'tglMulai': _fmtParam(_tglMulai!),
        'tglSelesai': _fmtParam(_tglSelesai!),
      };
    }
    return {'tglMulai': null, 'tglSelesai': null};
  }

  // ── Load data ────────────────────────────────────────────

  void _loadAll() {
    _loadServis();
    _loadSparepart();
    _loadKeuangan();
  }

  void _loadTab(int idx) {
    if (idx == 0 && _dataServis == null) _loadServis();
    if (idx == 1 && _dataSparepart == null) _loadSparepart();
    if (idx == 2 && _dataKeuangan == null) _loadKeuangan();
  }

  Future<void> _loadServis() async {
    if (!mounted) return;
    setState(() => _loadingServis = true);
    final p = _paramTanggal;
    try {
      final res = await OwnerService.instance.getLaporanServis(
        periode: _periode,
        tglMulai: p['tglMulai'],
        tglSelesai: p['tglSelesai'],
        mekanikId: _filterMekanikId,
        jenisServisId: _filterJenisServisId,
      );
      if (mounted) {
        setState(() {
          _dataServis = res['success'] == true
              ? res['data'] as Map<String, dynamic>?
              : null;
          final opts = _dataServis?['filter_options'] as Map<String, dynamic>?;
          if (opts != null) {
            _opsiMekanik = (opts['mekanik'] as List<dynamic>? ?? [])
                .whereType<Map<String, dynamic>>()
                .toList();
            _opsiJenisServis = (opts['jenis_servis'] as List<dynamic>? ?? [])
                .whereType<Map<String, dynamic>>()
                .toList();
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _dataServis = null);
    } finally {
      if (mounted) setState(() => _loadingServis = false);
    }
  }

  void _onMekanikFilterChanged(int? mekanikId) {
    setState(() => _filterMekanikId = mekanikId);
    _loadServis();
  }

  void _onJenisServisFilterChanged(int? jenisServisId) {
    setState(() => _filterJenisServisId = jenisServisId);
    _loadServis();
  }

  Future<void> _loadSparepart() async {
    if (!mounted) return;
    setState(() => _loadingSparepart = true);
    final p = _paramTanggal;
    try {
      final res = await OwnerService.instance.getLaporanSparepart(
        periode: _periode,
        tglMulai: p['tglMulai'],
        tglSelesai: p['tglSelesai'],
      );
      if (mounted) {
        setState(() {
          _dataSparepart = res['success'] == true
              ? res['data'] as Map<String, dynamic>?
              : null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _dataSparepart = null);
    } finally {
      if (mounted) setState(() => _loadingSparepart = false);
    }
  }

  Future<void> _loadKeuangan() async {
    if (!mounted) return;
    setState(() => _loadingKeuangan = true);
    final p = _paramTanggal;
    try {
      final res = await OwnerService.instance.getLaporanKeuangan(
        periode: _periode,
        tglMulai: p['tglMulai'],
        tglSelesai: p['tglSelesai'],
      );
      if (mounted) {
        setState(() {
          _dataKeuangan = res['success'] == true
              ? res['data'] as Map<String, dynamic>?
              : null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _dataKeuangan = null);
    } finally {
      if (mounted) setState(() => _loadingKeuangan = false);
    }
  }

  void _onPeriodeChanged(String key) async {
    if (key == 'custom') {
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2025),
        lastDate: DateTime.now(),
        helpText: 'Pilih Rentang Tanggal',
      );
      if (range == null) return;
      setState(() {
        _periode = 'custom';
        _tglMulai = range.start;
        _tglSelesai = range.end;
        _dataServis = null;
        _dataSparepart = null;
        _dataKeuangan = null;
      });
    } else {
      setState(() {
        _periode = key;
        _dataServis = null;
        _dataSparepart = null;
        _dataKeuangan = null;
      });
    }
    _loadAll();
  }

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Laporan'),
        backgroundColor: Colors.deepPurple.shade700,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              setState(() {
                _dataServis = null;
                _dataSparepart = null;
                _dataKeuangan = null;
              });
              _loadAll();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Servis'),
            Tab(text: 'Sparepart'),
            Tab(text: 'Keuangan'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Filter periode ────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _periodeOptions.entries
                        .map((e) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(e.value,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: _periode == e.key
                                            ? Colors.white
                                            : null)),
                                selected: _periode == e.key,
                                selectedColor: Colors.deepPurple.shade700,
                                onSelected: (_) => _onPeriodeChanged(e.key),
                              ),
                            ))
                        .toList(),
                  ),
                ),
                if (_periode == 'custom' && _tglMulai != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${_fmtLabel(_tglMulai!)} s/d ${_fmtLabel(_tglSelesai!)}',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.deepPurple.shade700,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Konten laporan ────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _LaporanServisTab(
                  data: _dataServis,
                  loading: _loadingServis,
                  opsiMekanik: _opsiMekanik,
                  opsiJenisServis: _opsiJenisServis,
                  filterMekanikId: _filterMekanikId,
                  filterJenisServisId: _filterJenisServisId,
                  onMekanikChanged: _onMekanikFilterChanged,
                  onJenisServisChanged: _onJenisServisFilterChanged,
                ),
                _LaporanSparepartTab(
                    data: _dataSparepart, loading: _loadingSparepart),
                _LaporanKeuanganTab(
                    data: _dataKeuangan, loading: _loadingKeuangan),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Tab Servis
// ═══════════════════════════════════════════════════════════

class _LaporanServisTab extends StatelessWidget {
  final Map<String, dynamic>? data;
  final bool loading;
  final List<Map<String, dynamic>> opsiMekanik;
  final List<Map<String, dynamic>> opsiJenisServis;
  final int? filterMekanikId;
  final int? filterJenisServisId;
  final ValueChanged<int?> onMekanikChanged;
  final ValueChanged<int?> onJenisServisChanged;

  const _LaporanServisTab({
    required this.data,
    required this.loading,
    required this.opsiMekanik,
    required this.opsiJenisServis,
    required this.filterMekanikId,
    required this.filterJenisServisId,
    required this.onMekanikChanged,
    required this.onJenisServisChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (data == null) {
      return const _EmptyState(
          'Gagal memuat data.\nCek koneksi dan coba refresh.');
    }

    final r = data!['ringkasan'] as Map<String, dynamic>? ?? {};
    final detail = data!['detail'] as List<dynamic>? ?? [];
    final terlaris = data!['terlaris'] as List<dynamic>? ?? [];
    final perMekanik = data!['per_mekanik'] as List<dynamic>? ?? [];
    final adaFilter = filterMekanikId != null || filterJenisServisId != null;

    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Filter mekanik & jenis servis ────────────────
          Row(
            children: [
              Expanded(
                child: _FilterDropdown(
                  label: 'Semua Mekanik',
                  value: filterMekanikId,
                  items: opsiMekanik,
                  onChanged: onMekanikChanged,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FilterDropdown(
                  label: 'Semua Jenis',
                  value: filterJenisServisId,
                  items: opsiJenisServis,
                  onChanged: onJenisServisChanged,
                ),
              ),
            ],
          ),
          if (adaFilter)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    onMekanikChanged(null);
                    onJenisServisChanged(null);
                  },
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Hapus filter',
                      style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),

          // Ringkasan
          Row(children: [
            Expanded(
                child: _MiniCard('Total Servis', '${r['total_servis'] ?? 0}',
                    Colors.blue, Icons.build)),
            const SizedBox(width: 12),
            Expanded(
                child: _MiniCard('Selesai', '${r['selesai'] ?? 0}',
                    Colors.green, Icons.check_circle)),
            const SizedBox(width: 12),
            Expanded(
                child: _MiniCard('No-Show', '${r['no_show'] ?? 0}', Colors.red,
                    Icons.cancel)),
          ]),
          const SizedBox(height: 12),

          // Pendapatan jasa
          _InfoCard(
            icon: Icons.payments,
            color: Colors.green,
            label: 'Total Pendapatan Jasa',
            value: formatRupiah(r['total_pendapatan_jasa'] ?? 0),
          ),
          const SizedBox(height: 16),

          // ── Servis Terlaris ───────────────────────────────
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Servis Terlaris',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('Jenis servis paling banyak dikerjakan pada periode ini',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  const SizedBox(height: 12),
                  if (terlaris.isEmpty)
                    _emptyState('Belum ada servis selesai\npada periode ini')
                  else
                    ..._buildTerlaris(terlaris),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Performa per Mekanik ──────────────────────────
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Performa Mekanik',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),
                  if (perMekanik.isEmpty)
                    _emptyState('Belum ada servis selesai\npada periode ini')
                  else
                    ...perMekanik.map((item) {
                      final d = item as Map<String, dynamic>;
                      return _MekanikRow(d);
                    }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Tabel riwayat
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Riwayat Servis',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),
                  if (detail.isEmpty)
                    _emptyState('Tidak ada data servis\npada periode ini')
                  else
                    ...detail.map((item) {
                      final d = item as Map<String, dynamic>;
                      return _ServisRow(d);
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTerlaris(List<dynamic> terlaris) {
    final maxJumlah = terlaris
        .map((e) => (e as Map<String, dynamic>)['jumlah'] as int? ?? 0)
        .fold<int>(0, (a, b) => a > b ? a : b);
    return terlaris.map((item) {
      final d = item as Map<String, dynamic>;
      return _TerlarisRow(d, maxJumlah: maxJumlah == 0 ? 1 : maxJumlah);
    }).toList();
  }
}

class _FilterDropdown extends StatelessWidget {
  final String label;
  final int? value;
  final List<Map<String, dynamic>> items;
  final ValueChanged<int?> onChanged;

  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          isExpanded: true,
          value: value,
          isDense: true,
          icon: const Icon(Icons.expand_more, size: 18),
          style: const TextStyle(fontSize: 12, color: Colors.black87),
          hint: Text(label, style: const TextStyle(fontSize: 12)),
          items: [
            DropdownMenuItem<int?>(value: null, child: Text(label)),
            ...items.map((m) => DropdownMenuItem<int?>(
                  value: m['id'] as int,
                  child: Text(m['nama'] as String? ?? '-',
                      overflow: TextOverflow.ellipsis),
                )),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _TerlarisRow extends StatelessWidget {
  final Map<String, dynamic> d;
  final int maxJumlah;
  const _TerlarisRow(this.d, {required this.maxJumlah});

  @override
  Widget build(BuildContext context) {
    final jumlah = d['jumlah'] as int? ?? 0;
    final ratio = (jumlah / maxJumlah).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(d['nama'] as String? ?? '-',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              Text('$jumlah kali',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor:
                  AlwaysStoppedAnimation<Color>(Colors.deepPurple.shade400),
            ),
          ),
          const SizedBox(height: 2),
          Text(formatRupiah(d['total_jasa'] ?? 0),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

class _MekanikRow extends StatelessWidget {
  final Map<String, dynamic> d;
  const _MekanikRow(this.d);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.deepPurple.shade50,
                child: Icon(Icons.engineering,
                    size: 18, color: Colors.deepPurple.shade400),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(d['nama'] as String? ?? '-',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${d['jumlah_servis'] ?? 0} servis',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                  Text(formatRupiah(d['total_pendapatan'] ?? 0),
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

class _ServisRow extends StatelessWidget {
  final Map<String, dynamic> d;
  const _ServisRow(this.d);

  @override
  Widget build(BuildContext context) {
    final status = d['status'] as String? ?? '-';
    final statusColor = status == 'selesai'
        ? Colors.green
        : status == 'no_show'
            ? Colors.red
            : status == 'dibatalkan'
                ? Colors.grey
                : Colors.orange;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d['nama_pelanggan'] as String? ?? '-',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(
                      '${d['merk'] ?? ''} ${d['model'] ?? ''} • ${d['no_polisi'] ?? ''}',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${d['jenis_servis'] ?? '-'} • ${FormatHelper.tanggal(d['tanggal_servis'] as String? ?? '')}',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                    if ((d['nama_mekanik'] as String?) != null &&
                        d['nama_mekanik'] != '-')
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Icon(Icons.engineering,
                                size: 12, color: Colors.grey.shade400),
                            const SizedBox(width: 3),
                            Text(d['nama_mekanik'] as String,
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey.shade500)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(status,
                        style: TextStyle(
                            fontSize: 11,
                            color: statusColor,
                            fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 4),
                  Text(formatRupiah(d['total_biaya'] ?? 0),
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Tab Sparepart
// ═══════════════════════════════════════════════════════════

class _LaporanSparepartTab extends StatelessWidget {
  final Map<String, dynamic>? data;
  final bool loading;
  const _LaporanSparepartTab({required this.data, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (data == null) {
      return const _EmptyState(
          'Gagal memuat data.\nCek koneksi dan coba refresh.');
    }

    final r = data!['ringkasan'] as Map<String, dynamic>? ?? {};
    final detail = data!['detail'] as List<dynamic>? ?? [];
    final menipis = data!['stok_menipis'] as List<dynamic>? ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Ringkasan
        Row(children: [
          Expanded(
              child: _MiniCard('Terjual', '${r['total_terjual'] ?? 0} pcs',
                  Colors.teal, Icons.shopping_cart)),
          const SizedBox(width: 12),
          Expanded(
              child: _MiniCard(
                  'Pendapatan',
                  formatRupiah(r['total_pendapatan'] ?? 0),
                  Colors.green,
                  Icons.payments)),
          const SizedBox(width: 12),
          Expanded(
              child: _MiniCard('Item Habis', '${r['item_habis'] ?? 0}',
                  Colors.red, Icons.inventory_2)),
        ]),
        const SizedBox(height: 12),

        _InfoCard(
          icon: Icons.trending_up,
          color: Colors.blue,
          label: 'Laba Kotor Sparepart',
          value: formatRupiah(r['total_laba'] ?? 0),
        ),
        const SizedBox(height: 16),

        // Penjualan per item
        Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Penjualan Sparepart',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 12),
                if (detail.where((e) => (e['terjual'] ?? 0) > 0).isEmpty)
                  _emptyState('Tidak ada penjualan sparepart\npada periode ini')
                else
                  ...detail.where((e) => (e['terjual'] ?? 0) > 0).map((item) {
                    final d = item as Map<String, dynamic>;
                    return _SparepartRow(d);
                  }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Stok menipis
        Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.warning_amber,
                      color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 8),
                  const Text('Stok Menipis',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ]),
                const SizedBox(height: 12),
                if (menipis.isEmpty)
                  _emptyState('Semua stok aman')
                else
                  ...menipis.map((item) {
                    final d = item as Map<String, dynamic>;
                    return _StokMenipisRow(d);
                  }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SparepartRow extends StatelessWidget {
  final Map<String, dynamic> d;
  const _SparepartRow(this.d);

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d['nama'] as String? ?? '-',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(
                          '${d['kode'] ?? ''} • Terjual: ${d['terjual']} ${d['satuan'] ?? 'pcs'}',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(formatRupiah(d['pendapatan'] ?? 0),
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                    Text('Laba: ${formatRupiah(d['laba'] ?? 0)}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.green.shade600)),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
      );
}

class _StokMenipisRow extends StatelessWidget {
  final Map<String, dynamic> d;
  const _StokMenipisRow(this.d);

  @override
  Widget build(BuildContext context) {
    final stok = int.tryParse(d['stok'].toString()) ?? 0;
    final min = int.tryParse(d['stok_minimum'].toString()) ?? 0;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d['nama'] as String? ?? '-',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(d['kode'] as String? ?? '',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Stok: $stok ${d['satuan'] ?? 'pcs'}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: stok == 0 ? Colors.red : Colors.orange)),
                  Text('Min: $min',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Tab Keuangan
// ═══════════════════════════════════════════════════════════

class _LaporanKeuanganTab extends StatelessWidget {
  final Map<String, dynamic>? data;
  final bool loading;
  const _LaporanKeuanganTab({required this.data, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (data == null) {
      return const _EmptyState(
          'Gagal memuat data.\nCek koneksi dan coba refresh.');
    }

    final r = data!['ringkasan'] as Map<String, dynamic>? ?? {};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Ringkasan pemasukan
        Row(children: [
          Expanded(
              child: _MiniCard(
                  'Pemasukan',
                  formatRupiah(r['total_pemasukan'] ?? 0),
                  Colors.green,
                  Icons.arrow_upward)),
          const SizedBox(width: 12),
          Expanded(
              child: _MiniCard('Transaksi', '${r['jumlah_transaksi'] ?? 0}x',
                  Colors.blue, Icons.receipt_long)),
        ]),
        const SizedBox(height: 12),

        // Rekap rinci
        Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Rekap Keuangan',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const Divider(height: 20),
                _keuRow('Pendapatan Jasa Servis',
                    formatRupiah(r['pemasukan_jasa'] ?? 0)),
                _keuRow('Pendapatan Penjualan Sparepart',
                    formatRupiah(r['pemasukan_sparepart'] ?? 0)),
                _keuRow('Total Diskon Diberikan',
                    '- ${formatRupiah(r['total_diskon'] ?? 0)}',
                    valueColor: Colors.red),
                const Divider(height: 16),
                _keuRow('HPP Sparepart',
                    '- ${formatRupiah(r['hpp_sparepart'] ?? 0)}',
                    valueColor: Colors.red.shade700),
                const Divider(height: 16),
                _keuRow('Laba Kotor', formatRupiah(r['laba_kotor'] ?? 0),
                    bold: true, valueColor: Colors.green.shade700),
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 12),
                // Metode bayar
                Row(children: [
                  const Icon(Icons.money, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text('Cash: ${formatRupiah(r['cash'] ?? 0)}',
                      style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 16),
                  const Icon(Icons.account_balance,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text('Transfer: ${formatRupiah(r['transfer'] ?? 0)}',
                      style: const TextStyle(fontSize: 12)),
                ]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _keuRow(String label, String val,
          {bool bold = false, Color? valueColor}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
                child: Text(label,
                    style:
                        TextStyle(fontSize: 13, color: Colors.grey.shade600))),
            Text(val,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                    color: valueColor)),
          ],
        ),
      );
}

// ═══════════════════════════════════════════════════════════
// Shared widgets
// ═══════════════════════════════════════════════════════════

class _MiniCard extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _MiniCard(this.label, this.value, this.color, this.icon);

  @override
  Widget build(BuildContext context) => Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 6),
              Text(value,
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text(label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
        ),
      );
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _InfoCard(
      {required this.icon,
      required this.color,
      required this.label,
      required this.value});

  @override
  Widget build(BuildContext context) => Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                    Text(value,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: color)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  final String msg;
  const _EmptyState(this.msg);
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bar_chart, size: 56, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text(msg,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
            ],
          ),
        ),
      );
}

Widget _emptyState(String msg) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Column(children: [
          Icon(Icons.bar_chart, size: 40, color: Colors.grey.shade300),
          const SizedBox(height: 8),
          Text(msg,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
        ]),
      ),
    );
