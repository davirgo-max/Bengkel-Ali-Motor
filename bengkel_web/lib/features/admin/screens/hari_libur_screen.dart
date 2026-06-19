// lib/features/admin/screens/hari_libur_screen.dart

import 'package:flutter/material.dart';
import '../../../core/utils/format_helper.dart';
import '../../../shared/widgets/app_dialogs.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/date_table_card.dart';
import '../../../shared/widgets/toolbar_controls.dart';
import '../models/admin_models.dart';
import '../services/admin_service.dart';
import 'admin_shell.dart';

const _namaHari = [
  'Minggu',
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
];

class HariLiburScreen extends StatefulWidget {
  const HariLiburScreen({super.key});

  @override
  State<HariLiburScreen> createState() => _HariLiburScreenState();
}

class _HariLiburScreenState extends State<HariLiburScreen> {
  final _svc = AdminService.instance;

  List<HariLiburModel> _items = [];
  bool _loading = true;
  int _tahun = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await _svc.getHariLibur(tahun: _tahun);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _items = items;
    });
  }

  String _hariDari(String tanggal) {
    try {
      final dt = DateTime.parse(tanggal);
      return _namaHari[dt.weekday % 7];
    } catch (_) {
      return '—';
    }
  }

  // ── Tambah hari libur ─────────────────────────────────────

  Future<void> _showTambahDialog() async {
    // Capture messenger sebelum async gap
    final messenger = ScaffoldMessenger.of(context);

    await showDialog<void>(
      context: context,
      builder: (ctx) => _TambahHariLiburDialog(
        tahun: _tahun,
        svc: _svc,
        onSaved: () {
          Navigator.pop(ctx);
          _load();
          messenger.showSnackBar(const SnackBar(
            content: Text('Hari libur ditambahkan'),
            behavior: SnackBarBehavior.floating,
          ));
        },
        onError: (msg) => showAppSnackBar(ctx, msg, error: true),
      ),
    );
  }

  // ── Hapus hari libur ──────────────────────────────────────

  Future<void> _hapus(HariLiburModel item) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Hapus Hari Libur?',
      message:
          '"${item.keterangan}" (${formatTanggal(item.tanggal)}) akan dihapus.',
      confirmText: 'Hapus',
      danger: true,
    );
    if (!ok || !mounted) return;
    final res = await _svc.hapusHariLibur(item.id);
    if (!mounted) return;
    if (res['success'] == true) {
      _load();
      showAppSnackBar(context, 'Hari libur dihapus');
    } else {
      showAppSnackBar(context, res['message'] ?? 'Gagal menghapus',
          error: true);
    }
  }

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tahunOptions = [
      DateTime.now().year - 1,
      DateTime.now().year,
      DateTime.now().year + 1,
    ];

    return AdminShell(
      currentRoute: '/admin/hari-libur',
      pageTitle: 'Hari Libur',
      actions: [
        TopbarButton(
          label: 'Tambah Hari Libur',
          icon: Icons.add,
          primary: true,
          onPressed: _showTambahDialog,
        ),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              FilterDropdown<int>(
                value: _tahun,
                onChanged: (v) {
                  if (v != null) setState(() => _tahun = v);
                  _load();
                },
                items: tahunOptions
                    .map((y) =>
                        DropdownMenuItem(value: y, child: Text('Tahun $y')))
                    .toList(),
              ),
              const Spacer(),
              Text('${_items.length} hari libur',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF888899))),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        TableCard(
          loading: _loading,
          stretch: false,
          columnSpacing: 10,
          horizontalMargin: 12,
          empty: const Text('Belum ada hari libur untuk tahun ini.',
              style: TextStyle(color: Color(0xFF888899))),
          columns: const [
            DataColumn(label: Text('TANGGAL')),
            DataColumn(label: Text('HARI')),
            DataColumn(label: Text('KETERANGAN')),
            DataColumn(label: Text('AKSI')),
          ],
          rows: _items.map((h) {
            return DataRow(cells: [
              DataCell(Text(formatTanggal(h.tanggal))),
              DataCell(Text(_hariDari(h.tanggal))),
              DataCell(SizedBox(
                width: 180,
                child: Text(
                  h.keterangan,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              )),
              DataCell(ActionIconButton(
                icon: Icons.delete_outline,
                tooltip: 'Hapus',
                color: const Color(0xFFA32D2D),
                onPressed: () => _hapus(h),
              )),
            ]);
          }).toList(),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Dialog Tambah Hari Libur — StatefulWidget mandiri (fix Assertion Failed)
// ══════════════════════════════════════════════════════════════════════════════

class _TambahHariLiburDialog extends StatefulWidget {
  final int tahun;
  final AdminService svc;
  final VoidCallback onSaved;
  final void Function(String msg) onError;

  const _TambahHariLiburDialog({
    required this.tahun,
    required this.svc,
    required this.onSaved,
    required this.onError,
  });

  @override
  State<_TambahHariLiburDialog> createState() => _TambahHariLiburDialogState();
}

class _TambahHariLiburDialogState extends State<_TambahHariLiburDialog> {
  DateTime? _tanggal;
  final _keteranganCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _keteranganCtrl.dispose();
    super.dispose();
  }

  /// Tentukan initialDate yang wajar untuk date picker
  DateTime get _initialDate {
    final now = DateTime.now();
    if (widget.tahun == now.year) {
      return DateTime(widget.tahun, now.month, 1);
    }
    return DateTime(widget.tahun, 1, 1);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _initialDate,
      firstDate: DateTime(widget.tahun - 1),
      lastDate: DateTime(widget.tahun + 2, 12, 31),
    );
    if (picked != null && mounted) setState(() => _tanggal = picked);
  }

  Future<void> _save() async {
    final keterangan = _keteranganCtrl.text.trim();
    if (_tanggal == null) {
      widget.onError('Tanggal wajib dipilih');
      return;
    }
    if (keterangan.isEmpty) {
      widget.onError('Keterangan wajib diisi');
      return;
    }

    setState(() => _saving = true);

    final tglStr = '${_tanggal!.year.toString().padLeft(4, '0')}-'
        '${_tanggal!.month.toString().padLeft(2, '0')}-'
        '${_tanggal!.day.toString().padLeft(2, '0')}';

    final res = await widget.svc
        .tambahHariLibur(tanggal: tglStr, keterangan: keterangan);

    if (!mounted) return;

    if (res['success'] == true) {
      widget.onSaved(); // tutup dialog + reload dari parent
    } else {
      setState(() => _saving = false);
      widget.onError(res['message'] ?? 'Gagal menyimpan');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tanggalLabel = _tanggal == null
        ? 'Pilih tanggal'
        : formatTanggal('${_tanggal!.year}-'
            '${_tanggal!.month.toString().padLeft(2, '0')}-'
            '${_tanggal!.day.toString().padLeft(2, '0')}');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(children: [
                const Expanded(
                  child: Text('Tambah Hari Libur',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
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
              const SizedBox(height: 18),

              // Tanggal
              const FieldLabel('Tanggal', required: true),
              InkWell(
                onTap: _saving ? null : _pickDate,
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    hintText: 'Pilih tanggal',
                    suffixIcon: Icon(Icons.calendar_today_outlined, size: 16),
                  ),
                  child: Text(
                    tanggalLabel,
                    style: TextStyle(
                      color: _tanggal == null ? const Color(0xFFAAAABB) : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Keterangan
              const FieldLabel('Keterangan', required: true),
              TextField(
                controller: _keteranganCtrl,
                enabled: !_saving,
                decoration:
                    const InputDecoration(hintText: 'Mis. Libur Lebaran'),
              ),
              const SizedBox(height: 20),

              // Actions
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Batal')),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Tambah'),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
