// lib/features/owner/screens/mutasi_stok_screen.dart

import 'package:flutter/material.dart';
import '../../../core/utils/currency_format.dart';
import '../services/owner_service.dart';

class MutasiStokScreen extends StatefulWidget {
  const MutasiStokScreen({super.key});

  @override
  State<MutasiStokScreen> createState() => _MutasiStokScreenState();
}

class _MutasiStokScreenState extends State<MutasiStokScreen> {
  DateTime _dari = DateTime.now().subtract(const Duration(days: 6));
  DateTime _sampai = DateTime.now();

  List<dynamic> _mutasi = [];
  Map<String, dynamic> _ringkasan = {};
  bool _loading = false;
  // Filter: 'semua' | 'masuk' | 'keluar_servis' | 'keluar_langsung'
  String _filter = 'semua';

  static const _bulan = [
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
    'Des',
  ];

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _label(DateTime d) => '${d.day} ${_bulan[d.month]} ${d.year}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        OwnerService.instance
            .getMutasiStok(dari: _fmt(_dari), sampai: _fmt(_sampai)),
        OwnerService.instance
            .getRingkasanMutasi(dari: _fmt(_dari), sampai: _fmt(_sampai)),
      ]);
      if (!mounted) return;
      final detail = results[0];
      final ringkasan = results[1];
      setState(() {
        _mutasi = detail['success'] == true
            ? (detail['data']?['mutasi'] as List? ?? [])
            : [];
        _ringkasan = ringkasan['success'] == true
            ? (ringkasan['data'] as Map<String, dynamic>? ?? {})
            : {};
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pilihPeriode() async {
    final range = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _dari, end: _sampai),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      helpText: 'Pilih Periode Mutasi Stok',
    );
    if (range == null) return;
    setState(() {
      _dari = range.start;
      _sampai = range.end;
    });
    _load();
  }

  List<dynamic> get _filtered {
    if (_filter == 'semua') return _mutasi;
    return _mutasi.where((m) => m['tipe'] == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final masuk = _ringkasan['masuk'] as Map<String, dynamic>? ?? {};
    final keluar = _ringkasan['keluar'] as Map<String, dynamic>? ?? {};

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Mutasi Stok'),
        backgroundColor: Colors.deepPurple.shade700,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          // ── Filter periode ────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.date_range, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  '${_label(_dari)} – ${_label(_sampai)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _pilihPeriode,
                  icon: const Icon(Icons.edit_calendar, size: 16),
                  label: const Text('Ubah', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.deepPurple.shade700,
                    side: BorderSide(color: Colors.deepPurple.shade700),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
              ],
            ),
          ),

          // ── Ringkasan masuk/keluar ────────────────────────
          if (!_loading && _ringkasan.isNotEmpty)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: _RingkasanCard(
                      label: 'Masuk',
                      qty: '${masuk['total_qty'] ?? 0} item',
                      nilai: formatRupiah(masuk['total_nilai'] ?? 0),
                      color: Colors.green.shade700,
                      icon: Icons.arrow_downward,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _RingkasanCard(
                      label: 'Keluar',
                      qty: '${keluar['total_qty'] ?? 0} item',
                      nilai: formatRupiah(keluar['total_nilai'] ?? 0),
                      color: Colors.red.shade600,
                      icon: Icons.arrow_upward,
                    ),
                  ),
                ],
              ),
            ),

          // ── Filter tipe ───────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('semua', 'Semua'),
                  _filterChip('masuk', 'Masuk'),
                  _filterChip('keluar_servis', 'Keluar Servis'),
                  _filterChip('keluar_langsung', 'Jual Langsung'),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // ── List mutasi ───────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2,
                                size: 56, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              _filter == 'semua'
                                  ? 'Tidak ada mutasi stok\npada periode ini'
                                  : 'Tidak ada data untuk filter ini',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) => _MutasiCard(
                              data: _filtered[i] as Map<String, dynamic>),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String key, String label) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label,
              style: TextStyle(
                  fontSize: 12, color: _filter == key ? Colors.white : null)),
          selected: _filter == key,
          selectedColor: Colors.deepPurple.shade700,
          onSelected: (_) => setState(() => _filter = key),
        ),
      );
}

// ── Ringkasan card ──────────────────────────────────────────
class _RingkasanCard extends StatelessWidget {
  final String label, qty, nilai;
  final Color color;
  final IconData icon;
  const _RingkasanCard({
    required this.label,
    required this.qty,
    required this.nilai,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.15),
            radius: 18,
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                Text(qty,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: color)),
                Text(nilai,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ]),
      );
}

// ── Mutasi card ─────────────────────────────────────────────
class _MutasiCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _MutasiCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final tipe = data['tipe'] as String? ?? '';
    final isMasuk = tipe == 'masuk';

    final Color tipeColor;
    final IconData tipeIcon;
    final String tipeLabel;

    switch (tipe) {
      case 'masuk':
        tipeColor = Colors.green.shade700;
        tipeIcon = Icons.arrow_downward;
        tipeLabel = 'MASUK';
        break;
      case 'keluar_servis':
        tipeColor = Colors.blue.shade700;
        tipeIcon = Icons.build;
        tipeLabel = 'KELUAR SERVIS';
        break;
      default:
        tipeColor = Colors.orange.shade700;
        tipeIcon = Icons.shopping_bag;
        tipeLabel = 'JUAL LANGSUNG';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tipe icon
            CircleAvatar(
              backgroundColor: tipeColor.withOpacity(0.1),
              radius: 20,
              child: Icon(tipeIcon, size: 18, color: tipeColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          data['nama_sparepart'] as String? ?? '-',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: tipeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(tipeLabel,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: tipeColor)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${data['kode'] ?? ''} · ${data['referensi'] ?? '-'}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                  Text(
                    data['keterangan'] as String? ?? '-',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.person_outline,
                        size: 12, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text(data['oleh'] as String? ?? '-',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade400)),
                    const Spacer(),
                    // Qty
                    Text(
                      '${isMasuk ? '+' : '-'}${data['qty']} ${data['satuan'] ?? ''}',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: tipeColor),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      formatRupiah(data['nilai'] ?? 0),
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
