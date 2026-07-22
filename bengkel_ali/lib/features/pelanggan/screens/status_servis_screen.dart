// lib/features/pelanggan/screens/status_servis_screen.dart

import 'package:flutter/material.dart';
import '../services/pelanggan_service.dart';
import '../../../core/utils/format_helper.dart';
import '../../../shared/widgets/status_badge.dart';

class StatusServisScreen extends StatefulWidget {
  const StatusServisScreen({super.key});
  @override
  State<StatusServisScreen> createState() => _StatusServisScreenState();
}

class _StatusServisScreenState extends State<StatusServisScreen> {
  List<Map<String, dynamic>> _list = [];
  bool _loading = true;

  static const _prioritasStatus = [
    'dikerjakan',
    'diagnosa', // <-- sebelumnya tidak ada di daftar ini, jadi indexOf()
    // mengembalikan -1 -> dianggap prioritas 999 (paling bawah, di bawah
    // 'selesai' sekalipun). Ini penyebab servis yang baru masuk diagnosa
    // selalu "hilang" ke bagian bawah list.
    'antrian',
    'menunggu_part',
    'selesai_servis',
    'selesai',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await PelangganService.instance.getStatusServis();
    if (!mounted) return;

    List<Map<String, dynamic>> raw = [];
    if (res['success'] == true) {
      final data = res['data'];
      if (data is List) {
        raw = List<Map<String, dynamic>>.from(data);
      }
    }

    raw.sort((a, b) {
      final ia = _prioritasStatus.indexOf(a['status'] as String? ?? '');
      final ib = _prioritasStatus.indexOf(b['status'] as String? ?? '');
      final priA = ia == -1 ? 999 : ia;
      final priB = ib == -1 ? 999 : ib;
      if (priA != priB) return priA.compareTo(priB);
      final tA = a['tanggal_servis'] as String? ?? '';
      final tB = b['tanggal_servis'] as String? ?? '';
      return tB.compareTo(tA);
    });

    setState(() {
      _list = raw;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Status Servis'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _list.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.build_outlined,
                                  size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text('Belum ada riwayat servis',
                                  style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 15)),
                              const SizedBox(height: 6),
                              Text(
                                'Tarik ke bawah untuk refresh',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade400),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      itemCount: _list.length,
                      itemBuilder: (_, i) {
                        final item = _list[i];
                        final isAktif = !['selesai']
                            .contains(item['status'] as String? ?? '');
                        // Tandai jika ada sparepart menunggu persetujuan
                        final adaMenunggu =
                            item['ada_menunggu_persetujuan'] == true ||
                                item['ada_menunggu_persetujuan'] == 1;

                        return _ServisCard(
                          data: item,
                          isAktif: isAktif,
                          adaMenungguPersetujuan: adaMenunggu,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DetailServisScreen(
                                  servisId: item['id'] as int,
                                ),
                              ),
                            );
                            _load();
                          },
                        );
                      },
                    ),
            ),
    );
  }
}

// ── Satu card servis di list ──────────────────────────────
class _ServisCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isAktif;
  final bool adaMenungguPersetujuan;
  final VoidCallback onTap;
  const _ServisCard({
    required this.data,
    required this.isAktif,
    required this.adaMenungguPersetujuan,
    required this.onTap,
  });

  Color _accentColor(String status) {
    switch (status) {
      case 'dikerjakan':
        return Colors.blue.shade600;
      case 'antrian':
        return Colors.orange.shade500;
      case 'menunggu_part':
        return Colors.purple.shade400;
      case 'selesai_servis':
        return Colors.teal.shade500;
      case 'selesai':
        return Colors.green.shade600;
      default:
        return Colors.grey.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = data['status'] as String? ?? '';
    final color = _accentColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      elevation: isAktif ? 3 : 1,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
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
                              data['no_booking'] as String? ?? '-',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          if (adaMenungguPersetujuan)
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: Colors.orange.shade300, width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.notification_important,
                                      size: 11, color: Colors.orange.shade700),
                                  const SizedBox(width: 3),
                                  Text('Perlu Keputusan',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.orange.shade700,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          StatusBadge(status: status),
                        ],
                      ),
                      const Divider(height: 14),
                      _Row(
                        icon: Icons.two_wheeler,
                        text:
                            '${data['merk']} ${data['model']} • ${data['no_polisi']}',
                      ),
                      const SizedBox(height: 5),
                      _Row(
                        icon: Icons.calendar_today,
                        text: FormatHelper.tanggal(
                            data['tanggal_servis'] as String? ?? ''),
                      ),
                      if (data['jenis_servis'] != null) ...[
                        const SizedBox(height: 5),
                        _Row(
                          icon: Icons.build,
                          text: data['jenis_servis'] as String,
                        ),
                      ],
                      if (data['mekanik'] != null) ...[
                        const SizedBox(height: 5),
                        _Row(
                          icon: Icons.person,
                          text: 'Mekanik: ${data['mekanik']}',
                          color: Colors.blue.shade700,
                        ),
                      ],
                      if (isAktif) ...[
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Lihat detail →',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w500),
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
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  const _Row({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 15, color: color ?? Colors.grey.shade500),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          text,
          style: TextStyle(fontSize: 13, color: color),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ]);
  }
}

// ── Detail Servis ─────────────────────────────────────────
class DetailServisScreen extends StatefulWidget {
  final int servisId;
  const DetailServisScreen({super.key, required this.servisId});
  @override
  State<DetailServisScreen> createState() => _DetailServisScreenState();
}

class _DetailServisScreenState extends State<DetailServisScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _submitting = false;

  // Pilihan sparepart pelanggan: 'request' | 'rekomendasi' | id sparepart lain
  // null = belum memilih
  String? _pilihanSumber; // 'request' | 'rekomendasi'
  final _catatanCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _catatanCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res =
        await PelangganService.instance.getStatusServis(id: widget.servisId);
    if (mounted) {
      setState(() {
        _data = res['success'] == true
            ? res['data'] as Map<String, dynamic>?
            : null;
        _loading = false;
        // Reset pilihan setiap refresh
        _pilihanSumber = null;
        _catatanCtrl.clear();
      });
    }
  }

  List<Map<String, dynamic>> get _sparepartList {
    if (_data == null) return [];
    final raw = _data!['sparepart'];
    if (raw is List) return List<Map<String, dynamic>>.from(raw);
    return [];
  }

  // Sparepart yang berstatus 'menunggu' persetujuan (tampil di panel keputusan)
  List<Map<String, dynamic>> get _sparepartMenunggu =>
      _sparepartList.where((p) {
        final sp = p['status_persetujuan'] as String? ?? '';
        return sp == 'menunggu';
      }).toList();

  // Apakah ada request dari pelanggan (sumber = 'request')
  Map<String, dynamic>? get _sparepartRequest {
    try {
      return _sparepartMenunggu.firstWhere((p) => p['sumber'] == 'request');
    } catch (_) {
      return null;
    }
  }

  // Apakah ada rekomendasi kasir (sumber = 'rekomendasi')
  Map<String, dynamic>? get _sparepartRekomendasi {
    try {
      return _sparepartMenunggu.firstWhere((p) => p['sumber'] == 'rekomendasi');
    } catch (_) {
      return null;
    }
  }

  bool get _adaMenungguPersetujuan => _sparepartMenunggu.isNotEmpty;

  Future<void> _submitKeputusan(String keputusan) async {
    // Validasi: jika setuju, harus memilih sparepart mana
    if (keputusan == 'setuju' && _pilihanSumber == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih sparepart terlebih dahulu'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Tentukan sparepart_dipilih_id berdasarkan pilihan sumber
    int? sparepartDipilihId;
    if (keputusan == 'setuju') {
      if (_pilihanSumber == 'request' && _sparepartRequest != null) {
        sparepartDipilihId = _sparepartRequest!['id'] as int?;
      } else if (_pilihanSumber == 'rekomendasi' &&
          _sparepartRekomendasi != null) {
        sparepartDipilihId = _sparepartRekomendasi!['id'] as int?;
      }
    }

    setState(() => _submitting = true);
    final res = await PelangganService.instance.responSparepart(
      servisId: widget.servisId,
      keputusan: keputusan,
      sparepartDipilihId: sparepartDipilihId,
      catatanPelanggan:
          _catatanCtrl.text.trim().isEmpty ? null : _catatanCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(keputusan == 'setuju'
              ? 'Sparepart disetujui, servis akan segera dilanjutkan'
              : 'Sparepart ditolak'),
          backgroundColor:
              keputusan == 'setuju' ? Colors.green : Colors.red.shade400,
        ),
      );
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(res['message'] as String? ?? 'Gagal mengirim keputusan'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Servis'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _data == null
              ? const Center(child: Text('Data tidak ditemukan'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _StatusProgress(
                            status:
                                _data!['servis']['status'] as String? ?? ''),
                        const SizedBox(height: 16),
                        _buildInfoCard(),
                        const SizedBox(height: 16),

                        // Panel persetujuan sparepart (muncul jika ada yang menunggu)
                        if (_adaMenungguPersetujuan) ...[
                          _buildSparepartPersetujuanCard(),
                          const SizedBox(height: 16),
                        ],

                        // Daftar sparepart yang sudah diputuskan
                        if (_sparepartList
                            .where((p) =>
                                (p['status_persetujuan'] as String? ?? '') !=
                                'menunggu')
                            .isNotEmpty)
                          _buildSparepartCard(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildInfoCard() {
    final s = _data!['servis'] as Map<String, dynamic>;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Informasi Servis',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Divider(height: 16),
            _rowInfo('No Booking', s['no_booking'] as String? ?? '-'),
            _rowInfo(
                'Kendaraan', '${s['merk']} ${s['model']} (${s['no_polisi']})'),
            _rowInfo('Jenis Servis', s['jenis_servis'] as String? ?? '-'),
            _rowInfo('Mekanik', s['mekanik'] as String? ?? 'Belum ditugaskan'),
            _rowInfo('Keluhan', s['keluhan'] as String? ?? '-'),
            if (s['diagnosa'] != null)
              _rowInfo('Diagnosa', s['diagnosa'] as String),
            if (s['waktu_mulai'] != null)
              _rowInfo('Mulai',
                  FormatHelper.tanggalWaktu(s['waktu_mulai'] as String)),
            if (s['waktu_selesai'] != null)
              _rowInfo('Selesai',
                  FormatHelper.tanggalWaktu(s['waktu_selesai'] as String)),
            if (_data!['estimasi_total'] != null) ...[
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Estimasi Total',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    FormatHelper.currency(
                        double.parse(_data!['estimasi_total'].toString())),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                        fontSize: 16),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Panel Persetujuan Sparepart ───────────────────────────
  Widget _buildSparepartPersetujuanCard() {
    final request = _sparepartRequest;
    final rekomendasi = _sparepartRekomendasi;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.orange.shade300, width: 1.5),
      ),
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.notification_important,
                    color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Keputusan Sparepart Diperlukan',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.orange.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Pilih sparepart yang ingin digunakan untuk servis kendaraan Anda.',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
            ),
            const Divider(height: 20),

            // Pilihan sparepart (request & rekomendasi)
            if (request != null) ...[
              _PilihanSparepartTile(
                label: 'Permintaan Saya',
                labelColor: Colors.blue.shade700,
                labelBg: Colors.blue.shade50,
                data: request,
                selected: _pilihanSumber == 'request',
                onTap: () => setState(() => _pilihanSumber = 'request'),
              ),
              const SizedBox(height: 10),
            ],

            if (rekomendasi != null) ...[
              _PilihanSparepartTile(
                label: 'Rekomendasi Kasir',
                labelColor: Colors.green.shade700,
                labelBg: Colors.green.shade50,
                data: rekomendasi,
                selected: _pilihanSumber == 'rekomendasi',
                onTap: () => setState(() => _pilihanSumber = 'rekomendasi'),
              ),
              const SizedBox(height: 10),
            ],

            // Info jika hanya ada satu pilihan
            if (request == null && rekomendasi != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Tidak ada permintaan sparepart dari Anda sebelumnya. Kasir merekomendasikan sparepart di atas.',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade600, height: 1.4),
                ),
              ),

            const Divider(height: 16),

            // Catatan dari pelanggan
            Text(
              'Catatan (opsional)',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.grey.shade700),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _catatanCtrl,
              maxLines: 2,
              maxLength: 200,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Tulis catatan atau pertanyaan untuk bengkel...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),

            const SizedBox(height: 12),

            // Tombol Tolak & Setujui
            _submitting
                ? const Center(child: CircularProgressIndicator())
                : Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _submitKeputusan('tolak'),
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Tolak'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade600,
                            side: BorderSide(color: Colors.red.shade300),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _pilihanSumber != null
                              ? () => _submitKeputusan('setuju')
                              : null,
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Setujui Pilihan'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey.shade300,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  // ── Daftar sparepart yang sudah diputuskan ────────────────
  Widget _buildSparepartCard() {
    final parts = _sparepartList
        .where((p) => (p['status_persetujuan'] as String? ?? '') != 'menunggu')
        .toList();
    if (parts.isEmpty) return const SizedBox.shrink();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Suku Cadang Digunakan',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Divider(height: 16),
            ...parts.map((p) {
              final status = p['status_persetujuan'] as String? ?? '';
              final isDitolak = status == 'ditolak';
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${p['nama']} (${p['jumlah']} ${p['satuan']})',
                            style: TextStyle(
                              fontSize: 13,
                              decoration:
                                  isDitolak ? TextDecoration.lineThrough : null,
                              color: isDitolak
                                  ? Colors.grey.shade400
                                  : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              _SumberChip(sumber: p['sumber'] as String? ?? ''),
                              const SizedBox(width: 6),
                              _StatusPersetujuanChip(status: status),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (!isDitolak)
                      Text(
                        FormatHelper.currency(
                            double.parse(p['subtotal'].toString())),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _rowInfo(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(label,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ),
            Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
          ],
        ),
      );
}

// ── Tile pilihan sparepart (request / rekomendasi) ────────
class _PilihanSparepartTile extends StatelessWidget {
  final String label;
  final Color labelColor;
  final Color labelBg;
  final Map<String, dynamic> data;
  final bool selected;
  final VoidCallback onTap;

  const _PilihanSparepartTile({
    required this.label,
    required this.labelColor,
    required this.labelBg,
    required this.data,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: selected ? Colors.blue.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.blue.shade500 : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Radio visual
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? Colors.blue.shade600 : Colors.grey.shade400,
                  width: 2,
                ),
                color: selected ? Colors.blue.shade600 : Colors.transparent,
              ),
              child: selected
                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Label sumber
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: labelBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(label,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: labelColor)),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    data['nama'] as String? ?? '-',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${data['jumlah']} ${data['satuan']}  •  ${FormatHelper.currency(double.parse((data['harga_jual'] ?? 0).toString()))}/unit',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  if (data['catatan'] != null &&
                      (data['catatan'] as String).isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Catatan: ${data['catatan']}',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  FormatHelper.currency(
                      double.parse((data['subtotal'] ?? 0).toString())),
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                      fontSize: 13),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Chip label sumber sparepart ───────────────────────────
class _SumberChip extends StatelessWidget {
  final String sumber;
  const _SumberChip({required this.sumber});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String text;
    switch (sumber) {
      case 'request':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade700;
        text = 'Permintaan';
        break;
      case 'rekomendasi':
        bg = Colors.green.shade50;
        fg = Colors.green.shade700;
        text = 'Rekomendasi';
        break;
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade600;
        text = 'Manual';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text,
          style:
              TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Chip status persetujuan ───────────────────────────────
class _StatusPersetujuanChip extends StatelessWidget {
  final String status;
  const _StatusPersetujuanChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String text;
    switch (status) {
      case 'disetujui':
        bg = Colors.green.shade50;
        fg = Colors.green.shade700;
        text = 'Disetujui';
        break;
      case 'ditolak':
        bg = Colors.red.shade50;
        fg = Colors.red.shade400;
        text = 'Ditolak';
        break;
      default:
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade700;
        text = 'Menunggu';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text,
          style:
              TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Progress bar status servis ────────────────────────────
class _StatusProgress extends StatelessWidget {
  final String status;
  const _StatusProgress({required this.status});

  static const _steps = [
    ('antrian', 'Antrian', Icons.queue),
    ('diagnosa', 'Diagnosa', Icons.search),
    ('menunggu_part', 'Tunggu Part', Icons.inventory),
    ('dikerjakan', 'Dikerjakan', Icons.build),
    ('selesai_servis', 'Selesai Servis', Icons.done),
    ('selesai', 'Lunas', Icons.check_circle),
  ];

  @override
  Widget build(BuildContext context) {
    // Normalisasi: 'mulai_diagnosa' dan 'selesai_diagnosa' sama-sama tampil di step diagnosa
    final displayStatus =
        (status == 'mulai_diagnosa' || status == 'selesai_diagnosa')
            ? 'diagnosa'
            : status;
    final idx = _steps.indexWhere((s) => s.$1 == displayStatus);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Progress Servis',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            Row(
              children: List.generate(_steps.length * 2 - 1, (i) {
                if (i.isOdd) {
                  final done = i ~/ 2 < idx;
                  return Expanded(
                    child: Divider(
                      thickness: 2,
                      color: done ? Colors.blue.shade700 : Colors.grey.shade300,
                    ),
                  );
                }
                final si = i ~/ 2;
                final done = si <= idx;
                final current = si == idx;
                return Column(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            done ? Colors.blue.shade700 : Colors.grey.shade200,
                        border: current
                            ? Border.all(color: Colors.blue.shade400, width: 2)
                            : null,
                      ),
                      child: Icon(
                        _steps[si].$3,
                        size: 16,
                        color: done ? Colors.white : Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _steps[si].$2,
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight:
                            current ? FontWeight.bold : FontWeight.normal,
                        color: done ? Colors.blue.shade700 : Colors.grey,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
