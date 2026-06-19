import 'dart:async';
import 'package:flutter/material.dart';
import '../services/kasir_service.dart';
import '../models/kasir_models.dart';
import '../../../core/utils/currency_format.dart';

class FormWalkInScreen extends StatefulWidget {
  const FormWalkInScreen({super.key});
  @override
  State<FormWalkInScreen> createState() => _FormWalkInScreenState();
}

class _FormWalkInScreenState extends State<FormWalkInScreen> {
  final _formKey = GlobalKey<FormState>();

  // Step: 0=cari pelanggan, 1=data kendaraan, 2=detail servis
  int _step = 0;
  bool _submitting = false;

  // Pelanggan
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  final _namaCtrl = TextEditingController();
  final _hpCtrl = TextEditingController();
  bool _pelangganBaru = false;
  Map<String, dynamic>? _pelangganDipilih;
  List<Map<String, dynamic>> _hasilCari = [];
  bool _mencari = false;

  // Kendaraan
  final _merkCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _polisiCtrl = TextEditingController();
  final _warnaCtrl = TextEditingController();
  List<Map<String, dynamic>> _kendaraanPelanggan = [];
  Map<String, dynamic>? _kendaraanDipilih;
  bool _kendaraanBaru = false;

  // Servis
  String? _jenisServisId;
  List<Map<String, dynamic>> _jenisServisList = [];
  final _keluhanCtrl = TextEditingController();

  // Sparepart walk-in
  final _sparepartSearchCtrl = TextEditingController();
  Timer? _sparepartDebounce;
  List<SparepartCariModel> _hasilCariSparepart = [];
  bool _mencariSparepart = false;
  // Keranjang sparepart: Map<sparepartId, KeranjangItem>
  final Map<int, KeranjangItem> _keranjangSparepart = {};

  @override
  void initState() {
    super.initState();
    _loadJenisServis();
  }

  Future<void> _loadJenisServis() async {
    final list = await KasirService.instance.getJenisServis();
    if (!mounted) return;
    setState(() => _jenisServisList = list);
  }

  Future<void> _pilihPelanggan(Map<String, dynamic> p) async {
    setState(() {
      _pelangganDipilih = p;
      _kendaraanPelanggan = [];
      _kendaraanDipilih = null;
      _kendaraanBaru = false;
    });

    final id = p['id'];
    if (id == null) return;

    final res = await KasirService.instance.getDetailPelanggan(id as int);
    if (!mounted) return;

    final rawKendaraan = res['data']?['kendaraan'];
    if (rawKendaraan is List && rawKendaraan.isNotEmpty) {
      setState(() {
        _kendaraanPelanggan = List<Map<String, dynamic>>.from(rawKendaraan);
        // Auto-pilih kalau hanya ada 1 kendaraan
        if (_kendaraanPelanggan.length == 1) {
          _kendaraanDipilih = _kendaraanPelanggan.first;
        }
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _sparepartDebounce?.cancel();
    for (final c in [
      _searchCtrl,
      _namaCtrl,
      _hpCtrl,
      _merkCtrl,
      _modelCtrl,
      _polisiCtrl,
      _warnaCtrl,
      _keluhanCtrl,
      _sparepartSearchCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Walk-in Baru'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ── Step indicator ─────────────────────────
          _StepIndicator(current: _step, steps: const [
            'Pelanggan',
            'Kendaraan',
            'Servis',
          ]),
          const Divider(height: 1),

          // ── Konten per step ────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Form(
                key: _formKey,
                child: _step == 0
                    ? _stepPelanggan()
                    : _step == 1
                        ? _stepKendaraan()
                        : _stepServis(),
              ),
            ),
          ),

          // ── Navigasi step ──────────────────────────
          _buildNavBar(),
        ],
      ),
    );
  }

  // ── STEP 0: Pelanggan ─────────────────────────────────
  Widget _stepPelanggan() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toggle: cari atau baru
        Row(
          children: [
            _ToggleChip(
              label: 'Cari Pelanggan',
              active: !_pelangganBaru,
              onTap: () => setState(() {
                _pelangganBaru = false;
                _pelangganDipilih = null;
                _hasilCari = [];
              }),
            ),
            const SizedBox(width: 8),
            _ToggleChip(
              label: 'Pelanggan Baru',
              active: _pelangganBaru,
              onTap: () => setState(() {
                _pelangganBaru = true;
                _pelangganDipilih = null;
              }),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (!_pelangganBaru) ...[
          // Cari pelanggan
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Cari nama / no HP pelanggan...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _mencari
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onChanged: (v) {
              if (v.trim().length < 2) {
                _debounce?.cancel();
                setState(() {
                  _hasilCari = [];
                  _mencari = false;
                });
                return;
              }
              setState(() => _mencari = true);
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 500), () async {
                final keyword = v.trim();
                if (!mounted) return;
                final res = await KasirService.instance.cariPelanggan(keyword);
                if (!mounted) return;
                setState(() {
                  _hasilCari = res['success'] == true
                      ? List<Map<String, dynamic>>.from(
                          res['data'] as List? ?? [])
                      : [];
                  _mencari = false;
                });
              });
            },
          ),
          const SizedBox(height: 12),

          if (_hasilCari.isEmpty && _searchCtrl.text.isNotEmpty)
            const _InfoBox(
              icon: Icons.person_off,
              color: Colors.orange,
              msg: 'Pelanggan tidak ditemukan. Gunakan "Pelanggan Baru".',
            )
          else
            ..._hasilCari.map((p) => _PelangganTile(
                  data: p,
                  selected: _pelangganDipilih?['id'] == p['id'],
                  onTap: () => _pilihPelanggan(p),
                )),

          if (_pelangganDipilih != null) ...[
            const SizedBox(height: 12),
            _InfoBox(
              icon: Icons.check_circle,
              color: Colors.green,
              msg: '✅ ${_pelangganDipilih!['nama']} dipilih.',
            ),
          ],
        ] else ...[
          // Form pelanggan baru
          _field(_namaCtrl, 'Nama Lengkap', Icons.person, req: true),
          const SizedBox(height: 12),
          _field(_hpCtrl, 'No HP', Icons.phone,
              req: true, type: TextInputType.phone),
        ],
      ],
    );
  }

  // ── STEP 1: Kendaraan ─────────────────────────────────
  Widget _stepKendaraan() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_kendaraanPelanggan.isNotEmpty) ...[
          Row(
            children: [
              _ToggleChip(
                label: 'Kendaraan Tersimpan',
                active: !_kendaraanBaru,
                onTap: () => setState(() => _kendaraanBaru = false),
              ),
              const SizedBox(width: 8),
              _ToggleChip(
                label: 'Kendaraan Baru',
                active: _kendaraanBaru,
                onTap: () => setState(() {
                  _kendaraanBaru = true;
                  _kendaraanDipilih = null;
                }),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!_kendaraanBaru)
            ..._kendaraanPelanggan.map((k) => _KendaraanTile(
                  data: k,
                  selected: _kendaraanDipilih?['id'] == k['id'],
                  onTap: () => setState(() => _kendaraanDipilih = k),
                )),
          const SizedBox(height: 8),
        ],
        if (_kendaraanBaru || _kendaraanPelanggan.isEmpty) ...[
          if (_kendaraanPelanggan.isNotEmpty) const SizedBox(height: 8),
          _field(_merkCtrl, 'Merk', Icons.label, req: true),
          const SizedBox(height: 12),
          _field(_modelCtrl, 'Model', Icons.two_wheeler, req: true),
          const SizedBox(height: 12),
          _field(_polisiCtrl, 'No Polisi', Icons.credit_card,
              req: true, upper: true),
          const SizedBox(height: 12),
          _field(_warnaCtrl, 'Warna', Icons.color_lens),
        ],
      ],
    );
  }

  // ── STEP 2: Servis ────────────────────────────────────
  Widget _stepServis() {
    final totalPart = _keranjangSparepart.values
        .fold<double>(0, (sum, item) => sum + item.subtotal);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ringkasan pilihan sebelumnya
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.indigo.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ringkasan',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              _summRow(
                  'Pelanggan',
                  _pelangganBaru
                      ? _namaCtrl.text
                      : _pelangganDipilih?['nama'] ?? '-'),
              _summRow(
                  'Kendaraan',
                  _kendaraanBaru || _kendaraanPelanggan.isEmpty
                      ? '${_merkCtrl.text} ${_modelCtrl.text} • ${_polisiCtrl.text}'
                      : '${_kendaraanDipilih?['merk']} ${_kendaraanDipilih?['model']} • ${_kendaraanDipilih?['no_polisi']}'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Jenis servis
        const Text('Jenis Servis (opsional)',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          initialValue: _jenisServisId,
          isExpanded: true,
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.build, color: Colors.indigo.shade700),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('-- Belum tahu / konsultasi dulu --'),
            ),
            ..._jenisServisList.map(
              (j) => DropdownMenuItem(
                value: j['id'].toString(),
                child: Text(j['nama'] as String),
              ),
            ),
          ],
          onChanged: (v) => setState(() => _jenisServisId = v),
        ),
        const SizedBox(height: 16),

        // Keluhan
        const Text('Keluhan / Keterangan (opsional)',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _keluhanCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Deskripsikan masalah kendaraan...',
            prefixIcon: Icon(Icons.notes, color: Colors.indigo.shade700),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 20),

        // ── Sparepart (opsional) ──────────────────────
        Row(
          children: [
            Icon(Icons.inventory_2, color: Colors.indigo.shade700, size: 18),
            const SizedBox(width: 6),
            const Text('Sparepart (opsional)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Langsung tambahkan sparepart yang akan digunakan.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 10),

        // Cari sparepart
        TextField(
          controller: _sparepartSearchCtrl,
          decoration: InputDecoration(
            hintText: 'Cari nama / kode sparepart...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _mencariSparepart
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : (_sparepartSearchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _sparepartSearchCtrl.clear();
                          setState(() => _hasilCariSparepart = []);
                        },
                      )
                    : null),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onChanged: (v) {
            if (v.trim().length < 2) {
              _sparepartDebounce?.cancel();
              setState(() {
                _hasilCariSparepart = [];
                _mencariSparepart = false;
              });
              return;
            }
            setState(() => _mencariSparepart = true);
            _sparepartDebounce?.cancel();
            _sparepartDebounce =
                Timer(const Duration(milliseconds: 400), () async {
              if (!mounted) return;
              final results =
                  await KasirService.instance.cariSparepart(v.trim());
              if (!mounted) return;
              setState(() {
                _hasilCariSparepart = results;
                _mencariSparepart = false;
              });
            });
          },
        ),
        const SizedBox(height: 8),

        // Hasil cari sparepart
        if (_hasilCariSparepart.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: _hasilCariSparepart.map((sp) {
                final sudahAda = _keranjangSparepart.containsKey(sp.id);
                final stokHabis = sp.stok <= 0;
                return ListTile(
                  dense: true,
                  title: Text(sp.nama,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '${sp.kode} • Stok: ${sp.stok} ${sp.satuan} • ${formatRupiah(sp.hargaJual)}',
                    style: TextStyle(
                        fontSize: 11,
                        color: stokHabis ? Colors.red : Colors.grey.shade600),
                  ),
                  trailing: stokHabis
                      ? Text('Habis',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.red.shade400,
                              fontWeight: FontWeight.w500))
                      : sudahAda
                          ? Icon(Icons.check_circle,
                              color: Colors.green.shade600, size: 22)
                          : IconButton(
                              icon: Icon(Icons.add_circle,
                                  color: Colors.indigo.shade700),
                              onPressed: () => _tambahKeKeranjang(sp),
                            ),
                  onTap: (!stokHabis && !sudahAda)
                      ? () => _tambahKeKeranjang(sp)
                      : null,
                );
              }).toList(),
            ),
          ),

        // Keranjang sparepart
        if (_keranjangSparepart.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                  child: Text(
                    'Sparepart dipilih (${_keranjangSparepart.length} item)',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.green.shade800),
                  ),
                ),
                const Divider(height: 1),
                ..._keranjangSparepart.values.map((item) => _KeranjangTile(
                      item: item,
                      onTambah: () => _ubahJumlah(item.sparepartId, 1),
                      onKurang: () => _ubahJumlah(item.sparepartId, -1),
                      onHapus: () => _hapusDariKeranjang(item.sparepartId),
                    )),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Estimasi Part',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(
                        formatRupiah(totalPart),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.green.shade700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),

        // Tombol submit
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : const Icon(Icons.play_circle),
            label: const Text('Mulai Servis Walk-in',
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
    );
  }

  // ── Keranjang sparepart helpers ────────────────────────
  void _tambahKeKeranjang(SparepartCariModel sp) {
    setState(() {
      if (_keranjangSparepart.containsKey(sp.id)) return;
      _keranjangSparepart[sp.id] = KeranjangItem.fromSparepart(sp);
      // Collapse hasil cari setelah ditambah
      _sparepartSearchCtrl.clear();
      _hasilCariSparepart = [];
    });
  }

  void _ubahJumlah(int sparepartId, int delta) {
    setState(() {
      final item = _keranjangSparepart[sparepartId];
      if (item == null) return;
      final baru = item.jumlah + delta;
      if (baru <= 0) {
        _keranjangSparepart.remove(sparepartId);
      } else if (baru <= item.stokTersedia) {
        item.jumlah = baru;
      } else {
        _snack('Stok tidak cukup (tersedia: ${item.stokTersedia})');
      }
    });
  }

  void _hapusDariKeranjang(int sparepartId) {
    setState(() => _keranjangSparepart.remove(sparepartId));
  }

  // ── Nav bar bawah ─────────────────────────────────────
  Widget _buildNavBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black12, blurRadius: 8, offset: Offset(0, -2)),
        ],
      ),
      child: Row(
        children: [
          if (_step > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _step--),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Kembali'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.indigo.shade700,
                  side: BorderSide(color: Colors.indigo.shade700),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          if (_step > 0) const SizedBox(width: 12),
          if (_step < 2)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _nextStep,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Lanjut'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _nextStep() {
    if (_step == 0) {
      if (!_pelangganBaru && _pelangganDipilih == null) {
        _snack('Pilih pelanggan atau gunakan "Pelanggan Baru"');
        return;
      }
      if (_pelangganBaru) {
        if (_namaCtrl.text.trim().isEmpty || _hpCtrl.text.trim().isEmpty) {
          _snack('Nama dan No HP wajib diisi');
          return;
        }
      }
    }
    if (_step == 1) {
      if (!_kendaraanBaru &&
          _kendaraanDipilih == null &&
          _kendaraanPelanggan.isNotEmpty) {
        _snack('Pilih kendaraan atau tambah kendaraan baru');
        return;
      }
      if (_kendaraanBaru || _kendaraanPelanggan.isEmpty) {
        if (_merkCtrl.text.trim().isEmpty ||
            _modelCtrl.text.trim().isEmpty ||
            _polisiCtrl.text.trim().isEmpty) {
          _snack('Merk, model, dan no polisi wajib diisi');
          return;
        }
      }
    }
    setState(() => _step++);
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final payload = <String, dynamic>{
        'tipe': 'walk_in',
        // Kendaraan
        'merk': _merkCtrl.text.trim(),
        'model': _modelCtrl.text.trim(),
        'no_polisi': _polisiCtrl.text.trim().toUpperCase(),
        // Keluhan
        'keluhan': _keluhanCtrl.text.trim(),
        'jenis_servis_id': _jenisServisId,
      };

      // Pelanggan
      if (_pelangganBaru) {
        payload['pelanggan_baru'] = true;
        payload['nama_baru'] = _namaCtrl.text.trim();
        payload['hp_baru'] = _hpCtrl.text.trim();
      } else if (_pelangganDipilih != null) {
        payload['pelanggan_id'] = _pelangganDipilih!['id'];
        payload['kendaraan_baru'] = _kendaraanDipilih == null;
        if (_kendaraanDipilih != null) {
          payload['kendaraan_id'] = _kendaraanDipilih!['id'];
        }
      }

      // Sparepart (opsional)
      if (_keranjangSparepart.isNotEmpty) {
        payload['sparepart'] = _keranjangSparepart.values
            .map((item) => {
                  'sparepart_id': item.sparepartId,
                  'jumlah': item.jumlah,
                })
            .toList();
      }

      final res = await KasirService.instance.buatWalkIn(payload);
      if (!mounted) return;
      final ok = res['success'] == true;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(res['message'] ?? (ok ? 'Walk-in berhasil dibuat' : 'Gagal')),
        backgroundColor: ok ? Colors.green : Colors.red,
      ));
      if (ok) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
    if (mounted) setState(() => _submitting = false);
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool req = false,
    bool upper = false,
    TextInputType type = TextInputType.text,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      textCapitalization:
          upper ? TextCapitalization.characters : TextCapitalization.none,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.indigo.shade700),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      validator: req
          ? (v) => (v == null || v.trim().isEmpty) ? '$label wajib diisi' : null
          : null,
    );
  }

  Widget _summRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 80,
                child: Text(label,
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600))),
            Expanded(
                child: Text(value,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600))),
          ],
        ),
      );
}

// ── Tile item di keranjang sparepart ─────────────────────
class _KeranjangTile extends StatelessWidget {
  final KeranjangItem item;
  final VoidCallback onTambah;
  final VoidCallback onKurang;
  final VoidCallback onHapus;

  const _KeranjangTile({
    required this.item,
    required this.onTambah,
    required this.onKurang,
    required this.onHapus,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.nama,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text(
                  '${formatRupiah(item.hargaJual)} / ${item.satuan}  →  ${formatRupiah(item.subtotal)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          // Kontrol jumlah
          Row(
            children: [
              _IconBtn(
                  icon: Icons.remove,
                  color: Colors.red.shade400,
                  onTap: onKurang),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('${item.jumlah}',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold)),
              ),
              _IconBtn(
                  icon: Icons.add,
                  color: Colors.green.shade600,
                  onTap: onTambah),
              const SizedBox(width: 4),
              _IconBtn(
                  icon: Icons.delete_outline,
                  color: Colors.grey.shade500,
                  onTap: onHapus),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _IconBtn(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

// ── Step indicator ────────────────────────────────────────
class _StepIndicator extends StatelessWidget {
  final int current;
  final List<String> steps;
  const _StepIndicator({required this.current, required this.steps});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            final done = i ~/ 2 < current;
            return Expanded(
                child: Container(
              height: 2,
              color: done ? Colors.indigo.shade500 : Colors.grey.shade200,
            ));
          }
          final si = i ~/ 2;
          final done = si < current;
          final cur = si == current;
          return Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done || cur
                      ? Colors.indigo.shade700
                      : Colors.grey.shade200,
                ),
                child: Center(
                  child: done
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : Text('${si + 1}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: cur ? Colors.white : Colors.grey.shade500,
                          )),
                ),
              ),
              const SizedBox(height: 4),
              Text(steps[si],
                  style: TextStyle(
                    fontSize: 10,
                    color: cur || done ? Colors.indigo.shade700 : Colors.grey,
                    fontWeight: cur ? FontWeight.bold : FontWeight.normal,
                  )),
            ],
          );
        }),
      ),
    );
  }
}

// ── Widget helpers ────────────────────────────────────────
class _ToggleChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ToggleChip(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.indigo.shade700 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? Colors.indigo.shade700 : Colors.grey.shade300),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 13,
              color: active ? Colors.white : Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            )),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String msg;
  const _InfoBox({required this.icon, required this.color, required this.msg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(msg, style: TextStyle(fontSize: 13, color: color))),
        ],
      ),
    );
  }
}

class _PelangganTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool selected;
  final VoidCallback onTap;
  const _PelangganTile(
      {required this.data, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selected ? Colors.indigo.shade700 : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: Colors.indigo.shade100,
          child: Text(
            (data['nama'] as String? ?? 'P')[0].toUpperCase(),
            style: TextStyle(
                color: Colors.indigo.shade700, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(data['nama'] as String? ?? ''),
        subtitle: Text(data['no_hp'] as String? ?? ''),
        trailing: selected
            ? Icon(Icons.check_circle, color: Colors.indigo.shade700)
            : null,
      ),
    );
  }
}

class _KendaraanTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool selected;
  final VoidCallback onTap;
  const _KendaraanTile(
      {required this.data, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selected ? Colors.indigo.shade700 : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.two_wheeler, color: Colors.indigo.shade700),
        ),
        title: Text('${data['merk']} ${data['model']}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(data['no_polisi'] as String? ?? ''),
        trailing: selected
            ? Icon(Icons.check_circle, color: Colors.indigo.shade700)
            : null,
      ),
    );
  }
}
