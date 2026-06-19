import 'dart:async';
import 'package:flutter/material.dart';
import '../services/kasir_service.dart';
import '../../../shared/widgets/status_badge.dart';

class KelolaPelangganScreen extends StatefulWidget {
  const KelolaPelangganScreen({super.key});
  @override
  State<KelolaPelangganScreen> createState() => _KelolaPelangganScreenState();
}

class _KelolaPelangganScreenState extends State<KelolaPelangganScreen> {
  final _searchCtrl = TextEditingController();
  bool _loading = false;
  String _search = '';
  Timer? _debounce;
  List<Map<String, dynamic>> _list = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Data Pelanggan'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ── Search bar ─────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Cari nama / no HP pelanggan...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {
                            _search = '';
                            _list = [];
                          });
                        })
                    : null,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) {
                setState(() => _search = v);
                _debounce?.cancel();
                debugPrint('[CARI] onChanged v="$v" len=${v.trim().length}');
                if (v.trim().length >= 2) {
                  _debounce = Timer(const Duration(milliseconds: 500), _cari);
                } else if (v.trim().isEmpty) {
                  setState(() => _list = []);
                }
              },
              onSubmitted: (_) {
                _debounce?.cancel();
                _cari();
              },
            ),
          ),

          // ── List ───────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _list.isEmpty
                    ? _buildEmpty()
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _list.length,
                        itemBuilder: (_, i) => _PelangganCard(
                          data: _list[i],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  DetailPelangganScreen(data: _list[i]),
                            ),
                          ).then((_) => _cari()),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _cari() async {
    debugPrint(
        '[CARI] keyword="${_search.trim()}" empty=${_search.trim().isEmpty}');
    if (_search.trim().isEmpty) return;
    setState(() => _loading = true);
    final res = await KasirService.instance.cariPelanggan(_search.trim());
    debugPrint(
        '[CARI] success=${res['success']} data_type=${res['data']?.runtimeType} data=${res['data']}');
    if (!mounted) return;
    setState(() {
      _list = res['success'] == true
          ? List<Map<String, dynamic>>.from(res['data'] as List? ?? [])
          : [];
      debugPrint('[CARI] _list.length=${_list.length}');
      _loading = false;
    });
  }

  Widget _buildEmpty() {
    if (_search.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('Cari pelanggan berdasarkan nama atau no HP',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_off, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('Pelanggan "$_search" tidak ditemukan',
              style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

class _PelangganCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  const _PelangganCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final diblokir = data['is_diblokir'] == 1 || data['is_diblokir'] == true;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor:
                    diblokir ? Colors.red.shade100 : Colors.indigo.shade100,
                child: Text(
                  (data['nama'] as String? ?? 'P')[0].toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color:
                        diblokir ? Colors.red.shade700 : Colors.indigo.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            data['nama'] as String? ?? '-',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                        if (diblokir)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.red.shade300),
                            ),
                            child: Text('Diblokir',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.red.shade700,
                                    fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(data['no_hp'] as String? ?? '-',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 13)),
                    const SizedBox(height: 3),
                    Text(
                      'No-show: ${data['total_noshow'] ?? 0}x',
                      style: TextStyle(
                          fontSize: 12,
                          color: (data['total_noshow'] ?? 0) > 2
                              ? Colors.red.shade600
                              : Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Detail Pelanggan ──────────────────────────────────────
class DetailPelangganScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  const DetailPelangganScreen({super.key, required this.data});
  @override
  State<DetailPelangganScreen> createState() => _DetailPelangganScreenState();
}

class _DetailPelangganScreenState extends State<DetailPelangganScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  final List<Map<String, dynamic>> _riwayatBooking = [];
  final List<Map<String, dynamic>> _riwayatPenalti = [];
  final List<Map<String, dynamic>> _kendaraan = [];
  bool _loadingDetail = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final id = widget.data['id'];
    if (id == null) return;
    setState(() => _loadingDetail = true);
    try {
      final res = await KasirService.instance.getRiwayatPelanggan(id as int);
      if (!mounted) return;
      if (res['success'] == true) {
        final d = res['data'] as Map<String, dynamic>? ?? {};
        setState(() {
          _kendaraan
            ..clear()
            ..addAll(
                List<Map<String, dynamic>>.from(d['kendaraan'] as List? ?? []));
          _riwayatBooking
            ..clear()
            ..addAll(List<Map<String, dynamic>>.from(
                d['riwayat_booking'] as List? ?? []));
          _riwayatPenalti
            ..clear()
            ..addAll(List<Map<String, dynamic>>.from(
                d['riwayat_penalti'] as List? ?? []));
        });
      }
    } finally {
      if (mounted) setState(() => _loadingDetail = false);
    }
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  bool get _diblokir =>
      widget.data['is_diblokir'] == 1 || widget.data['is_diblokir'] == true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.data['nama'] as String? ?? 'Pelanggan'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        actions: [
          if (_diblokir)
            TextButton.icon(
              onPressed: () => _showBukaBlokir(),
              icon: const Icon(Icons.lock_open, color: Colors.white, size: 18),
              label: const Text('Buka Blokir',
                  style: TextStyle(color: Colors.white)),
            )
          else
            TextButton.icon(
              onPressed: () => _showBlokirManual(),
              icon: const Icon(Icons.block, color: Colors.white, size: 18),
              label:
                  const Text('Blokir', style: TextStyle(color: Colors.white)),
            ),
        ],
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Profil'),
            Tab(text: 'Riwayat'),
            Tab(text: 'Penalti'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _tabProfil(),
          _tabRiwayat(),
          _tabPenalti(),
        ],
      ),
    );
  }

  // ── Tab Profil ────────────────────────────────────────
  Widget _tabProfil() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Status blokir
          if (_diblokir)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.block, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Text('Akun Diblokir',
                        style: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    widget.data['blokir_alasan'] as String? ??
                        'Tidak ada alasan',
                    style: TextStyle(color: Colors.red.shade600, fontSize: 13),
                  ),
                  if (widget.data['blokir_sampai'] != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Sampai: ${widget.data['blokir_sampai']}',
                      style:
                          TextStyle(color: Colors.red.shade500, fontSize: 12),
                    ),
                  ] else
                    Text('Status: PERMANEN',
                        style: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                ],
              ),
            ),

          // Data profil
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                _infoTile(Icons.person, 'Nama',
                    widget.data['nama'] as String? ?? '-'),
                _infoTile(Icons.phone, 'No HP',
                    widget.data['no_hp'] as String? ?? '-'),
                _infoTile(Icons.email, 'Email',
                    widget.data['email'] as String? ?? '-'),
                _infoTile(Icons.warning_amber, 'Total No-show',
                    '${widget.data['total_noshow'] ?? 0}x'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Kendaraan
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Kendaraan',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 8),
                  if (_loadingDetail)
                    const Center(
                        child: CircularProgressIndicator(strokeWidth: 2))
                  else if (_kendaraan.isEmpty)
                    Text('Tidak ada kendaraan terdaftar',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 13))
                  else
                    ..._kendaraan.map((k) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.two_wheeler),
                          title: Text('${k['merk']} ${k['model']}'),
                          subtitle: Text(k['no_polisi'] ?? ''),
                        )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab Riwayat Booking ───────────────────────────────
  Widget _tabRiwayat() {
    if (_loadingDetail) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_riwayatBooking.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('Belum ada riwayat booking',
                style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _riwayatBooking.length,
      itemBuilder: (_, i) {
        final b = _riwayatBooking[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            title: Text(b['no_booking'] as String? ?? '-'),
            subtitle: Text(b['tanggal_servis'] as String? ?? '-'),
            trailing: StatusBadge(status: b['status'] as String? ?? ''),
          ),
        );
      },
    );
  }

  // ── Tab Penalti No-show ───────────────────────────────
  Widget _tabPenalti() {
    if (_riwayatPenalti.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified_user, size: 56, color: Colors.green.shade200),
            const SizedBox(height: 12),
            const Text('Tidak ada riwayat penalti'),
            const SizedBox(height: 8),
            Text('Pelanggan ini belum pernah no-show',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _riwayatPenalti.length,
      itemBuilder: (_, i) {
        final p = _riwayatPenalti[i];
        final permanen = p['blokir_hari'] == null;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text('${p['noshow_ke']}',
                    style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.bold)),
              ),
            ),
            title: Text('No-show ke-${p['noshow_ke']}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p['booking']?['no_booking'] ?? '-'),
                Text(
                  permanen
                      ? 'Sanksi: Blokir PERMANEN'
                      : p['blokir_hari'] == 0
                          ? 'Sanksi: Peringatan (belum blokir)'
                          : 'Sanksi: Blokir ${p['blokir_hari']} hari',
                  style: TextStyle(
                      color: permanen || (p['blokir_hari'] ?? 0) > 0
                          ? Colors.red.shade600
                          : Colors.orange.shade600,
                      fontSize: 12),
                ),
              ],
            ),
            trailing: Text(
              (p['created_at'] as String? ?? '').substring(0, 10),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ),
        );
      },
    );
  }

  Widget _infoTile(IconData icon, String label, String value) => ListTile(
        dense: true,
        leading: Icon(icon, color: Colors.indigo.shade700, size: 20),
        title: Text(label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        subtitle: Text(value,
            style: const TextStyle(fontSize: 14, color: Colors.black87)),
      );

  void _showBukaBlokir() {
    final alasanCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Buka Blokir Akun?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Akun ${widget.data['nama']} akan dibuka blokirnya.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: alasanCtrl,
              decoration: const InputDecoration(
                labelText: 'Alasan (opsional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final pelangganId = widget.data['id'] as int? ??
                  int.tryParse(widget.data['id']?.toString() ?? '0') ??
                  0;
              final res = await KasirService.instance.blokirAksi(
                  pelangganId, 'buka_blokir',
                  alasan: 'Dibuka oleh kasir');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(res['message'] ?? 'Berhasil'),
                    backgroundColor:
                        res['success'] == true ? Colors.green : Colors.red));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Buka Blokir',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showBlokirManual() {
    final alasanCtrl = TextEditingController();
    int? hariBlokir = 3;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Blokir Akun?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Blokir akun ${widget.data['nama']}?',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                initialValue: hariBlokir,
                decoration: const InputDecoration(
                  labelText: 'Durasi Blokir',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 3, child: Text('3 Hari')),
                  DropdownMenuItem(value: 7, child: Text('7 Hari')),
                  DropdownMenuItem(value: 14, child: Text('14 Hari')),
                  DropdownMenuItem(value: 30, child: Text('30 Hari')),
                  DropdownMenuItem(value: null, child: Text('Permanen')),
                ],
                onChanged: (v) => setSt(() => hariBlokir = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: alasanCtrl,
                decoration: const InputDecoration(
                  labelText: 'Alasan',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                final pelangganId = widget.data['id'] as int? ??
                    int.tryParse(widget.data['id']?.toString() ?? '0') ??
                    0;
                final res = await KasirService.instance.blokirAksi(
                    pelangganId, 'blokir_manual',
                    hari: hariBlokir,
                    alasan: alasanCtrl.text.trim().isNotEmpty
                        ? alasanCtrl.text.trim()
                        : 'Diblokir oleh kasir');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(res['message'] ?? 'Berhasil'),
                      backgroundColor:
                          res['success'] == true ? Colors.red : Colors.orange));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child:
                  const Text('Blokir', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
