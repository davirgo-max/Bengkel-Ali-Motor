// lib/features/admin/screens/kelola_jenis_servis_screen.dart

import 'package:flutter/material.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/utils/format_helper.dart';
import '../../../shared/widgets/app_dialogs.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/badge_pill.dart';
import '../../../shared/widgets/toolbar_controls.dart';
import '../models/admin_models.dart';
import '../services/admin_service.dart';
import 'admin_shell.dart';

class KelolaJenisServisScreen extends StatefulWidget {
  const KelolaJenisServisScreen({super.key});

  @override
  State<KelolaJenisServisScreen> createState() =>
      _KelolaJenisServisScreenState();
}

class _KelolaJenisServisScreenState extends State<KelolaJenisServisScreen> {
  final _svc = AdminService.instance;
  final _searchCtrl = TextEditingController();

  List<JenisServisModel> _items = [];
  bool _loading = true;
  String _tampilkan = 'semua';

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
    final items = await _svc.getJenisServis(tampilkan: _tampilkan);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _items = items;
    });
  }

  List<JenisServisModel> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items.where((m) => m.nama.toLowerCase().contains(q)).toList();
  }

  // ── Dialog Tambah / Edit ─────────────────────────────────
  // FIX: Menggunakan StatefulWidget terpisah (_JenisServisFormDialog) alih-alih
  // StatefulBuilder di dalam showDialog. Ini mencegah Assertion error
  // "_dependents.isEmpty is not true" yang terjadi ketika StatefulBuilder
  // mencoba memanggil setState setelah dialog mulai ditutup.

  Future<void> _showFormDialog({JenisServisModel? item}) async {
    final messenger = ScaffoldMessenger.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => _JenisServisFormDialog(
        item: item,
        svc: _svc,
        onSaved: (isEdit) {
          Navigator.pop(ctx);
          _load();
          messenger.showSnackBar(SnackBar(
            content: Text(
                isEdit ? 'Jenis servis diperbarui' : 'Jenis servis ditambahkan'),
            behavior: SnackBarBehavior.floating,
          ));
        },
        onError: (msg) => showAppSnackBar(ctx, msg, error: true),
      ),
    );
  }

  Future<void> _toggleAktif(JenisServisModel item) async {
    final aktifkan = !item.isAktif;
    final ok = await showConfirmDialog(
      context,
      title: aktifkan ? 'Aktifkan Jenis Servis?' : 'Nonaktifkan Jenis Servis?',
      message: aktifkan
          ? '${item.nama} akan bisa dipilih lagi saat pelanggan booking.'
          : '${item.nama} tidak akan muncul lagi sebagai pilihan booking.',
      confirmText: aktifkan ? 'Aktifkan' : 'Nonaktifkan',
      danger: !aktifkan,
    );
    if (!ok || !mounted) return;
    final res = await _svc.toggleAktifJenisServis(item.id, aktifkan);
    if (!mounted) return;
    if (res['success'] == true) {
      _load();
      showAppSnackBar(context, res['message'] ?? 'Status diperbarui');
    } else {
      showAppSnackBar(context, res['message'] ?? 'Gagal mengubah status',
          error: true);
    }
  }

  Future<void> _hapus(JenisServisModel item) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Hapus Jenis Servis?',
      message:
          '"${item.nama}" akan dihapus. Jika pernah dipakai pada booking, jenis servis akan dinonaktifkan saja.',
      confirmText: 'Hapus',
      danger: true,
    );
    if (!ok || !mounted) return;
    final res = await _svc.hapusJenisServis(item.id);
    if (!mounted) return;
    if (res['success'] == true) {
      _load();
      showAppSnackBar(context, res['message'] ?? 'Jenis servis dihapus');
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
      currentRoute: '/admin/jenis-servis',
      pageTitle: 'Kelola Jenis Servis',
      actions: [
        TopbarButton(
          label: 'Tambah Jenis Servis',
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
                hint: 'Cari nama jenis servis...',
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                maxWidth: 300,
              ),
              const SizedBox(width: 10),
              FilterDropdown<String>(
                value: _tampilkan,
                onChanged: (v) {
                  if (v != null) setState(() => _tampilkan = v);
                  _load();
                },
                items: const [
                  DropdownMenuItem(value: 'semua', child: Text('Semua')),
                  DropdownMenuItem(value: 'aktif', child: Text('Aktif')),
                  DropdownMenuItem(
                      value: 'nonaktif', child: Text('Non-aktif')),
                ],
              ),
              const Spacer(),
              Text(
                '${filtered.length} jenis servis',
                style: const TextStyle(fontSize: 12, color: Color(0xFF888899)),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: _loading
              ? const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()))
              : filtered.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(
                          child: Text('Belum ada data jenis servis.',
                              style: TextStyle(color: Color(0xFF888899)))))
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('NAMA')),
                          DataColumn(label: Text('DESKRIPSI')),
                          DataColumn(label: Text('HARGA JASA')),
                          DataColumn(label: Text('ESTIMASI')),
                          DataColumn(label: Text('DIPAKAI')),
                          DataColumn(label: Text('STATUS')),
                          DataColumn(label: Text('AKSI')),
                        ],
                        rows: filtered.map((j) {
                          return DataRow(cells: [
                            DataCell(Text(j.nama,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500))),
                            DataCell(SizedBox(
                              width: 220,
                              child: Text(
                                j.deskripsi?.isNotEmpty == true
                                    ? j.deskripsi!
                                    : '—',
                                style:
                                    const TextStyle(color: Color(0xFF888899)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            )),
                            DataCell(Text(formatRupiah(j.hargaJasa))),
                            DataCell(Text('${j.estimasiMenit} menit')),
                            DataCell(Text('${j.jumlahDipakai}x')),
                            DataCell(BadgePill(
                              text: j.isAktif ? 'Aktif' : 'Non-aktif',
                              color:
                                  j.isAktif ? PillColor.green : PillColor.grey,
                            )),
                            DataCell(
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 17),
                                tooltip: 'Edit',
                                color: AppTheme.primary,
                                onPressed: () => _showFormDialog(item: j),
                              ),
                              IconButton(
                                icon: Icon(
                                    j.isAktif
                                        ? Icons.power_settings_new
                                        : Icons.check_circle_outline,
                                    size: 17),
                                tooltip: j.isAktif ? 'Nonaktifkan' : 'Aktifkan',
                                color: j.isAktif
                                    ? const Color(0xFFA32D2D)
                                    : const Color(0xFF0F6E56),
                                onPressed: () => _toggleAktif(j),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 17),
                                tooltip: 'Hapus',
                                color: const Color(0xFFA32D2D),
                                onPressed: () => _hapus(j),
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

// ── Dialog form jenis servis (StatefulWidget terpisah) ────────────────────────
//
// PENTING: Dipisah dari parent agar lifecycle TextEditingController sepenuhnya
// dikelola di sini. StatefulBuilder di dalam showDialog menyebabkan Assertion
// error "_dependents.isEmpty is not true" karena setState() bisa dipanggil
// di tengah animasi penutupan dialog (widget sedang di-deactivate).
// Dengan StatefulWidget terpisah, dispose() controller terjadi setelah
// widget benar-benar di-unmount, sehingga aman.

class _JenisServisFormDialog extends StatefulWidget {
  final JenisServisModel? item;
  final AdminService svc;
  final void Function(bool isEdit) onSaved;
  final void Function(String msg) onError;

  const _JenisServisFormDialog({
    required this.item,
    required this.svc,
    required this.onSaved,
    required this.onError,
  });

  @override
  State<_JenisServisFormDialog> createState() => _JenisServisFormDialogState();
}

class _JenisServisFormDialogState extends State<_JenisServisFormDialog> {
  late final TextEditingController _namaCtrl;
  late final TextEditingController _deskripsiCtrl;
  late final TextEditingController _hargaCtrl;
  late final TextEditingController _estimasiCtrl;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _namaCtrl = TextEditingController(text: item?.nama);
    _deskripsiCtrl = TextEditingController(text: item?.deskripsi);
    _hargaCtrl = TextEditingController(
        text: item != null ? '${item.hargaJasa.toInt()}' : '');
    _estimasiCtrl = TextEditingController(
        text: item != null ? '${item.estimasiMenit}' : '60');
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _deskripsiCtrl.dispose();
    _hargaCtrl.dispose();
    _estimasiCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final isEdit = widget.item != null;
    final nama = _namaCtrl.text.trim();
    final harga = double.tryParse(_hargaCtrl.text.trim());
    final estimasi = int.tryParse(_estimasiCtrl.text.trim());

    if (nama.isEmpty) {
      widget.onError('Nama jenis servis wajib diisi');
      return;
    }
    if (harga == null || harga < 0) {
      widget.onError('Harga jasa tidak valid');
      return;
    }
    if (estimasi == null || estimasi <= 0) {
      widget.onError('Estimasi waktu tidak valid');
      return;
    }

    setState(() => _saving = true);

    final res = isEdit
        ? await widget.svc.editJenisServis(
            widget.item!.id,
            nama: nama,
            deskripsi: _deskripsiCtrl.text.trim(),
            hargaJasa: harga,
            estimasiMenit: estimasi,
          )
        : await widget.svc.tambahJenisServis(
            nama: nama,
            deskripsi: _deskripsiCtrl.text.trim(),
            hargaJasa: harga,
            estimasiMenit: estimasi,
          );

    if (!mounted) return;

    if (res['success'] == true) {
      widget.onSaved(isEdit);
    } else {
      setState(() => _saving = false);
      widget.onError(res['message'] ?? 'Gagal menyimpan');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;

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
                      isEdit ? 'Edit Jenis Servis' : 'Tambah Jenis Servis',
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
                const FieldLabel('Nama Jenis Servis', required: true),
                TextField(
                    controller: _namaCtrl,
                    decoration: const InputDecoration(
                        hintText: 'Mis. Servis Ringan')),
                const SizedBox(height: 14),
                const FieldLabel('Deskripsi'),
                TextField(
                  controller: _deskripsiCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      hintText: 'Mis. Ganti oli, cek rem, cek busi'),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const FieldLabel('Harga Jasa (Rp)', required: true),
                          TextField(
                              controller: _hargaCtrl,
                              keyboardType: TextInputType.number,
                              decoration:
                                  const InputDecoration(hintText: '0')),
                        ]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const FieldLabel('Estimasi (menit)', required: true),
                          TextField(
                              controller: _estimasiCtrl,
                              keyboardType: TextInputType.number,
                              decoration:
                                  const InputDecoration(hintText: '60')),
                        ]),
                  ),
                ]),
                const SizedBox(height: 20),
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
                        : Text(isEdit
                            ? 'Simpan Perubahan'
                            : 'Tambah Jenis Servis'),
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
