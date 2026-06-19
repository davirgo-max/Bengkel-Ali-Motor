import 'package:flutter/material.dart';
import '../../auth/models/user_model.dart';
import '../../auth/services/auth_service.dart';
import '../services/pelanggan_service.dart';
import '../models/pelanggan_models.dart';
import 'form_kendaraan_screen.dart';

class ProfilScreen extends StatefulWidget {
  final UserModel user;
  const ProfilScreen({super.key, required this.user});
  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  Map<String, dynamic>? _profil;
  List<KendaraanModel> _kendaraan = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final svc = PelangganService.instance;
    final p = await svc.getProfil();
    final k = await svc.getKendaraan();
    if (mounted) {
      setState(() {
        _profil =
            p['success'] == true ? p['data'] as Map<String, dynamic> : null;
        _kendaraan = k;
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text('Apakah kamu yakin ingin keluar?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child:
                  const Text('Logout', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await AuthService.instance.logout();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _hapusKendaraan(KendaraanModel k) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Kendaraan?'),
        content: Text('${k.merk} ${k.model} (${k.noPolisi}) akan dihapus.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child:
                  const Text('Hapus', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (ok != true) return;
    final res = await PelangganService.instance.hapusKendaraan(k.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['message'] as String),
        backgroundColor: res['success'] == true ? Colors.green : Colors.red,
      ));
      if (res['success'] == true) _load();
    }
  }

  void _bukaGantiPassword() {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const _GantiPasswordScreen()));
  }

  /// Buka popup untuk isi field yang masih kosong (email atau alamat)
  Future<void> _bukaIsiField(String field, String label) async {
    final ctrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool submitting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                field == 'email'
                    ? Icons.email_outlined
                    : Icons.location_on_outlined,
                color: Colors.blue.shade700,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text('Tambah $label'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Data ini hanya bisa diisi satu kali dan tidak dapat diubah setelah disimpan.',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade700,
                    fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 16),
              Form(
                key: formKey,
                child: TextFormField(
                  controller: ctrl,
                  autofocus: true,
                  keyboardType: field == 'email'
                      ? TextInputType.emailAddress
                      : TextInputType.streetAddress,
                  maxLines: field == 'alamat' ? 3 : 1,
                  decoration: InputDecoration(
                    labelText: label,
                    hintText: field == 'email'
                        ? 'contoh@email.com'
                        : 'Jalan, Kota, Provinsi...',
                    prefixIcon: Icon(
                      field == 'email'
                          ? Icons.email_outlined
                          : Icons.location_on_outlined,
                      color: Colors.blue.shade700,
                    ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          BorderSide(color: Colors.blue.shade700, width: 2),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return '$label wajib diisi';
                    }
                    if (field == 'email' &&
                        !RegExp(r'^[\w\.\+\-]+@[\w\-]+\.[a-zA-Z]{2,}$')
                            .hasMatch(v.trim())) {
                      return 'Format email tidak valid';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: submitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setStateDialog(() => submitting = true);

                      // Kirim hanya field yang diisi — backend akan abaikan field null
                      final Map<String, dynamic> payload = {};
                      payload[field] = ctrl.text.trim();

                      final res =
                          await PelangganService.instance.updateProfil(payload);

                      if (!mounted) return;
                      setStateDialog(() => submitting = false);

                      Navigator.pop(ctx);

                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(res['message'] as String? ?? ''),
                        backgroundColor:
                            res['success'] == true ? Colors.green : Colors.red,
                      ));

                      if (res['success'] == true) _load();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Profil'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: _logout),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Avatar & nama ──────────────────
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 38,
                          backgroundColor: Colors.blue.shade100,
                          child: Text(
                            (_profil?['nama'] as String? ?? widget.user.nama)[0]
                                .toUpperCase(),
                            style: TextStyle(
                                fontSize: 30,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _profil?['nama'] as String? ?? widget.user.nama,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _profil?['no_hp'] as String? ?? '',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Data Akun ──────────────────────
                  _sectionLabel('Data Akun'),
                  _profilCard(),
                  const SizedBox(height: 8),
                  _menuTile(
                      Icons.lock_outline, 'Ganti Password', _bukaGantiPassword),
                  const SizedBox(height: 20),

                  // ── Kendaraan ──────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _sectionLabel('Kendaraan Saya'),
                      TextButton.icon(
                        onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const FormKendaraanScreen()))
                            .then((_) => _load()),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Tambah'),
                      ),
                    ],
                  ),
                  if (_kendaraan.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Belum ada kendaraan terdaftar.',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    )
                  else
                    ..._kendaraan.map((k) => _KendaraanTile(
                          kendaraan: k,
                          onHapus: () => _hapusKendaraan(k),
                        )),
                ],
              ),
            ),
    );
  }

  Widget _sectionLabel(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      );

  Widget _profilCard() {
    if (_profil == null) return const SizedBox();

    final email = _profil!['email'] as String?;
    final alamat = _profil!['alamat'] as String?;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // Nama & No HP — terkunci (tidak bisa diubah)
          _infoRowLocked(
              Icons.person, 'Nama', _profil!['nama'] as String? ?? '-'),
          _infoRowLocked(
              Icons.phone, 'No HP', _profil!['no_hp'] as String? ?? '-'),

          // Email — bisa ditambah jika kosong
          _infoRowEditable(
            icon: Icons.email,
            label: 'Email',
            value: email,
            onAdd: (email == null || email.isEmpty)
                ? () => _bukaIsiField('email', 'Email')
                : null,
          ),

          // Alamat — bisa ditambah jika kosong
          _infoRowEditable(
            icon: Icons.location_on,
            label: 'Alamat',
            value: alamat,
            onAdd: (alamat == null || alamat.isEmpty)
                ? () => _bukaIsiField('alamat', 'Alamat')
                : null,
          ),
        ],
      ),
    );
  }

  /// Row untuk data yang terkunci (nama, no hp)
  Widget _infoRowLocked(IconData icon, String label, String value) => ListTile(
        dense: true,
        leading: Icon(icon, color: Colors.blue.shade700, size: 20),
        title: Text(label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        subtitle: Text(value,
            style: const TextStyle(fontSize: 14, color: Colors.black87)),
        trailing:
            Icon(Icons.lock_outline, size: 16, color: Colors.grey.shade400),
      );

  /// Row untuk data yang bisa ditambah jika masih kosong (email, alamat)
  Widget _infoRowEditable({
    required IconData icon,
    required String label,
    required String? value,
    required VoidCallback? onAdd, // null = sudah terisi, tidak bisa edit
  }) {
    final isEmpty = value == null || value.isEmpty;

    return ListTile(
      dense: true,
      leading: Icon(icon, color: Colors.blue.shade700, size: 20),
      title: Text(label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      subtitle: isEmpty
          ? Text('Belum diisi',
              style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade400,
                  fontStyle: FontStyle.italic))
          : Text(value,
              style: const TextStyle(fontSize: 14, color: Colors.black87)),
      trailing: isEmpty
          ? Tooltip(
              message: 'Tambah $label',
              child: InkWell(
                onTap: onAdd,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Icon(Icons.edit_outlined,
                      size: 16, color: Colors.blue.shade700),
                ),
              ),
            )
          : Icon(Icons.lock_outline, size: 16, color: Colors.grey.shade400),
    );
  }

  Widget _menuTile(IconData icon, String label, VoidCallback onTap) => Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: Icon(icon, color: Colors.blue.shade700),
          title: Text(label),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );
}

// ── Kendaraan tile ────────────────────────────────────────
class _KendaraanTile extends StatelessWidget {
  final KendaraanModel kendaraan;
  final VoidCallback onHapus;
  const _KendaraanTile({required this.kendaraan, required this.onHapus});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.two_wheeler, color: Colors.blue.shade700),
        ),
        title: Text('${kendaraan.merk} ${kendaraan.model}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          [
            kendaraan.noPolisi,
            if (kendaraan.warna != null) kendaraan.warna!,
            if (kendaraan.tahun != null) '${kendaraan.tahun}',
          ].join(' • '),
          style: const TextStyle(fontSize: 12),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: onHapus,
        ),
      ),
    );
  }
}

// ── Halaman Ganti Password ────────────────────────────────
class _GantiPasswordScreen extends StatefulWidget {
  const _GantiPasswordScreen();
  @override
  State<_GantiPasswordScreen> createState() => _GantiPasswordScreenState();
}

class _GantiPasswordScreenState extends State<_GantiPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confCtrl = TextEditingController();

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConf = true;
  bool _submitting = false;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final res = await PelangganService.instance.gantiPassword(
      passLama: _oldCtrl.text,
      passBaru: _newCtrl.text,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res['message'] as String? ?? ''),
      backgroundColor: res['success'] == true ? Colors.green : Colors.red,
    ));

    if (res['success'] == true) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Ganti Password'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          24,
          20,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Masukkan password lama dan password baru kamu.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              _passField(
                ctrl: _oldCtrl,
                label: 'Password Lama',
                obscure: _obscureOld,
                toggle: () => setState(() => _obscureOld = !_obscureOld),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              _passField(
                ctrl: _newCtrl,
                label: 'Password Baru',
                obscure: _obscureNew,
                toggle: () => setState(() => _obscureNew = !_obscureNew),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Wajib diisi';
                  if (v.length < 6) return 'Minimal 6 karakter';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _passField(
                ctrl: _confCtrl,
                label: 'Konfirmasi Password Baru',
                obscure: _obscureConf,
                toggle: () => setState(() => _obscureConf = !_obscureConf),
                validator: (v) =>
                    v != _newCtrl.text ? 'Password tidak cocok' : null,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Text('Simpan Password',
                          style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _passField({
    required TextEditingController ctrl,
    required String label,
    required bool obscure,
    required VoidCallback toggle,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(Icons.lock_outline, color: Colors.blue.shade700),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: toggle,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      validator: validator,
    );
  }
}
