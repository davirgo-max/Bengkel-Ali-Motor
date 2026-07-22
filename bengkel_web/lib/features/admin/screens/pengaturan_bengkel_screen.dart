// lib/features/admin/screens/pengaturan_bengkel_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/utils/format_helper.dart';
import '../../../shared/widgets/app_dialogs.dart';
import '../../../shared/widgets/app_shell.dart';
// import '../../../shared/widgets/toolbar_controls.dart';
import '../models/admin_models.dart';
import '../services/admin_service.dart';
import 'admin_shell.dart';

class PengaturanBengkelScreen extends StatefulWidget {
  const PengaturanBengkelScreen({super.key});

  @override
  State<PengaturanBengkelScreen> createState() =>
      _PengaturanBengkelScreenState();
}

class _PengaturanBengkelScreenState extends State<PengaturanBengkelScreen> {
  final _svc = AdminService.instance;

  PengaturanBengkelModel? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final data = await _svc.getPengaturanBengkel();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _data = data;
      if (data == null) _error = 'Gagal memuat pengaturan bengkel';
    });
  }

  Future<void> _showEditDialog() async {
    if (_data == null) return;
    final messenger = ScaffoldMessenger.of(context);

    await showDialog<void>(
      context: context,
      builder: (ctx) => _EditPengaturanDialog(
        data: _data!,
        svc: _svc,
        onSaved: () {
          Navigator.pop(ctx);
          _load();
          messenger.showSnackBar(const SnackBar(
            content: Text('Pengaturan berhasil disimpan'),
            behavior: SnackBarBehavior.floating,
          ));
        },
        onError: (msg) => showAppSnackBar(ctx, msg, error: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      currentRoute: '/admin/pengaturan',
      pageTitle: 'Pengaturan Bengkel',
      actions: [
        TopbarButton(
          label: 'Refresh',
          icon: Icons.refresh,
          onPressed: _load,
        ),
      ],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!,
                          style: const TextStyle(color: Color(0xFFA32D2D))),
                      const SizedBox(height: 12),
                      OutlinedButton(
                          onPressed: _load, child: const Text('Coba Lagi')),
                    ],
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final d = _data!;
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Card Info Bengkel ──────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(
                  child: Text('Informasi Bengkel',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                OutlinedButton.icon(
                  onPressed: _showEditDialog,
                  icon: const Icon(Icons.edit_outlined, size: 15),
                  label: const Text('Edit'),
                ),
              ]),
              const SizedBox(height: 16),
              _infoGrid([
                _InfoItem('Nama Bengkel', d.namaBengkel),
                _InfoItem('No. HP / WA', d.noHpBengkel ?? '—'),
                _InfoItem('Alamat', d.alamatBengkel ?? '—'),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 12),

        // ── Card Operasional ───────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Jam & Kapasitas',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              _infoGrid([
                _InfoItem('Jam Buka', d.jamBuka),
                _InfoItem('Jam Tutup', d.jamTutup),
                _InfoItem(
                    'Kuota Servis / Hari', '${d.kuotaBookingHarian} servis'),
              ]),
              if (d.updatedAt != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Terakhir diperbarui: ${formatTanggalWaktu(d.updatedAt)}',
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF888899)),
                ),
              ],
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _infoGrid(List<_InfoItem> items) {
    return Wrap(
      spacing: 24,
      runSpacing: 12,
      children: items
          .map((item) => SizedBox(
                width: 260,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.label,
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF888899))),
                      const SizedBox(height: 3),
                      Text(item.value,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500)),
                    ]),
              ))
          .toList(),
    );
  }
}

class _InfoItem {
  final String label;
  final String value;
  const _InfoItem(this.label, this.value);
}

// ══════════════════════════════════════════════════════════════════════════════
// Dialog Edit Pengaturan — StatefulWidget mandiri (fix Assertion Failed)
// ══════════════════════════════════════════════════════════════════════════════

class _EditPengaturanDialog extends StatefulWidget {
  final PengaturanBengkelModel data;
  final AdminService svc;
  final VoidCallback onSaved;
  final void Function(String msg) onError;

  const _EditPengaturanDialog({
    required this.data,
    required this.svc,
    required this.onSaved,
    required this.onError,
  });

  @override
  State<_EditPengaturanDialog> createState() => _EditPengaturanDialogState();
}

class _EditPengaturanDialogState extends State<_EditPengaturanDialog> {
  late final TextEditingController _namaCtrl;
  late final TextEditingController _alamatCtrl;
  late final TextEditingController _noHpCtrl;
  late final TextEditingController _jamBukaCtrl;
  late final TextEditingController _jamTutupCtrl;
  late final TextEditingController _kuotaCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.data;
    _namaCtrl = TextEditingController(text: d.namaBengkel);
    _alamatCtrl = TextEditingController(text: d.alamatBengkel ?? '');
    _noHpCtrl = TextEditingController(text: d.noHpBengkel ?? '');
    _jamBukaCtrl = TextEditingController(text: d.jamBuka);
    _jamTutupCtrl = TextEditingController(text: d.jamTutup);
    _kuotaCtrl = TextEditingController(text: '${d.kuotaBookingHarian}');
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _alamatCtrl.dispose();
    _noHpCtrl.dispose();
    _jamBukaCtrl.dispose();
    _jamTutupCtrl.dispose();
    _kuotaCtrl.dispose();
    super.dispose();
  }

  bool _isValidJam(String v) => RegExp(r'^\d{2}:\d{2}$').hasMatch(v);

  Future<void> _save() async {
    final nama = _namaCtrl.text.trim();
    final jamBuka = _jamBukaCtrl.text.trim();
    final jamTutup = _jamTutupCtrl.text.trim();
    final kuota = int.tryParse(_kuotaCtrl.text.trim()) ?? 0;

    if (nama.isEmpty) {
      widget.onError('Nama bengkel wajib diisi');
      return;
    }
    if (jamBuka.isNotEmpty && !_isValidJam(jamBuka)) {
      widget.onError('Format jam buka harus HH:MM (contoh: 08:00)');
      return;
    }
    if (jamTutup.isNotEmpty && !_isValidJam(jamTutup)) {
      widget.onError('Format jam tutup harus HH:MM (contoh: 17:00)');
      return;
    }
    if (kuota < 1 || kuota > 100) {
      widget.onError('Kuota servis harian harus antara 1 – 100');
      return;
    }

    setState(() => _saving = true);

    final res = await widget.svc.updatePengaturanBengkel({
      'nama_bengkel': nama,
      'alamat_bengkel': _alamatCtrl.text.trim(),
      'no_hp_bengkel': _noHpCtrl.text.trim(),
      'jam_buka': jamBuka,
      'jam_tutup': jamTutup,
      'kuota_booking_harian': kuota,
    });

    if (!mounted) return;

    if (res['success'] == true) {
      widget.onSaved();
    } else {
      setState(() => _saving = false);
      widget.onError(res['message'] ?? 'Gagal menyimpan');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(children: [
                  const Expanded(
                    child: Text('Edit Pengaturan Bengkel',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w600)),
                  ),
                  InkWell(
                    onTap: _saving ? null : () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child:
                          Icon(Icons.close, size: 20, color: Color(0xFF888899)),
                    ),
                  ),
                ]),
                const SizedBox(height: 20),

                // Nama Bengkel
                const FieldLabel('Nama Bengkel', required: true),
                TextField(
                  controller: _namaCtrl,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                      hintText: 'Contoh: Bengkel Ali Motor'),
                ),
                const SizedBox(height: 14),

                // No HP
                const FieldLabel('No. HP / WhatsApp'),
                TextField(
                  controller: _noHpCtrl,
                  enabled: !_saving,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s]'))
                  ],
                  decoration: const InputDecoration(hintText: '08xx-xxxx-xxxx'),
                ),
                const SizedBox(height: 14),

                // Alamat
                const FieldLabel('Alamat'),
                TextField(
                  controller: _alamatCtrl,
                  enabled: !_saving,
                  maxLines: 2,
                  decoration:
                      const InputDecoration(hintText: 'Alamat lengkap bengkel'),
                ),
                const SizedBox(height: 14),

                // Jam operasional — 2 kolom
                Row(
                  children: [
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const FieldLabel('Jam Buka'),
                            TextField(
                              controller: _jamBukaCtrl,
                              enabled: !_saving,
                              keyboardType: TextInputType.datetime,
                              decoration:
                                  const InputDecoration(hintText: '08:00'),
                            ),
                          ]),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const FieldLabel('Jam Tutup'),
                            TextField(
                              controller: _jamTutupCtrl,
                              enabled: !_saving,
                              keyboardType: TextInputType.datetime,
                              decoration:
                                  const InputDecoration(hintText: '17:00'),
                            ),
                          ]),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('Format: HH:MM (contoh: 08:00, 17:00)',
                    style: TextStyle(fontSize: 11, color: Color(0xFF888899))),
                const SizedBox(height: 14),

                // Kuota booking
                const FieldLabel('Kuota Servis Harian', required: true),
                TextField(
                  controller: _kuotaCtrl,
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(hintText: 'Maks. 100'),
                ),
                const SizedBox(height: 4),
                const Text(
                    'Jumlah servis yang dapat diterima per hari (1 – 100)',
                    style: TextStyle(fontSize: 11, color: Color(0xFF888899))),
                const SizedBox(height: 24),

                // Actions
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Simpan'),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
