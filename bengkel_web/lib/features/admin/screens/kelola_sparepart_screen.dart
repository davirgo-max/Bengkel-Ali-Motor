// lib/features/admin/screens/kelola_sparepart_screen.dart

import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
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

class KelolaSparepartScreen extends StatefulWidget {
  const KelolaSparepartScreen({super.key});

  @override
  State<KelolaSparepartScreen> createState() => _KelolaSparepartScreenState();
}

class _KelolaSparepartScreenState extends State<KelolaSparepartScreen> {
  final _svc = AdminService.instance;
  final _searchCtrl = TextEditingController();

  List<SparepartModel> _items = [];
  List<KategoriModel> _kategori = [];
  bool _loading = true;
  String? _error;
  String _tampilkan = 'semua';
  int? _filtKategori;

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
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await _svc.getSparepart(
      search: _searchCtrl.text,
      kategoriId: _filtKategori,
      tampilkan: _tampilkan,
    );
    if (!mounted) return;
    if (res['success'] != true) {
      setState(() {
        _loading = false;
        _error = res['message'] ?? 'Gagal memuat data';
      });
      return;
    }
    try {
      final data = res['data'] as Map<String, dynamic>? ?? {};
      final rawItems = data['sparepart'] as List? ?? [];
      final rawKat = data['kategori'] as List? ?? [];
      setState(() {
        _loading = false;
        _items = rawItems
            .whereType<Map<String, dynamic>>()
            .map(SparepartModel.fromJson)
            .toList();
        _kategori = rawKat
            .whereType<Map<String, dynamic>>()
            .map(KategoriModel.fromJson)
            .toList();
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'Format respons tidak sesuai';
      });
    }
  }

  // ── Dialog Tambah / Edit ─────────────────────────────────
  // FIX: Dialog dibuat sebagai StatefulWidget terpisah (_SparepartFormDialog)
  // agar controller, file picker, dan setState tidak bentrok dengan
  // animasi penutupan dialog (sumber Assertion error _dependents.isEmpty).

  Future<void> _showFormDialog({SparepartModel? item}) async {
    final messenger = ScaffoldMessenger.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => _SparepartFormDialog(
        item: item,
        kategori: _kategori,
        svc: _svc,
        onSaved: (isEdit) {
          Navigator.pop(ctx);
          _load();
          messenger.showSnackBar(SnackBar(
            content:
                Text(isEdit ? 'Sparepart diperbarui' : 'Sparepart ditambahkan'),
            behavior: SnackBarBehavior.floating,
          ));
        },
        onError: (msg) => showAppSnackBar(ctx, msg, error: true),
      ),
    );
  }

  // ── Toggle aktif / nonaktif ──────────────────────────────

  Future<void> _toggleAktif(SparepartModel sp) async {
    final aktifkan = !sp.isAktif;
    final ok = await showConfirmDialog(
      context,
      title: aktifkan ? 'Aktifkan Sparepart?' : 'Nonaktifkan Sparepart?',
      message: aktifkan
          ? '${sp.nama} akan muncul kembali dan bisa dipilih saat transaksi.'
          : '${sp.nama} tidak akan bisa dipilih sampai diaktifkan lagi.',
      confirmText: aktifkan ? 'Aktifkan' : 'Nonaktifkan',
      danger: !aktifkan,
    );
    if (!ok || !mounted) return;
    final res = await _svc.toggleAktifSparepart(sp.id, aktifkan);
    if (!mounted) return;
    if (res['success'] == true) {
      _load();
      showAppSnackBar(context, res['message'] ?? 'Status diperbarui');
    } else {
      showAppSnackBar(context, res['message'] ?? 'Gagal mengubah status',
          error: true);
    }
  }

  // ── Hapus ────────────────────────────────────────────────

  Future<void> _hapus(SparepartModel item) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Hapus Sparepart?',
      message: 'Sparepart "${item.nama}" akan dihapus permanen.',
      confirmText: 'Hapus',
      danger: true,
    );
    if (!ok || !mounted) return;
    final res = await _svc.hapusSparepart(item.id);
    if (!mounted) return;
    if (res['success'] == true) {
      _load();
      showAppSnackBar(context, 'Sparepart dihapus');
    } else {
      showAppSnackBar(context, res['message'] ?? 'Gagal menghapus',
          error: true);
    }
  }

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final stokMenipis = _items.where((e) => e.stokMenipis && e.isAktif).length;

    return AdminShell(
      currentRoute: '/admin/sparepart',
      pageTitle: 'Kelola Sparepart',
      actions: [
        TopbarButton(
          label: 'Tambah Sparepart',
          icon: Icons.add,
          primary: true,
          onPressed: () => _showFormDialog(),
        ),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Banner stok menipis
        if (stokMenipis > 0)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFAEEDA),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFEDD09A), width: 0.5),
            ),
            child: Row(children: [
              const Icon(Icons.warning_amber_outlined,
                  size: 18, color: Color(0xFF633806)),
              const SizedBox(width: 10),
              Text(
                '$stokMenipis item stok menipis — segera lakukan pembelian stok.',
                style: const TextStyle(fontSize: 13, color: Color(0xFF633806)),
              ),
            ]),
          ),

        // Toolbar
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              SearchField(
                hint: 'Cari nama / kode sparepart...',
                controller: _searchCtrl,
                onChanged: (_) => _load(),
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
                  DropdownMenuItem(value: 'nonaktif', child: Text('Non-aktif')),
                  DropdownMenuItem(
                      value: 'menipis', child: Text('Stok Menipis')),
                  DropdownMenuItem(value: 'habis', child: Text('Stok Habis')),
                ],
              ),
              const SizedBox(width: 10),
              if (_kategori.isNotEmpty)
                FilterDropdown<int?>(
                  value: _filtKategori,
                  onChanged: (v) {
                    setState(() => _filtKategori = v);
                    _load();
                  },
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('Semua Kategori')),
                    ..._kategori.map((k) =>
                        DropdownMenuItem(value: k.id, child: Text(k.nama))),
                  ],
                ),
              const Spacer(),
              Text(
                '${_items.length} item',
                style: const TextStyle(fontSize: 12, color: Color(0xFF888899)),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 12),

        // Tabel
        Card(
          child: _loading
              ? const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()))
              : _error != null
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                          child: Text(_error!,
                              style:
                                  const TextStyle(color: Color(0xFFA32D2D)))))
                  : _items.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(48),
                          child: Center(
                              child: Text('Belum ada data sparepart.',
                                  style: TextStyle(color: Color(0xFF888899)))))
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(
                                const Color(0xFFF8F8FB)),
                            columnSpacing: 20,
                            columns: const [
                              DataColumn(label: Text('FOTO')),
                              DataColumn(label: Text('KODE')),
                              DataColumn(label: Text('NAMA')),
                              DataColumn(label: Text('KATEGORI')),
                              DataColumn(label: Text('HARGA JUAL')),
                              DataColumn(label: Text('STOK')),
                              DataColumn(label: Text('STATUS')),
                              DataColumn(label: Text('AKSI')),
                            ],
                            rows: _items.map((sp) {
                              return DataRow(cells: [
                                // Kolom Foto
                                DataCell(_FotoThumb(fotoPath: sp.foto)),
                                DataCell(Text(sp.kode,
                                    style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 12))),
                                DataCell(Text(sp.nama,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500))),
                                DataCell(Text(sp.kategoriNama ?? '—',
                                    style: const TextStyle(
                                        color: Color(0xFF888899)))),
                                DataCell(Text(formatRupiah(sp.hargaJual))),
                                DataCell(_stokCell(sp)),
                                DataCell(BadgePill(
                                  text: sp.isAktif ? 'Aktif' : 'Non-aktif',
                                  color: sp.isAktif
                                      ? PillColor.green
                                      : PillColor.grey,
                                )),
                                DataCell(Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ActionIconButton(
                                        icon: Icons.edit_outlined,
                                        tooltip: 'Edit',
                                        onPressed: () =>
                                            _showFormDialog(item: sp),
                                      ),
                                      const SizedBox(width: 4),
                                      ActionIconButton(
                                        icon: sp.isAktif
                                            ? Icons.power_settings_new
                                            : Icons.power_settings_new_outlined,
                                        tooltip: sp.isAktif
                                            ? 'Nonaktifkan'
                                            : 'Aktifkan',
                                        color: sp.isAktif
                                            ? const Color(0xFFA32D2D)
                                            : AppTheme.primary,
                                        onPressed: () => _toggleAktif(sp),
                                      ),
                                      const SizedBox(width: 4),
                                      ActionIconButton(
                                        icon: Icons.delete_outline,
                                        tooltip: 'Hapus',
                                        color: const Color(0xFFA32D2D),
                                        onPressed: () => _hapus(sp),
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

  Widget _stokCell(SparepartModel sp) {
    Color textColor = const Color(0xFF1A1A2E);
    if (sp.habis) {
      textColor = const Color(0xFFA32D2D);
    } else if (sp.stokMenipis) {
      textColor = const Color(0xFF633806);
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(
        '${sp.stok} ${sp.satuan}',
        style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
      ),
      if (sp.habis) ...[
        const SizedBox(width: 6),
        const BadgePill(text: 'Habis', color: PillColor.red),
      ] else if (sp.stokMenipis) ...[
        const SizedBox(width: 6),
        const BadgePill(text: 'Menipis', color: PillColor.amber),
      ],
    ]);
  }
}

// ── Thumbnail foto di tabel ───────────────────────────────

class _FotoThumb extends StatelessWidget {
  final String? fotoPath;
  const _FotoThumb({this.fotoPath});

  @override
  Widget build(BuildContext context) {
    if (fotoPath == null || fotoPath!.isEmpty) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F1F6),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.image_not_supported_outlined,
            size: 18, color: Color(0xFFCCCCD8)),
      );
    }
    final url = '${AppConstants.uploadUrl}/$fotoPath';
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        url,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F1F6),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(Icons.broken_image_outlined,
              size: 18, color: Color(0xFFCCCCD8)),
        ),
      ),
    );
  }
}

// ── Dialog form sparepart (StatefulWidget terpisah) ───────
//
// Dipisah dari parent agar lifecycle controller (TextEditingController,
// file picker state) sepenuhnya dikelola di sini — mencegah Assertion error
// "_dependents.isEmpty is not true" yang muncul saat StatefulBuilder di dalam
// showDialog mencoba setState setelah dialog mulai ditutup.

class _SparepartFormDialog extends StatefulWidget {
  final SparepartModel? item;
  final List<KategoriModel> kategori;
  final AdminService svc;
  final void Function(bool isEdit) onSaved;
  final void Function(String msg) onError;

  const _SparepartFormDialog({
    required this.item,
    required this.kategori,
    required this.svc,
    required this.onSaved,
    required this.onError,
  });

  @override
  State<_SparepartFormDialog> createState() => _SparepartFormDialogState();
}

class _SparepartFormDialogState extends State<_SparepartFormDialog> {
  late final TextEditingController _namaCtrl;
  late final TextEditingController _kodeCtrl;
  late final TextEditingController _satuanCtrl;
  late final TextEditingController _hargaBeliCtrl;
  late final TextEditingController _hargaJualCtrl;
  late final TextEditingController _stokCtrl;
  late final TextEditingController _stokMinCtrl;

  int? _katId;
  bool _saving = false;

  // ── Foto ─────────────────────────────────────────────────
  Uint8List? _fotoBytes; // file baru yang dipilih user
  String? _fotoNama;
  bool _uploadingFoto = false;
  // Apakah foto lama sudah ada (dari server)
  bool get _adaFotoLama =>
      widget.item?.foto != null && widget.item!.foto!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final sp = widget.item;
    _namaCtrl = TextEditingController(text: sp?.nama);
    _kodeCtrl = TextEditingController(text: sp?.kode);
    _satuanCtrl = TextEditingController(text: sp?.satuan ?? 'pcs');
    _hargaBeliCtrl = TextEditingController(
        text: sp != null ? '${sp.hargaBeli.toInt()}' : '');
    _hargaJualCtrl = TextEditingController(
        text: sp != null ? '${sp.hargaJual.toInt()}' : '');
    _stokCtrl = TextEditingController(text: sp != null ? '${sp.stok}' : '0');
    _stokMinCtrl =
        TextEditingController(text: sp != null ? '${sp.stokMinimum}' : '5');
    _katId = sp?.kategoriId;
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _kodeCtrl.dispose();
    _satuanCtrl.dispose();
    _hargaBeliCtrl.dispose();
    _hargaJualCtrl.dispose();
    _stokCtrl.dispose();
    _stokMinCtrl.dispose();
    super.dispose();
  }

  // ── Pilih foto dari file system ───────────────────────────

  Future<void> _pickFoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    setState(() {
      _fotoBytes = file.bytes;
      _fotoNama = file.name;
    });
  }

  // ── Simpan data ───────────────────────────────────────────

  Future<void> _save() async {
    final isEdit = widget.item != null;
    final nama = _namaCtrl.text.trim();
    final kode = _kodeCtrl.text.trim();
    if (nama.isEmpty || kode.isEmpty) {
      widget.onError('Nama dan kode wajib diisi');
      return;
    }

    final hargaBeli = double.tryParse(_hargaBeliCtrl.text.trim());
    final hargaJual = double.tryParse(_hargaJualCtrl.text.trim());

    if (hargaBeli == null || hargaBeli < 0) {
      widget.onError('Harga beli tidak valid');
      return;
    }
    if (hargaJual == null || hargaJual <= 0) {
      widget.onError('Harga jual wajib diisi dan harus lebih dari 0');
      return;
    }
    if (hargaJual <= hargaBeli) {
      widget.onError('Harga jual harus lebih besar dari harga beli');
      return;
    }

    setState(() => _saving = true);

    // 1. Simpan data utama
    final payload = {
      'nama': nama,
      'kode': kode,
      'satuan':
          _satuanCtrl.text.trim().isEmpty ? 'pcs' : _satuanCtrl.text.trim(),
      'harga_beli': hargaBeli,
      'harga_jual': hargaJual,
      'stok': int.tryParse(_stokCtrl.text) ?? 0,
      'stok_minimum': int.tryParse(_stokMinCtrl.text) ?? 5,
      if (_katId != null) 'kategori_id': _katId,
    };

    final res = isEdit
        ? await widget.svc.editSparepart(widget.item!.id, payload)
        : await widget.svc.tambahSparepart(payload);

    if (!mounted) return;

    if (res['success'] != true) {
      setState(() => _saving = false);
      widget.onError(res['message'] ?? 'Gagal menyimpan');
      return;
    }

    // 2. Upload foto jika ada file baru
    if (_fotoBytes != null && _fotoNama != null) {
      final sparepartId =
          isEdit ? widget.item!.id : (res['data']?['id'] as num?)?.toInt() ?? 0;

      if (sparepartId > 0) {
        setState(() => _uploadingFoto = true);
        await widget.svc.uploadFotoSparepart(
          sparepartId: sparepartId,
          fileBytes: _fotoBytes!,
          fileName: _fotoNama!,
        );
        if (!mounted) return;
        setState(() => _uploadingFoto = false);
      }
    }

    widget.onSaved(isEdit);
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: SingleChildScrollView(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Header
              Row(children: [
                Expanded(
                  child: Text(
                    isEdit ? 'Edit Sparepart' : 'Tambah Sparepart',
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

              // ── Baris 1: Nama + Kode
              Row(children: [
                Expanded(
                    child: _field('Nama Sparepart', _namaCtrl,
                        hint: 'Nama sparepart', required: true)),
                const SizedBox(width: 12),
                Expanded(
                    child: _field('Kode', _kodeCtrl,
                        hint: 'Kode unik', required: true)),
              ]),
              const SizedBox(height: 14),

              // ── Baris 2: Satuan + Kategori
              Row(children: [
                Expanded(
                    child: _field('Satuan', _satuanCtrl,
                        hint: 'pcs, ltr, set...')),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FieldLabel('Kategori'),
                        DropdownButtonFormField<int?>(
                          initialValue: _katId,
                          decoration:
                              const InputDecoration(hintText: 'Pilih kategori'),
                          items: [
                            const DropdownMenuItem(
                                value: null, child: Text('— Tanpa kategori —')),
                            ...widget.kategori.map((k) => DropdownMenuItem(
                                value: k.id, child: Text(k.nama))),
                          ],
                          onChanged: (v) => setState(() => _katId = v),
                        ),
                      ]),
                ),
              ]),
              const SizedBox(height: 14),

              // ── Baris 3: Harga Beli + Harga Jual
              Row(children: [
                Expanded(
                    child: _field('Harga Beli (Rp)', _hargaBeliCtrl,
                        hint: '0', numeric: true)),
                const SizedBox(width: 12),
                Expanded(
                    child: _field('Harga Jual (Rp)', _hargaJualCtrl,
                        hint: '0', numeric: true)),
              ]),
              const SizedBox(height: 14),

              // ── Baris 4: Stok Awal + Stok Minimum
              Row(children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FieldLabel('Stok Awal'),
                        TextField(
                          controller: _stokCtrl,
                          keyboardType: TextInputType.number,
                          readOnly: isEdit,
                          decoration: InputDecoration(
                            hintText: '0',
                            helperText: isEdit
                                ? 'Stok diubah lewat pembelian stok'
                                : null,
                          ),
                        ),
                      ]),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: _field('Stok Minimum', _stokMinCtrl,
                        hint: '5', numeric: true)),
              ]),
              const SizedBox(height: 14),

              // ── Foto Sparepart ────────────────────────────
              const FieldLabel('Foto Sparepart'),
              const SizedBox(height: 6),
              _buildFotoSection(isEdit),

              const SizedBox(height: 20),

              // ── Tombol aksi
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? Row(mainAxisSize: MainAxisSize.min, children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                          Text(_uploadingFoto
                              ? 'Mengupload foto...'
                              : 'Menyimpan...'),
                        ])
                      : Text(isEdit ? 'Simpan Perubahan' : 'Tambah Sparepart'),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Widget foto ───────────────────────────────────────────

  Widget _buildFotoSection(bool isEdit) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Preview
      _buildPreview(isEdit),
      const SizedBox(width: 14),
      // Info + tombol pilih
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_fotoBytes != null)
            Text(_fotoNama ?? '',
                style: const TextStyle(fontSize: 12, color: Color(0xFF444455)),
                overflow: TextOverflow.ellipsis)
          else if (_adaFotoLama)
            const Text('Foto sudah ada. Pilih file baru untuk menggantinya.',
                style: TextStyle(fontSize: 12, color: Color(0xFF888899)))
          else
            const Text('Belum ada foto. Format: JPG / PNG (maks. 2 MB).',
                style: TextStyle(fontSize: 12, color: Color(0xFF888899))),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _saving ? null : _pickFoto,
            icon: const Icon(Icons.upload_outlined, size: 15),
            label: Text(_adaFotoLama || _fotoBytes != null
                ? 'Ganti Foto'
                : 'Pilih Foto'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _buildPreview(bool isEdit) {
    // Prioritas: file baru yang baru dipilih > foto lama dari server
    if (_fotoBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child:
            Image.memory(_fotoBytes!, width: 72, height: 72, fit: BoxFit.cover),
      );
    }
    if (_adaFotoLama) {
      final url = '${AppConstants.uploadUrl}/${widget.item!.foto}';
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          width: 72,
          height: 72,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _emptyPreview(),
        ),
      );
    }
    return _emptyPreview();
  }

  Widget _emptyPreview() => Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F1F6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFDDDDE8)),
        ),
        child: const Icon(Icons.image_outlined,
            size: 28, color: Color(0xFFCCCCD8)),
      );

  // ── Helper field ──────────────────────────────────────────

  Widget _field(
    String label,
    TextEditingController ctrl, {
    String hint = '',
    bool required = false,
    bool numeric = false,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      FieldLabel(label, required: required),
      TextField(
        controller: ctrl,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(hintText: hint),
      ),
    ]);
  }
}
