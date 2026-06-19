// lib/features/admin/screens/kelola_mekanik_screen.dart

import 'package:flutter/material.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/utils/format_helper.dart';
import '../../../shared/widgets/app_dialogs.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/badge_pill.dart';
import '../../../shared/widgets/date_table_card.dart';
import '../../../shared/widgets/toolbar_controls.dart';
import '../models/admin_models.dart';
import '../services/admin_service.dart';
import 'admin_shell.dart';

class KelolaMekanikScreen extends StatefulWidget {
  const KelolaMekanikScreen({super.key});

  @override
  State<KelolaMekanikScreen> createState() => _KelolaMekanikScreenState();
}

class _KelolaMekanikScreenState extends State<KelolaMekanikScreen> {
  final _svc = AdminService.instance;
  final _searchCtrl = TextEditingController();

  List<MekanikModel> _items = [];
  bool _loading = true;
  String _tampilkan = 'aktif';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await _svc.getMekanik(tampilkan: _tampilkan);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _items = items;
    });
  }

  List<MekanikModel> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items
        .where((m) =>
            m.nama.toLowerCase().contains(q) ||
            (m.spesialisasi?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  // ── Validasi no HP ───────────────────────────────────────
  String? _validateNoHp(String val) {
    if (val.trim().isEmpty) return 'No. HP wajib diisi';
    if (!RegExp(r'^[0-9+\-\s]{8,15}$').hasMatch(val.trim())) {
      return 'No. HP tidak valid (8–15 digit, hanya angka/+/-)';
    }
    return null;
  }

  // ── Dialog Tambah / Edit ─────────────────────────────────
  // FIX: Assertion error — pindahkan dispose ke dalam widget agar tidak
  // dipanggil saat StatefulBuilder masih bisa render ulang.

  Future<void> _showFormDialog({MekanikModel? item}) async {
    final isEdit = item != null;
    final namaCtrl = TextEditingController(text: item?.nama);
    final noHpCtrl = TextEditingController(text: item?.noHp);
    final spesialisasiCtrl = TextEditingController(text: item?.spesialisasi);

    final messenger = ScaffoldMessenger.of(context);

    await showDialog<void>(
      context: context,
      builder: (ctx) => _MekanikFormDialog(
        isEdit: isEdit,
        namaCtrl: namaCtrl,
        noHpCtrl: noHpCtrl,
        spesialisasiCtrl: spesialisasiCtrl,
        validateNoHp: _validateNoHp,
        onSave: (res) {
          Navigator.pop(ctx);
          _load();
          messenger.showSnackBar(SnackBar(
            content: Text(
                isEdit ? 'Data mekanik diperbarui' : 'Mekanik ditambahkan'),
            behavior: SnackBarBehavior.floating,
          ));
        },
        onError: (msg) => showAppSnackBar(ctx, msg, error: true),
        svc: _svc,
        itemId: item?.id,
      ),
    );
  }

  // ── Toggle aktif / nonaktif ──────────────────────────────

  Future<void> _toggle(MekanikModel m) async {
    final aktifkan = !m.isAktif;
    final ok = await showConfirmDialog(
      context,
      title: aktifkan ? 'Aktifkan Mekanik?' : 'Nonaktifkan Mekanik?',
      message: aktifkan
          ? '${m.nama} akan muncul kembali dalam daftar aktif.'
          : '${m.nama} tidak akan bisa dipilih sampai diaktifkan lagi.',
      confirmText: aktifkan ? 'Aktifkan' : 'Nonaktifkan',
      danger: !aktifkan,
    );
    if (!ok || !mounted) return;
    final res = await _svc.toggleAktifMekanik(m.id, aktifkan);
    if (!mounted) return;
    if (res['success'] == true) {
      _load();
      showAppSnackBar(context, res['message'] ?? 'Status diperbarui');
    } else {
      showAppSnackBar(context, res['message'] ?? 'Gagal mengubah status',
          error: true);
    }
  }

  // ── Hapus mekanik ────────────────────────────────────────

  Future<void> _hapus(MekanikModel m) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Hapus Mekanik?',
      message:
          'Hapus ${m.nama}? Jika sudah pernah menangani servis, mekanik akan dinonaktifkan (bukan dihapus) agar riwayat tidak rusak.',
      confirmText: 'Hapus',
      danger: true,
    );
    if (!ok || !mounted) return;
    final res = await _svc.hapusMekanik(m.id);
    if (!mounted) return;
    if (res['success'] == true) {
      _load();
      showAppSnackBar(context, res['message'] ?? 'Mekanik dihapus');
    } else {
      showAppSnackBar(context, res['message'] ?? 'Gagal menghapus',
          error: true);
    }
  }

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return AdminShell(
      currentRoute: '/admin/mekanik',
      pageTitle: 'Kelola Mekanik',
      actions: [
        TopbarButton(
          label: 'Tambah Mekanik',
          icon: Icons.add,
          primary: true,
          onPressed: () => _showFormDialog(),
        ),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              SearchField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                hint: 'Cari nama / spesialisasi…',
                maxWidth: 300,
              ),
              const SizedBox(width: 10),
              FilterDropdown<String>(
                value: _tampilkan,
                items: const [
                  DropdownMenuItem(value: 'aktif', child: Text('Aktif')),
                  DropdownMenuItem(value: 'nonaktif', child: Text('Nonaktif')),
                  DropdownMenuItem(value: 'semua', child: Text('Semua')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _tampilkan = v);
                  _load();
                },
              ),
              const Spacer(),
              Text('${filtered.length} mekanik',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF888899))),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(),
            ),
          )
        else if (filtered.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: Center(
                child: Text('Tidak ada mekanik ditemukan.',
                    style: TextStyle(color: Color(0xFF888899))),
              ),
            ),
          )
        else
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Color(0xFFE5E5EF)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor:
                    WidgetStateProperty.all(const Color(0xFFF8F8FB)),
                columnSpacing: 20,
                columns: const [
                  DataColumn(label: Text('NAMA')),
                  DataColumn(label: Text('NO. HP')),
                  DataColumn(label: Text('SPESIALISASI')),
                  DataColumn(label: Text('STATUS')),
                  DataColumn(label: Text('BERGABUNG')),
                  DataColumn(label: Text('AKSI')),
                ],
                rows: filtered.map((m) {
                  return DataRow(cells: [
                    DataCell(Text(m.nama,
                        style: const TextStyle(fontWeight: FontWeight.w500))),
                    DataCell(Text(m.noHp ?? '—')),
                    DataCell(Text(m.spesialisasi ?? '—')),
                    DataCell(BadgePill(
                      text: m.isAktif ? 'Aktif' : 'Nonaktif',
                      color: m.isAktif ? PillColor.green : PillColor.grey,
                    )),
                    DataCell(Text(formatTanggal(m.createdAt))),
                    DataCell(Row(children: [
                      ActionIconButton(
                        icon: Icons.edit_outlined,
                        tooltip: 'Edit',
                        onPressed: () => _showFormDialog(item: m),
                      ),
                      const SizedBox(width: 4),
                      ActionIconButton(
                        icon: m.isAktif
                            ? Icons.power_settings_new
                            : Icons.power_settings_new_outlined,
                        tooltip: m.isAktif ? 'Nonaktifkan' : 'Aktifkan',
                        color: m.isAktif
                            ? const Color(0xFFA32D2D)
                            : AppTheme.primary,
                        onPressed: () => _toggle(m),
                      ),
                      const SizedBox(width: 4),
                      ActionIconButton(
                        icon: Icons.delete_outline,
                        tooltip: 'Hapus',
                        color: const Color(0xFFA32D2D),
                        onPressed: () => _hapus(m),
                      ),
                    ])),
                  ]);
                }).toList(),
              ),
            ),
          ),
      ]),
    );
  }
}

// ── Widget dialog form mekanik (terpisah agar controller dispose aman) ────────

class _MekanikFormDialog extends StatefulWidget {
  final bool isEdit;
  final TextEditingController namaCtrl;
  final TextEditingController noHpCtrl;
  final TextEditingController spesialisasiCtrl;
  final String? Function(String) validateNoHp;
  final void Function(Map<String, dynamic>) onSave;
  final void Function(String) onError;
  final AdminService svc;
  final int? itemId;

  const _MekanikFormDialog({
    required this.isEdit,
    required this.namaCtrl,
    required this.noHpCtrl,
    required this.spesialisasiCtrl,
    required this.validateNoHp,
    required this.onSave,
    required this.onError,
    required this.svc,
    this.itemId,
  });

  @override
  State<_MekanikFormDialog> createState() => _MekanikFormDialogState();
}

class _MekanikFormDialogState extends State<_MekanikFormDialog> {
  bool _saving = false;
  String? _noHpError;

  @override
  void dispose() {
    // Controller di-dispose di sini — aman karena widget ini yang owning-nya
    widget.namaCtrl.dispose();
    widget.noHpCtrl.dispose();
    widget.spesialisasiCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nama = widget.namaCtrl.text.trim();
    if (nama.isEmpty) {
      widget.onError('Nama mekanik wajib diisi');
      return;
    }
    final hpErr = widget.validateNoHp(widget.noHpCtrl.text);
    if (hpErr != null) {
      setState(() => _noHpError = hpErr);
      return;
    }
    if (widget.spesialisasiCtrl.text.trim().isEmpty) {
      widget.onError('Spesialisasi wajib diisi');
      return;
    }
    setState(() {
      _saving = true;
      _noHpError = null;
    });
    final res = widget.isEdit
        ? await widget.svc.editMekanik(
            widget.itemId!,
            nama: nama,
            noHp: widget.noHpCtrl.text.trim(),
            spesialisasi: widget.spesialisasiCtrl.text.trim(),
          )
        : await widget.svc.tambahMekanik(
            nama: nama,
            noHp: widget.noHpCtrl.text.trim(),
            spesialisasi: widget.spesialisasiCtrl.text.trim(),
          );
    if (!mounted) return;
    if (res['success'] == true) {
      widget.onSave(res);
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
          maxWidth: 460,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(children: [
                  Expanded(
                    child: Text(
                      widget.isEdit ? 'Edit Mekanik' : 'Tambah Mekanik',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child:
                          Icon(Icons.close, size: 20, color: Color(0xFF888899)),
                    ),
                  ),
                ]),
                const SizedBox(height: 18),
                // Form
                const FieldLabel('Nama Mekanik', required: true),
                TextField(
                    controller: widget.namaCtrl,
                    decoration:
                        const InputDecoration(hintText: 'Nama lengkap')),
                const SizedBox(height: 14),
                const FieldLabel('No. HP', required: true),
                TextField(
                  controller: widget.noHpCtrl,
                  keyboardType: TextInputType.phone,
                  onChanged: (_) {
                    if (_noHpError != null) setState(() => _noHpError = null);
                  },
                  decoration: InputDecoration(
                    hintText: '08xx-xxxx-xxxx',
                    errorText: _noHpError,
                  ),
                ),
                const SizedBox(height: 14),
                const FieldLabel('Spesialisasi', required: true),
                TextField(
                    controller: widget.spesialisasiCtrl,
                    decoration: const InputDecoration(
                        hintText: 'Mis. Mesin, Kelistrikan, Ban')),
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  OutlinedButton(
                      onPressed: () => Navigator.pop(context),
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
                        : Text(widget.isEdit ? 'Simpan' : 'Tambah'),
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
