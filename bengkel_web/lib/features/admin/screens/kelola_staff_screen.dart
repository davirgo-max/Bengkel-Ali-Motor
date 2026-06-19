// lib/features/admin/screens/kelola_staff_screen.dart

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

class KelolaStaffScreen extends StatefulWidget {
  const KelolaStaffScreen({super.key});

  @override
  State<KelolaStaffScreen> createState() => _KelolaStaffScreenState();
}

class _KelolaStaffScreenState extends State<KelolaStaffScreen> {
  final _svc = AdminService.instance;
  final _searchCtrl = TextEditingController();

  int _tab = 0; // 0 = Owner, 1 = Kasir
  OwnerInfoModel? _owner;
  List<AkunKasirModel> _kasir = [];
  bool _loading = true;

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
    final ownerRes = await _svc.getOwnerInfo();
    final kasirList = await _svc.getAkunKasir();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _owner = ownerRes['success'] == true && ownerRes['data'] != null
          ? OwnerInfoModel.fromJson(ownerRes['data'] as Map<String, dynamic>)
          : null;
      _kasir = kasirList;
    });
  }

  List<AkunKasirModel> get _filteredKasir {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _kasir;
    return _kasir
        .where((k) =>
            k.nama.toLowerCase().contains(q) ||
            k.username.toLowerCase().contains(q))
        .toList();
  }

  // ── Reset password ────────────────────────────────────────
  // FIX: pakai StatefulWidget terpisah (_ResetPasswordDialog) agar
  // dispose controller tidak bentrok dengan animasi penutupan dialog
  // (sumber Assertion error _dependents.isEmpty).

  Future<void> _resetPasswordDialog({
    required String namaAkun,
    required Future<Map<String, dynamic>> Function(String passwordBaru) onSubmit,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => _ResetPasswordDialog(
        namaAkun: namaAkun,
        onSubmit: onSubmit,
        onSuccess: (msg) {
          Navigator.pop(ctx);
          messenger.showSnackBar(SnackBar(
            content: Text(msg),
            behavior: SnackBarBehavior.floating,
          ));
        },
        onError: (msg) => showAppSnackBar(ctx, msg, error: true),
      ),
    );
  }

  // ── Tambah kasir ──────────────────────────────────────────
  // FIX: sama — pakai StatefulWidget terpisah (_TambahKasirDialog).

  Future<void> _showTambahKasirDialog() async {
    final messenger = ScaffoldMessenger.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => _TambahKasirDialog(
        svc: _svc,
        onSaved: () {
          Navigator.pop(ctx);
          _load();
          messenger.showSnackBar(const SnackBar(
            content: Text('Akun kasir ditambahkan'),
            behavior: SnackBarBehavior.floating,
          ));
        },
        onError: (msg) => showAppSnackBar(ctx, msg, error: true),
      ),
    );
  }

  // ── Toggle aktif kasir ────────────────────────────────────

  Future<void> _toggleAktifKasir(AkunKasirModel k) async {
    final aktifkan = !k.isAktif;
    final ok = await showConfirmDialog(
      context,
      title: aktifkan ? 'Aktifkan Akun?' : 'Nonaktifkan Akun?',
      message: aktifkan
          ? '${k.nama} akan bisa login kembali.'
          : '${k.nama} tidak akan bisa login sampai diaktifkan lagi.',
      confirmText: aktifkan ? 'Aktifkan' : 'Nonaktifkan',
      danger: !aktifkan,
    );
    if (!ok || !mounted) return;
    final res = await _svc.toggleAktifKasir(k.id, aktifkan);
    if (!mounted) return;
    if (res['success'] == true) {
      _load();
      showAppSnackBar(context, res['message'] ?? 'Status diperbarui');
    } else {
      showAppSnackBar(context, res['message'] ?? 'Gagal mengubah status',
          error: true);
    }
  }

  Future<void> _hapusKasir(AkunKasirModel k) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Hapus Akun Kasir?',
      message:
          'Akun "${k.nama}" akan dihapus permanen. Tidak bisa dihapus jika sudah punya riwayat transaksi.',
      confirmText: 'Hapus',
      danger: true,
    );
    if (!ok || !mounted) return;
    final res = await _svc.hapusKasir(k.id);
    if (!mounted) return;
    if (res['success'] == true) {
      _load();
      showAppSnackBar(context, 'Akun kasir dihapus');
    } else {
      showAppSnackBar(context, res['message'] ?? 'Gagal menghapus',
          error: true);
    }
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      currentRoute: '/admin/akun',
      pageTitle: 'Kelola Akun Staff',
      actions: _tab == 1
          ? [
              TopbarButton(
                label: 'Tambah Kasir',
                icon: Icons.add,
                primary: true,
                onPressed: _showTambahKasirDialog,
              ),
            ]
          : const [],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _tabBtn('Owner', 0),
          const SizedBox(width: 6),
          _tabBtn('Kasir', 1),
        ]),
        const SizedBox(height: 16),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_tab == 0)
          _ownerTab()
        else
          _kasirTab(),
      ]),
    );
  }

  Widget _tabBtn(String label, int idx) {
    final active = _tab == idx;
    return OutlinedButton(
      onPressed: () => setState(() => _tab = idx),
      style: OutlinedButton.styleFrom(
        backgroundColor: active ? AppTheme.primary : null,
        foregroundColor: active ? Colors.white : null,
        side: BorderSide(
            color: active ? AppTheme.primary : const Color(0xFFDDDDE8)),
      ),
      child: Text(label),
    );
  }

  Widget _ownerTab() {
    if (_owner == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Data akun owner tidak ditemukan.'),
        ),
      );
    }
    final o = _owner!;
    final colors = avatarColorFor(o.nama);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: colors[0],
            child: Text(initialsOf(o.nama),
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: colors[1])),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o.nama,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 14)),
                Text('@${o.username} · Owner',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF888899))),
              ],
            ),
          ),
          const BadgePill(text: 'Owner', color: PillColor.amber),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: () => _resetPasswordDialog(
              namaAkun: o.nama,
              onSubmit: _svc.resetPasswordOwner,
            ),
            icon: const Icon(Icons.lock_reset, size: 16),
            label: const Text('Reset Password'),
          ),
        ]),
      ),
    );
  }

  Widget _kasirTab() {
    final filtered = _filteredKasir;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            SearchField(
              hint: 'Cari nama / username kasir...',
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              maxWidth: 300,
            ),
            const Spacer(),
            Text('${filtered.length} akun',
                style: const TextStyle(fontSize: 12, color: Color(0xFF888899))),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: filtered.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(48),
                child: Center(
                    child: Text('Belum ada akun kasir.',
                        style: TextStyle(color: Color(0xFF888899)))))
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('NAMA')),
                    DataColumn(label: Text('USERNAME')),
                    DataColumn(label: Text('DIBUAT')),
                    DataColumn(label: Text('STATUS')),
                    DataColumn(label: Text('AKSI')),
                  ],
                  rows: filtered.map((k) {
                    return DataRow(cells: [
                      DataCell(Text(k.nama,
                          style: const TextStyle(fontWeight: FontWeight.w500))),
                      DataCell(Text('@${k.username}')),
                      DataCell(Text(formatTanggal(k.createdAt))),
                      DataCell(BadgePill(
                        text: k.isAktif ? 'Aktif' : 'Non-aktif',
                        color: k.isAktif ? PillColor.green : PillColor.grey,
                      )),
                      DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                          icon: const Icon(Icons.lock_reset, size: 17),
                          tooltip: 'Reset Password',
                          color: AppTheme.primary,
                          onPressed: () => _resetPasswordDialog(
                            namaAkun: k.nama,
                            onSubmit: (p) =>
                                _svc.resetPasswordKasir(k.id, p),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                              k.isAktif
                                  ? Icons.power_settings_new
                                  : Icons.check_circle_outline,
                              size: 17),
                          tooltip: k.isAktif ? 'Nonaktifkan' : 'Aktifkan',
                          color: k.isAktif
                              ? const Color(0xFFA32D2D)
                              : const Color(0xFF0F6E56),
                          onPressed: () => _toggleAktifKasir(k),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 17),
                          tooltip: 'Hapus',
                          color: const Color(0xFFA32D2D),
                          onPressed: () => _hapusKasir(k),
                        ),
                      ])),
                    ]);
                  }).toList(),
                ),
              ),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Dialog Reset Password — StatefulWidget terpisah
// ══════════════════════════════════════════════════════════════════════════════

class _ResetPasswordDialog extends StatefulWidget {
  final String namaAkun;
  final Future<Map<String, dynamic>> Function(String passwordBaru) onSubmit;
  final void Function(String msg) onSuccess;
  final void Function(String msg) onError;

  const _ResetPasswordDialog({
    required this.namaAkun,
    required this.onSubmit,
    required this.onSuccess,
    required this.onError,
  });

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  late final TextEditingController _passCtrl;
  late final TextEditingController _konfirmasiCtrl;
  bool _saving = false;
  bool _showPass = false;
  bool _showKonfirmasi = false;

  @override
  void initState() {
    super.initState();
    _passCtrl = TextEditingController();
    _konfirmasiCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _passCtrl.dispose();
    _konfirmasiCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final pass = _passCtrl.text.trim();
    final konfirmasi = _konfirmasiCtrl.text.trim();
    if (pass.length < 6) {
      widget.onError('Password minimal 6 karakter');
      return;
    }
    if (pass != konfirmasi) {
      widget.onError('Konfirmasi password tidak cocok');
      return;
    }
    setState(() => _saving = true);
    final res = await widget.onSubmit(pass);
    if (!mounted) return;
    if (res['success'] == true) {
      widget.onSuccess(res['message'] ?? 'Password direset');
    } else {
      setState(() => _saving = false);
      widget.onError(res['message'] ?? 'Gagal mereset password');
    }
  }

  @override
  Widget build(BuildContext context) {
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
              Row(children: [
                Expanded(
                  child: Text(
                    'Reset Password — ${widget.namaAkun}',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
                InkWell(
                  onTap: _saving ? null : () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 20, color: Color(0xFF888899)),
                  ),
                ),
              ]),
              const SizedBox(height: 18),
              const FieldLabel('Password Baru', required: true),
              TextField(
                controller: _passCtrl,
                obscureText: !_showPass,
                decoration: InputDecoration(
                  hintText: 'Minimal 6 karakter',
                  suffixIcon: IconButton(
                    icon: Icon(
                        _showPass ? Icons.visibility_off : Icons.visibility,
                        size: 18),
                    onPressed: () => setState(() => _showPass = !_showPass),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const FieldLabel('Konfirmasi Password', required: true),
              TextField(
                controller: _konfirmasiCtrl,
                obscureText: !_showKonfirmasi,
                decoration: InputDecoration(
                  hintText: 'Ulangi password baru',
                  suffixIcon: IconButton(
                    icon: Icon(
                        _showKonfirmasi
                            ? Icons.visibility_off
                            : Icons.visibility,
                        size: 18),
                    onPressed: () =>
                        setState(() => _showKonfirmasi = !_showKonfirmasi),
                  ),
                ),
              ),
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
                      : const Text('Reset Password'),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Dialog Tambah Kasir — StatefulWidget terpisah
// ══════════════════════════════════════════════════════════════════════════════

class _TambahKasirDialog extends StatefulWidget {
  final AdminService svc;
  final VoidCallback onSaved;
  final void Function(String msg) onError;

  const _TambahKasirDialog({
    required this.svc,
    required this.onSaved,
    required this.onError,
  });

  @override
  State<_TambahKasirDialog> createState() => _TambahKasirDialogState();
}

class _TambahKasirDialogState extends State<_TambahKasirDialog> {
  late final TextEditingController _namaCtrl;
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _passCtrl;
  late final TextEditingController _konfirmasiCtrl;
  bool _saving = false;
  bool _showPass = false;
  bool _showKonfirmasi = false;

  @override
  void initState() {
    super.initState();
    _namaCtrl = TextEditingController();
    _usernameCtrl = TextEditingController();
    _passCtrl = TextEditingController();
    _konfirmasiCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _usernameCtrl.dispose();
    _passCtrl.dispose();
    _konfirmasiCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nama = _namaCtrl.text.trim();
    final username = _usernameCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    final konfirmasi = _konfirmasiCtrl.text.trim();
    if (nama.isEmpty || username.isEmpty) {
      widget.onError('Nama dan username wajib diisi');
      return;
    }
    if (pass.length < 6) {
      widget.onError('Password minimal 6 karakter');
      return;
    }
    if (pass != konfirmasi) {
      widget.onError('Konfirmasi password tidak cocok');
      return;
    }
    setState(() => _saving = true);
    final res =
        await widget.svc.tambahKasir(nama: nama, username: username, password: pass);
    if (!mounted) return;
    if (res['success'] == true) {
      widget.onSaved();
    } else {
      setState(() => _saving = false);
      widget.onError(res['message'] ?? 'Gagal menambah kasir');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 460,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Expanded(
                    child: Text('Tambah Akun Kasir',
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
                const SizedBox(height: 18),
                const FieldLabel('Nama', required: true),
                TextField(
                    controller: _namaCtrl,
                    decoration:
                        const InputDecoration(hintText: 'Nama lengkap')),
                const SizedBox(height: 14),
                const FieldLabel('Username', required: true),
                TextField(
                    controller: _usernameCtrl,
                    decoration:
                        const InputDecoration(hintText: 'mis. sari.dewi')),
                const SizedBox(height: 14),
                const FieldLabel('Password', required: true),
                TextField(
                  controller: _passCtrl,
                  obscureText: !_showPass,
                  decoration: InputDecoration(
                    hintText: 'Minimal 6 karakter',
                    suffixIcon: IconButton(
                      icon: Icon(
                          _showPass ? Icons.visibility_off : Icons.visibility,
                          size: 18),
                      onPressed: () => setState(() => _showPass = !_showPass),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const FieldLabel('Konfirmasi Password', required: true),
                TextField(
                  controller: _konfirmasiCtrl,
                  obscureText: !_showKonfirmasi,
                  decoration: InputDecoration(
                    hintText: 'Ulangi password',
                    suffixIcon: IconButton(
                      icon: Icon(
                          _showKonfirmasi
                              ? Icons.visibility_off
                              : Icons.visibility,
                          size: 18),
                      onPressed: () =>
                          setState(() => _showKonfirmasi = !_showKonfirmasi),
                    ),
                  ),
                ),
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
                        : const Text('Tambah Kasir'),
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
