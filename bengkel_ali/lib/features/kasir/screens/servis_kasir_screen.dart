import 'package:flutter/material.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../core/utils/format_helper.dart';
import '../models/kasir_models.dart';
import '../services/kasir_service.dart';
import 'form_walkin_screen.dart';

class ServisKasirScreen extends StatefulWidget {
  const ServisKasirScreen({super.key});
  @override
  State<ServisKasirScreen> createState() => _ServisKasirScreenState();
}

class _ServisKasirScreenState extends State<ServisKasirScreen> {
  bool _loading = false;
  String _errorMsg = '';
  List<KasirServisModel> _list = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMsg = '';
    });
    try {
      final list = await KasirService.instance.getServisList();
      if (!mounted) return;
      setState(() {
        _list = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _list = [];
        _errorMsg = 'Gagal memuat data: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Kelola Servis'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FormWalkInScreen()),
        ).then((_) => _load()),
        icon: const Icon(Icons.directions_walk),
        label: const Text('Walk-in Baru'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMsg.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off,
                          size: 56, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(_errorMsg,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Coba Lagi'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo.shade700,
                            foregroundColor: Colors.white),
                      ),
                    ],
                  ),
                )
              : _list.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.build_outlined,
                              size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text('Tidak ada servis aktif hari ini',
                              style: TextStyle(color: Colors.grey.shade500)),
                          const SizedBox(height: 8),
                          Text('Aktifkan booking atau tambah walk-in baru',
                              style: TextStyle(
                                  color: Colors.grey.shade400, fontSize: 13)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _list.length,
                        itemBuilder: (_, i) => _ServisCard(
                          servis: _list[i],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  DetailServisScreen(servisId: _list[i].id),
                            ),
                          ).then((_) => _load()),
                        ),
                      ),
                    ),
    );
  }
}

class _ServisCard extends StatelessWidget {
  final KasirServisModel servis;
  final VoidCallback onTap;
  const _ServisCard({required this.servis, required this.onTap});

  Color get _statusColor {
    return switch (servis.status) {
      'antrian' => Colors.orange.shade600,
      'diagnosa' => Colors.blue.shade600, // ← tambah ini
      'dikerjakan' => Colors.indigo.shade600,
      'menunggu_part' => Colors.purple.shade500,
      'selesai_servis' => Colors.teal.shade600,
      _ => Colors.grey.shade500,
    };
  }

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(servis.noBooking,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo.shade700)),
                  const Spacer(),
                  StatusBadge(status: servis.status),
                ],
              ),
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.person, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text(servis.namaPelanggan,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.two_wheeler, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text('${servis.merk} ${servis.model} • ${servis.noPolisi}',
                    style: const TextStyle(fontSize: 13)),
              ]),
              if (servis.namaMekanik != null) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.engineering, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(servis.namaMekanik!,
                      style: TextStyle(
                          fontSize: 13, color: Colors.indigo.shade600)),
                ]),
              ],
              if (servis.waktuMulai != null) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.timer, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                      'Mulai: ${servis.waktuMulai!.length >= 16 ? servis.waktuMulai!.substring(11, 16) : servis.waktuMulai!}',
                      style: const TextStyle(fontSize: 13)),
                ]),
              ],
              const SizedBox(height: 10),
              _StatusStepper(status: servis.status),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusStepper extends StatelessWidget {
  final String status;
  const _StatusStepper({required this.status});

  static const _steps = [
    'antrian',
    'diagnosa',
    'menunggu_part',
    'dikerjakan',
    'selesai_servis',
  ];
  static const _labels = [
    'Antrian',
    'Diagnosa',
    'Tunggu\nPart',
    'Kerjakan',
    'Selesai'
  ];

  @override
  Widget build(BuildContext context) {
    final idx = _steps.indexOf(status);
    return Row(
      children: List.generate(_steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final done = i ~/ 2 < idx;
          return Expanded(
              child: Container(
            height: 2,
            color: done ? Colors.indigo.shade400 : Colors.grey.shade200,
          ));
        }
        final si = i ~/ 2;
        final done = si <= idx;
        final cur = si == idx;
        return Column(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? Colors.indigo.shade600 : Colors.grey.shade200,
                border: cur
                    ? Border.all(color: Colors.indigo.shade300, width: 2)
                    : null,
              ),
              child: done
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            const SizedBox(height: 2),
            Text(_labels[si],
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 9,
                    color: done ? Colors.indigo.shade600 : Colors.grey,
                    fontWeight: cur ? FontWeight.bold : FontWeight.normal)),
          ],
        );
      }),
    );
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
  DetailServisModel? _data;
  bool _loading = true;
  String? _error;

  // Form diagnosa & mekanik
  final _diagnosaCtrl = TextEditingController();
  int? _selectedMekanikId;
  bool _savingInfo = false;

  // Status update
  bool _updatingStatus = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _diagnosaCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await KasirService.instance.getServisDetail(widget.servisId);
    if (!mounted) return;
    if (res['success'] == true) {
      final data =
          DetailServisModel.fromJson(res['data'] as Map<String, dynamic>);
      setState(() {
        _data = data;
        _diagnosaCtrl.text = (data.servis['diagnosa'] as String?) ?? '';
        _selectedMekanikId = data.servis['mekanik_id'] != null
            ? int.tryParse(data.servis['mekanik_id'].toString())
            : null;
        _loading = false;
      });
    } else {
      setState(() {
        _error = res['message'] as String? ?? 'Gagal memuat data servis';
        _loading = false;
      });
    }
  }

  Future<void> _updateStatus(String status) async {
    setState(() => _updatingStatus = true);
    final res =
        await KasirService.instance.updateStatusServis(widget.servisId, status);
    if (!mounted) return;
    setState(() => _updatingStatus = false);
    final ok = res['success'] == true;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res['message'] ?? (ok ? 'Status diperbarui' : 'Gagal')),
      backgroundColor: ok ? Colors.green : Colors.red,
    ));
    if (ok) _load();
  }

  Future<void> _simpanInfo() async {
    setState(() => _savingInfo = true);
    final res = await KasirService.instance.updateInfoServis(
      widget.servisId,
      diagnosa: _diagnosaCtrl.text.trim(),
      mekanikId: _selectedMekanikId,
    );
    if (!mounted) return;
    setState(() => _savingInfo = false);
    final ok = res['success'] == true;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res['message'] ?? (ok ? 'Diagnosa disimpan' : 'Gagal')),
      backgroundColor: ok ? Colors.green : Colors.red,
    ));
    if (ok) _load();
  }

  Future<void> _dialogSelesaiDiagnosa() async {
    if (_diagnosaCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Isi diagnosa terlebih dahulu'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    await _simpanInfo();
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        // ← deklarasi di sini, dalam scope builder
        bool importRequest = false;
        String lanjutKe = 'dikerjakan';

        return StatefulBuilder(
          builder: (ctx, setDlg) => AlertDialog(
            title: const Text('Tentukan Sparepart'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: importRequest,
                  onChanged: (v) => setDlg(() => importRequest = v),
                  title: const Text('Pakai request sparepart pelanggan',
                      style: TextStyle(fontSize: 14)),
                  subtitle: const Text(
                      'Sparepart yang dipilih pelanggan saat booking akan masuk ke servis',
                      style: TextStyle(fontSize: 12)),
                ),
                const Divider(),
                const Text('Lanjut ke:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  value: 'dikerjakan',
                  groupValue: lanjutKe,
                  onChanged: (v) => setDlg(() => lanjutKe = v!),
                  title: const Text('Langsung Dikerjakan',
                      style: TextStyle(fontSize: 14)),
                  subtitle: const Text('Tidak perlu persetujuan pelanggan',
                      style: TextStyle(fontSize: 12)),
                ),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  value: 'menunggu_part',
                  groupValue: lanjutKe,
                  onChanged: (v) => setDlg(() => lanjutKe = v!),
                  title: const Text('Tunggu Persetujuan Pelanggan',
                      style: TextStyle(fontSize: 14)),
                  subtitle: const Text(
                      'Pelanggan akan diminta menyetujui sparepart rekomendasi',
                      style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  setState(() => _updatingStatus = true);
                  final res = await KasirService.instance.selesaiDiagnosa(
                    servisId: widget.servisId,
                    importRequest: importRequest,
                    lanjutKe: lanjutKe,
                  );
                  if (!mounted) return;
                  setState(() => _updatingStatus = false);
                  final ok = res['success'] == true;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content:
                        Text(res['message'] ?? (ok ? 'Berhasil' : 'Gagal')),
                    backgroundColor: ok ? Colors.green : Colors.red,
                  ));
                  if (ok) _load();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo.shade700,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Konfirmasi'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _hapusSparepart(int partId) async {
    final res = await KasirService.instance.hapusSparepart(partId);
    if (!mounted) return;
    final ok = res['success'] == true;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res['message'] ?? (ok ? 'Sparepart dihapus' : 'Gagal')),
      backgroundColor: ok ? Colors.orange : Colors.red,
    ));
    if (ok) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_data != null
            ? (_data!.servis['no_booking'] as String? ?? 'Detail Servis')
            : 'Detail Servis'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off,
                          size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(_error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Coba Lagi'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo.shade700,
                            foregroundColor: Colors.white),
                      ),
                    ],
                  ),
                )
              : _buildDetail(),
    );
  }

  Widget _buildDetail() {
    final d = _data!;
    final servis = d.servis;
    final status = servis['status'] as String? ?? '';
    final sudahSelesai = status == 'selesai_servis' || status == 'selesai';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ── Info Pelanggan & Kendaraan ──────────────────
          _SectionCard(
            title: 'Informasi',
            child: Column(
              children: [
                _infoRow(Icons.person, 'Pelanggan',
                    servis['nama_pelanggan'] as String? ?? '-'),
                _infoRow(
                    Icons.phone, 'No HP', servis['no_hp'] as String? ?? '-'),
                _infoRow(Icons.two_wheeler, 'Kendaraan',
                    '${servis['merk']} ${servis['model']} • ${servis['no_polisi']}'),
                if (servis['keluhan'] != null)
                  _infoRow(Icons.report_problem, 'Keluhan',
                      servis['keluhan'] as String),
                if (servis['jenis_servis'] != null)
                  _infoRow(Icons.build, 'Jenis Servis',
                      servis['jenis_servis'] as String),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Update Status ───────────────────────────────
          if (!sudahSelesai)
            _SectionCard(
              title: 'Update Status',
              child: _updatingStatus
                  ? const Center(
                      child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator()))
                  : Column(
                      children: [
                        if (status == 'antrian')
                          _statusBtn('Mulai Diagnosa', Icons.search,
                              Colors.blue, () => _updateStatus('diagnosa')),
                        if (status == 'diagnosa') ...[
                          // Simpan diagnosa dulu sebelum bisa lanjut
                          _infoRow(Icons.info_outline, 'Info',
                              'Isi diagnosa & pilih mekanik, lalu tentukan penggunaan sparepart.'),
                          const SizedBox(height: 8),
                          _statusBtn(
                              'Selesai Diagnosa & Tentukan Sparepart',
                              Icons.checklist,
                              Colors.indigo,
                              _dialogSelesaiDiagnosa),
                        ],
                        if (status == 'menunggu_part')
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.purple.shade200),
                            ),
                            child: Row(children: [
                              Icon(Icons.hourglass_top,
                                  color: Colors.purple.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Menunggu persetujuan sparepart dari pelanggan...',
                                  style:
                                      TextStyle(color: Colors.purple.shade700),
                                ),
                              ),
                            ]),
                          ),
                        if (status == 'dikerjakan') ...[
                          _statusBtn(
                              'Servis Selesai',
                              Icons.done_all,
                              Colors.teal,
                              () => _updateStatus('selesai_servis')),
                        ],
                        if (status == 'selesai_servis')
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(children: [
                              Icon(Icons.check_circle,
                                  color: Colors.teal.shade700),
                              const SizedBox(width: 8),
                              Text('Servis selesai — siap diproses pembayaran',
                                  style:
                                      TextStyle(color: Colors.teal.shade700)),
                            ]),
                          ),
                      ],
                    ),
            ),
          if (!sudahSelesai) const SizedBox(height: 12),

          // ── Diagnosa & Mekanik ──────────────────────────
          _SectionCard(
            title: 'Diagnosa & Mekanik',
            child: Column(
              children: [
                TextFormField(
                  controller: _diagnosaCtrl,
                  maxLines: 3,
                  enabled: !sudahSelesai,
                  decoration: InputDecoration(
                    hintText: 'Isi hasil diagnosa kendaraan...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int?>(
                  initialValue: _selectedMekanikId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Assign Mekanik',
                    prefixIcon: const Icon(Icons.engineering),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                        value: null, child: Text('-- Pilih Mekanik --')),
                    ...d.mekanikList.map((m) => DropdownMenuItem<int?>(
                        value: m.id, child: Text(m.nama))),
                  ],
                  onChanged: sudahSelesai
                      ? null
                      : (v) => setState(() => _selectedMekanikId = v),
                ),
                if (!sudahSelesai) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _savingInfo ? null : _simpanInfo,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _savingInfo
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text('Simpan Diagnosa'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Sparepart ───────────────────────────────────
          _SectionCard(
            title: 'Sparepart Digunakan',
            trailing: sudahSelesai
                ? null
                : IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.indigo),
                    onPressed: () => _showTambahSparepart(),
                  ),
            child: d.sparepart.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text('Belum ada sparepart ditambahkan',
                          style: TextStyle(color: Colors.grey.shade500)),
                    ),
                  )
                : Column(
                    children: d.sparepart
                        .map((sp) => _SparepartTile(
                              sp: sp,
                              onHapus: sudahSelesai
                                  ? null
                                  : () => _hapusSparepart(sp.id),
                            ))
                        .toList(),
                  ),
          ),
          const SizedBox(height: 12),

          // ── Estimasi Biaya ──────────────────────────────
          _SectionCard(
            title: 'Estimasi Biaya',
            child: Column(
              children: [
                _totalRow('Biaya Jasa', FormatHelper.currency(d.totalJasa)),
                _totalRow('Biaya Part', FormatHelper.currency(d.totalPart)),
                const Divider(),
                _totalRow('Total', FormatHelper.currency(d.grandTotal),
                    bold: true),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Tombol Proses Bayar ─────────────────────────
          if (status == 'selesai_servis')
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProsesBayarScreen(
                      servisId: widget.servisId,
                      grandTotal: d.grandTotal,
                      noBooking: servis['no_booking'] as String? ?? '',
                    ),
                  ),
                ).then((_) => _load()),
                icon: const Icon(Icons.payment),
                label: const Text('Proses Pembayaran',
                    style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          if (status == 'selesai')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(children: [
                Icon(Icons.check_circle, color: Colors.green.shade700),
                const SizedBox(width: 10),
                Text('Pembayaran sudah selesai',
                    style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold)),
              ]),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade500),
            const SizedBox(width: 8),
            SizedBox(
                width: 80,
                child: Text(label,
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600))),
            Expanded(
                child: Text(value,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500))),
          ],
        ),
      );

  Widget _statusBtn(
      String label, IconData icon, Color color, VoidCallback onTap) {
    // Label konfirmasi per status
    final konfirmasiMap = {
      'Mulai Dikerjakan': 'Tandai servis ini mulai dikerjakan?',
      'Menunggu Sparepart': 'Tandai servis ini menunggu sparepart?',
      'Servis Selesai':
          'Tandai servis ini sudah selesai dikerjakan?\nPastikan semua pekerjaan sudah tuntas.',
      'Lanjut Kerjakan': 'Lanjutkan pengerjaan servis ini?',
    };
    final pesanKonfirmasi = konfirmasiMap[label] ?? 'Ubah status ke "$label"?';

    return ListTile(
      dense: true,
      leading: Icon(icon, color: color),
      title: Text(label,
          style: TextStyle(color: color, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: () async {
        final konfirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(fontSize: 16)),
              ],
            ),
            content: Text(pesanKonfirmasi),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Ya, Ubah'),
              ),
            ],
          ),
        );
        if (konfirm == true) onTap();
      },
    );
  }

  Widget _totalRow(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            Text(value,
                style: TextStyle(
                    fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                    fontSize: bold ? 15 : 13)),
          ],
        ),
      );

  void _showTambahSparepart() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _TambahSparepartSheet(
        onTambah: (id, jumlah) async {
          Navigator.pop(context);
          final res = await KasirService.instance.tambahSparepart(
            servisId: widget.servisId,
            sparepartId: id,
            jumlah: jumlah,
          );
          if (!mounted) return;
          final ok = res['success'] == true;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                res['message'] ?? (ok ? 'Sparepart ditambahkan' : 'Gagal')),
            backgroundColor: ok ? Colors.green : Colors.red,
          ));
          if (ok) _load();
        },
      ),
    );
  }
}

// ── Sparepart Tile ────────────────────────────────────────
class _SparepartTile extends StatelessWidget {
  final ServisSparepart sp;
  final VoidCallback? onHapus;
  const _SparepartTile({required this.sp, this.onHapus});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sp.nama,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(
                    '${sp.jumlah} ${sp.satuan} × ${FormatHelper.currency(sp.hargaJual)}',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
          Text(FormatHelper.currency(sp.subtotal),
              style: const TextStyle(fontWeight: FontWeight.w600)),
          if (onHapus != null)
            IconButton(
              icon: Icon(Icons.delete_outline,
                  size: 18, color: Colors.red.shade400),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Hapus Sparepart?'),
                    content: Text('Hapus "${sp.nama}" dari servis ini?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Batal')),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white),
                        child: const Text('Hapus'),
                      ),
                    ],
                  ),
                );
                if (ok == true) onHapus!();
              },
            ),
        ],
      ),
    );
  }
}

// ── Section Card ──────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const _SectionCard({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              const Spacer(),
              if (trailing != null) trailing!,
            ]),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

// ── Tambah Sparepart Sheet ────────────────────────────────
class _TambahSparepartSheet extends StatefulWidget {
  final void Function(int id, int jumlah) onTambah;
  const _TambahSparepartSheet({required this.onTambah});
  @override
  State<_TambahSparepartSheet> createState() => _TambahSparepartSheetState();
}

class _TambahSparepartSheetState extends State<_TambahSparepartSheet> {
  final _searchCtrl = TextEditingController();
  int _jumlah = 1;
  SparepartCariModel? _selected;
  List<SparepartCariModel> _results = [];
  bool _searching = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _cari(String keyword) async {
    if (keyword.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    final list = await KasirService.instance.cariSparepart(keyword.trim());
    if (!mounted) return;
    setState(() {
      _results = list;
      _searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tambah Sparepart',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            onChanged: _cari,
            decoration: InputDecoration(
              hintText: 'Cari nama / kode sparepart...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)))
                  : null,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 8),

          // Hasil pencarian
          if (_selected == null && _results.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _results.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final sp = _results[i];
                  return ListTile(
                    dense: true,
                    title: Text(sp.nama,
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text(
                        'Stok: ${sp.stok} ${sp.satuan} · ${FormatHelper.currency(sp.hargaJual)}',
                        style: const TextStyle(fontSize: 12)),
                    trailing: sp.stok > 0
                        ? const Icon(Icons.add_circle, color: Colors.indigo)
                        : Text('Habis',
                            style: TextStyle(
                                color: Colors.red.shade400, fontSize: 12)),
                    onTap: sp.stok > 0
                        ? () => setState(() {
                              _selected = sp;
                              _jumlah = 1;
                              _results = [];
                            })
                        : null,
                  );
                },
              ),
            ),

          // Item terpilih
          if (_selected != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                        child: Text(_selected!.nama,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold))),
                    GestureDetector(
                      onTap: () => setState(() => _selected = null),
                      child: const Icon(Icons.close, size: 18),
                    ),
                  ]),
                  Text(
                      'Stok: ${_selected!.stok} ${_selected!.satuan} · ${FormatHelper.currency(_selected!.hargaJual)}',
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Text('Jumlah: '),
                    IconButton(
                      onPressed:
                          _jumlah > 1 ? () => setState(() => _jumlah--) : null,
                      icon: const Icon(Icons.remove_circle),
                      color: Colors.indigo,
                    ),
                    Text('$_jumlah',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    IconButton(
                      onPressed: _jumlah < _selected!.stok
                          ? () => setState(() => _jumlah++)
                          : null,
                      icon: const Icon(Icons.add_circle),
                      color: Colors.indigo,
                    ),
                    const Spacer(),
                    Text(FormatHelper.currency(_selected!.hargaJual * _jumlah),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => widget.onTambah(_selected!.id, _jumlah),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Tambahkan'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Proses Bayar ──────────────────────────────────────────
class ProsesBayarScreen extends StatefulWidget {
  final int servisId;
  final double grandTotal;
  final String noBooking;
  const ProsesBayarScreen({
    super.key,
    required this.servisId,
    required this.grandTotal,
    required this.noBooking,
  });
  @override
  State<ProsesBayarScreen> createState() => _ProsesBayarScreenState();
}

class _ProsesBayarScreenState extends State<ProsesBayarScreen> {
  String _metodeBayar = 'cash';
  final _bayarCtrl = TextEditingController();
  double _kembalian = 0;
  bool _submitting = false;

  @override
  void dispose() {
    _bayarCtrl.dispose();
    super.dispose();
  }

  void _hitungKembalian() {
    final bayar = double.tryParse(
            _bayarCtrl.text.replaceAll('.', '').replaceAll(',', '')) ??
        0;
    setState(() => _kembalian = bayar - widget.grandTotal);
  }

  Future<void> _konfirmasiBayar() async {
    if (_metodeBayar == 'cash') {
      final bayar = double.tryParse(
              _bayarCtrl.text.replaceAll('.', '').replaceAll(',', '')) ??
          0;
      if (bayar < widget.grandTotal) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Jumlah bayar kurang dari total tagihan'),
          backgroundColor: Colors.red,
        ));
        return;
      }
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Konfirmasi Pembayaran'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _bRow('Total', FormatHelper.currency(widget.grandTotal),
                bold: true),
            _bRow('Metode', _metodeBayar == 'cash' ? 'Cash' : 'Transfer'),
            if (_metodeBayar == 'cash')
              _bRow('Kembalian',
                  FormatHelper.currency(_kembalian.clamp(0, double.infinity))),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('Konfirmasi'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _submitting = true);
    final bayar = _metodeBayar == 'cash'
        ? (double.tryParse(
                _bayarCtrl.text.replaceAll('.', '').replaceAll(',', '')) ??
            widget.grandTotal)
        : widget.grandTotal;

    final res = await KasirService.instance.prosesBayar({
      'servis_id': widget.servisId,
      'tipe': 'servis',
      'metode_bayar': _metodeBayar,
      'jumlah_bayar': bayar,
      'diskon': 0,
    });
    if (!mounted) return;
    setState(() => _submitting = false);

    final berhasil = res['success'] == true;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res['message'] ??
          (berhasil ? 'Pembayaran berhasil' : 'Gagal memproses pembayaran')),
      backgroundColor: berhasil ? Colors.green : Colors.red,
    ));
    if (berhasil) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text('Bayar · ${widget.noBooking}'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
        child: Column(
          children: [
            // Ringkasan biaya
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Ringkasan Biaya',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const Divider(height: 16),
                    _bRow('Total Tagihan',
                        FormatHelper.currency(widget.grandTotal),
                        bold: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Metode bayar
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Metode Pembayaran',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 12),
                    Row(children: [
                      _MetodeBtn(
                          'cash',
                          'Cash',
                          Icons.payments,
                          _metodeBayar,
                          () => setState(() {
                                _metodeBayar = 'cash';
                                _hitungKembalian();
                              })),
                      const SizedBox(width: 12),
                      _MetodeBtn(
                          'transfer',
                          'Transfer',
                          Icons.account_balance,
                          _metodeBayar,
                          () => setState(() => _metodeBayar = 'transfer')),
                    ]),
                    if (_metodeBayar == 'cash') ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _bayarCtrl,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _hitungKembalian(),
                        decoration: InputDecoration(
                          labelText: 'Jumlah Bayar',
                          prefixText: 'Rp ',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      if (_bayarCtrl.text.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _kembalian >= 0
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _kembalian >= 0 ? 'Kembalian' : 'Kurang',
                                style: TextStyle(
                                    color: _kembalian >= 0
                                        ? Colors.green.shade700
                                        : Colors.red.shade700,
                                    fontWeight: FontWeight.bold),
                              ),
                              Text(
                                FormatHelper.currency(_kembalian.abs()),
                                style: TextStyle(
                                    color: _kembalian >= 0
                                        ? Colors.green.shade700
                                        : Colors.red.shade700,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _konfirmasiBayar,
                icon: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : const Icon(Icons.receipt_long),
                label: const Text('Konfirmasi & Proses Bayar',
                    style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bRow(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            Text(value,
                style: TextStyle(
                    fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                    fontSize: bold ? 15 : 13)),
          ],
        ),
      );
}

class _MetodeBtn extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final String selected;
  final VoidCallback onTap;
  const _MetodeBtn(
      this.value, this.label, this.icon, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) {
    final active = value == selected;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? Colors.green.shade700 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: active ? Colors.green.shade700 : Colors.grey.shade300),
          ),
          child: Column(
            children: [
              Icon(icon, color: active ? Colors.white : Colors.grey),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      color: active ? Colors.white : Colors.grey,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}
