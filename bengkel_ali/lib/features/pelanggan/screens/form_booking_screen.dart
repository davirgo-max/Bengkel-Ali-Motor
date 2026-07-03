import 'package:flutter/material.dart';
import '../services/pelanggan_service.dart';
import '../models/pelanggan_models.dart';
import '../../../core/utils/format_helper.dart';
import 'form_kendaraan_screen.dart';

class FormBookingScreen extends StatefulWidget {
  const FormBookingScreen({super.key});
  @override
  State<FormBookingScreen> createState() => _FormBookingScreenState();
}

class _FormBookingScreenState extends State<FormBookingScreen> {
  final _keluhanCtrl = TextEditingController();

  List<KendaraanModel> _kendaraan = [];
  List<JenisServisModel> _jenisServis = [];
  KendaraanModel? _selectedKendaraan;
  JenisServisModel? _selectedJenis;
  DateTime? _selectedDate;
  SlotResponse? _slotResponse;
  SlotWaktuModel? _selectedSlot;

  // ── State sparepart ──────────────────────────────────
  List<SparepartModel> _semuaSparepart = [];
  List<KategoriModel> _kategoriList = [];
  final List<BookingSparepartItem> _keranjangPart = [];
  bool _loadingSparepart = false;
  bool _sparepartExpanded = false; // panel accordion
  String _searchPart = '';
  int? _filterKategoriId;

  bool _loading = true;
  bool _loadingSlot = false;
  bool _submitting = false;
  List<String> _hariLibur = []; // tanggal blocked dari API
  String _errorMsg = '';

  @override
  void initState() {
    super.initState();
    _loadInit();
  }

  @override
  void dispose() {
    _keluhanCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInit({bool resetKendaraan = false}) async {
    setState(() {
      _loading = true;
      _errorMsg = '';
    });
    try {
      final results = await Future.wait([
        PelangganService.instance.getKendaraan(),
        PelangganService.instance.getJenisServis(),
        PelangganService.instance.getHariLibur(),
      ]);
      if (mounted) {
        final newKendaraanList = results[0] as List<KendaraanModel>;
        setState(() {
          _kendaraan = newKendaraanList;
          _jenisServis = results[1] as List<JenisServisModel>;
          _hariLibur = results[2] as List<String>;
          if (resetKendaraan ||
              (_selectedKendaraan != null &&
                  !newKendaraanList
                      .any((k) => k.id == _selectedKendaraan!.id))) {
            _selectedKendaraan = null;
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMsg = 'Error: $e';
        });
      }
    }
  }

  // ── Load sparepart (dipanggil saat panel dibuka pertama kali) ──
  Future<void> _loadSparepart() async {
    if (_loadingSparepart) return;
    setState(() => _loadingSparepart = true);

    final results = await Future.wait([
      PelangganService.instance.getSparepartTersedia(),
      PelangganService.instance.getKategoriSparepart(),
    ]);

    if (mounted) {
      setState(() {
        _semuaSparepart = results[0] as List<SparepartModel>;
        _kategoriList = results[1] as List<KategoriModel>;
        _loadingSparepart = false;
      });
    }
  }

  // ── Load sparepart dengan filter ──────────────────────
  Future<void> _filterSparepart() async {
    setState(() => _loadingSparepart = true);
    final list = await PelangganService.instance.getSparepartTersedia(
      search: _searchPart.isNotEmpty ? _searchPart : null,
      kategoriId: _filterKategoriId,
    );
    if (mounted) {
      setState(() {
        _semuaSparepart = list;
        _loadingSparepart = false;
      });
    }
  }

  Future<void> _loadSlot() async {
    if (_selectedDate == null) return;
    setState(() {
      _loadingSlot = true;
      _selectedSlot = null;
      _slotResponse = null;
    });

    final res = await PelangganService.instance.getSlotWaktu(
      tanggal: _fmtDate(_selectedDate!),
      jenisServisId: _selectedJenis?.id,
    );

    // ← tambah ini untuk debug sementara
    debugPrint('[SLOT] result: $res');

    if (mounted) {
      setState(() {
        _slotResponse = res;
        _loadingSlot = false;
      });
    }
  }

  bool _isSelectable(DateTime day) {
    if (day.weekday == DateTime.sunday) return false;
    final fmt =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    return !_hariLibur.contains(fmt);
  }

  Future<void> _pilihTanggal() async {
    final now = DateTime.now();

    // Cari hari valid pertama mulai hari ini (maks 90 hari ke depan)
    DateTime initialDate = now;
    for (int i = 0; i <= 90; i++) {
      final candidate = now.add(Duration(days: i));
      if (_isSelectable(candidate)) {
        initialDate = candidate;
        break;
      }
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      helpText: 'Pilih Tanggal Servis',
      selectableDayPredicate: _isSelectable,
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedDate = picked);
    await _loadSlot();
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _displayDate(DateTime d) {
    const bulan = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des'
    ];
    return '${d.day} ${bulan[d.month]} ${d.year}';
  }

  // ── Keranjang sparepart helpers ───────────────────────
  void _tambahPart(SparepartModel part) {
    final existing =
        _keranjangPart.indexWhere((e) => e.sparepart.id == part.id);
    if (existing >= 0) {
      // Sudah ada — naikkan jumlah
      setState(() => _keranjangPart[existing].jumlah++);
    } else {
      setState(() => _keranjangPart.add(BookingSparepartItem(sparepart: part)));
    }
  }

  void _kurangiPart(SparepartModel part) {
    final idx = _keranjangPart.indexWhere((e) => e.sparepart.id == part.id);
    if (idx < 0) return;
    if (_keranjangPart[idx].jumlah <= 1) {
      setState(() => _keranjangPart.removeAt(idx));
    } else {
      setState(() => _keranjangPart[idx].jumlah--);
    }
  }

  void _hapusPart(int idx) => setState(() => _keranjangPart.removeAt(idx));

  int _jumlahDiKeranjang(int sparepartId) {
    final idx = _keranjangPart.indexWhere((e) => e.sparepart.id == sparepartId);
    return idx >= 0 ? _keranjangPart[idx].jumlah : 0;
  }

  double get _totalEstimasiPart =>
      _keranjangPart.fold(0, (sum, e) => sum + e.subtotal);

  Future<void> _konfirmasiDanSubmit() async {
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Booking'),
        content: const Text(
          'Apakah kamu yakin ingin mengirim booking ini?\n\n'
          '⚠️ Setiap pelanggan hanya dapat membuat 1 booking per hari. '
          'Booking yang sudah dikirim tidak dapat diulang di hari yang sama, '
          'meskipun dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Kirim Booking'),
          ),
        ],
      ),
    );
    if (konfirmasi == true) _submit();
  }

  Future<void> _submit() async {
    if (_selectedKendaraan == null) {
      _snack('Pilih kendaraan terlebih dahulu');
      return;
    }
    if (_selectedDate == null) {
      _snack('Pilih tanggal servis');
      return;
    }
    if (_selectedSlot == null) {
      _snack('Pilih slot waktu');
      return;
    }
    if (!_selectedSlot!.tersedia) {
      _snack('Slot tidak tersedia');
      return;
    }

    setState(() => _submitting = true);

    final res = await PelangganService.instance.buatBooking(
      {
        'kendaraan_id': _selectedKendaraan!.id,
        'jenis_servis_id': _selectedJenis?.id,
        'slot_id': _selectedSlot!.id,
        'tanggal_servis': _fmtDate(_selectedDate!),
        'keluhan': _keluhanCtrl.text.trim(),
      },
      sparepartItems: _keranjangPart.isNotEmpty ? _keranjangPart : null,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (res['success'] == true) {
      final data = res['data'] as Map<String, dynamic>;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Booking Berhasil! 🎉'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dialogRow('No Booking', data['no_booking'].toString()),
              _dialogRow('Tanggal', _displayDate(_selectedDate!)),
              _dialogRow('Waktu', _selectedSlot!.label),
              if (_selectedJenis != null)
                _dialogRow('Jenis Servis', _selectedJenis!.nama),
              _dialogRow('Status', data['status'].toString()),
              if (_keranjangPart.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 16, color: Colors.amber.shade800),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${_keranjangPart.length} sparepart dikirim ke kasir untuk dikonfirmasi.',
                          style: TextStyle(
                              fontSize: 12, color: Colors.amber.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      _snack(res['message'] as String? ?? 'Gagal membuat booking');
    }
  }

  Widget _dialogRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 90,
                child: Text(label,
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 13))),
            Expanded(
                child: Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13))),
          ],
        ),
      );

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // ════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMsg.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(
            title: const Text('Buat Booking'),
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white),
        body: Center(
            child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(_errorMsg,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
                onPressed: _loadInit,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white)),
          ],
        )),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buat Booking Servis'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── STEP 1: Kendaraan ──────────────────────
            _stepHeader('1', 'Pilih Kendaraan'),
            if (_kendaraan.isEmpty)
              _infoBox(Icons.info_outline, Colors.orange,
                  'Belum ada kendaraan. Tambahkan dulu.')
            else
              DropdownButtonFormField<KendaraanModel>(
                initialValue: _selectedKendaraan,
                isExpanded: true,
                decoration: _deco('Pilih kendaraan', Icons.two_wheeler),
                items: _kendaraan
                    .map((k) => DropdownMenuItem(
                          value: k,
                          child: Text(k.label,
                              overflow: TextOverflow.ellipsis, maxLines: 1),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedKendaraan = v),
              ),
            TextButton.icon(
              onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const FormKendaraanScreen()))
                  .then((_) => _loadInit(resetKendaraan: true)),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Tambah kendaraan baru'),
            ),
            const SizedBox(height: 16),

            // ── STEP 2: Jenis Servis ───────────────────
            _stepHeader('2', 'Jenis Servis (opsional)'),
            DropdownButtonFormField<JenisServisModel?>(
              initialValue: _selectedJenis,
              isExpanded: true,
              decoration: _deco('Pilih jenis servis', Icons.build),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('-- Belum tahu / konsultasi dulu --',
                      overflow: TextOverflow.ellipsis, maxLines: 1),
                ),
                ..._jenisServis.map((j) => DropdownMenuItem(
                      value: j,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(j.nama,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1),
                          Text(
                            '${FormatHelper.currency(j.hargaJasa)} • ~${j.estimasiMenit} mnt',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )),
              ],
              selectedItemBuilder: (context) => [
                const Text('-- Belum tahu / konsultasi dulu --',
                    overflow: TextOverflow.ellipsis, maxLines: 1),
                ..._jenisServis.map((j) => Text(
                      '${j.nama} • ${FormatHelper.currency(j.hargaJasa)}',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(fontSize: 14),
                    )),
              ],
              onChanged: (v) {
                setState(() {
                  _selectedJenis = v;
                  _selectedSlot = null;
                });
                if (_selectedDate != null) _loadSlot();
              },
            ),
            const SizedBox(height: 16),

            // ── STEP 3: Tanggal ────────────────────────
            _stepHeader('3', 'Pilih Tanggal'),
            InkWell(
              onTap: _pilihTanggal,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Text(
                      _selectedDate == null
                          ? 'Pilih tanggal...'
                          : _displayDate(_selectedDate!),
                      style: TextStyle(
                        fontSize: 15,
                        color: _selectedDate == null
                            ? Colors.grey.shade500
                            : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── STEP 4: Slot Waktu ─────────────────────
            _stepHeader('4', 'Pilih Slot Waktu'),
            if (_selectedDate == null)
              _infoBox(Icons.info_outline, Colors.blue,
                  'Pilih tanggal terlebih dahulu untuk melihat slot tersedia.')
            else if (_loadingSlot)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_slotResponse == null)
              Column(
                children: [
                  _infoBox(Icons.error_outline, Colors.red,
                      'Gagal memuat slot waktu. Periksa koneksi atau coba lagi.'),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _loadSlot,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Coba Lagi'),
                  ),
                ],
              )
            else ...[
              if (_selectedJenis != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.timer, color: Colors.blue.shade700, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Estimasi ±${_slotResponse!.estimasiSelesai} '
                          '(${_slotResponse!.slotDibutuhkan} slot)',
                          style: TextStyle(
                              fontSize: 13, color: Colors.blue.shade800),
                        ),
                      ),
                    ],
                  ),
                ),
              _buildSlotGrid(),
            ],
            const SizedBox(height: 16),

            // ── STEP 5: Keluhan ────────────────────────
            _stepHeader('5', 'Keluhan (opsional)'),
            TextFormField(
              controller: _keluhanCtrl,
              maxLines: 3,
              decoration:
                  _deco('Deskripsikan masalah kendaraan kamu...', Icons.notes),
            ),
            const SizedBox(height: 16),

            // ── STEP 6: Sparepart (opsional) ──────────
            _buildSparepartSection(),
            const SizedBox(height: 20),

            // ── Ringkasan ──────────────────────────────
            if (_selectedSlot != null) ...[
              _buildSummaryCard(),
              const SizedBox(height: 12),
            ],

            // ── Tombol Submit ──────────────────────────
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _submitting ? null : _konfirmasiDanSubmit,
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
                    : const Text('Buat Booking',
                        style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════
  //  SECTION SPAREPART (accordion opsional)
  // ════════════════════════════════════════════════════
  Widget _buildSparepartSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header step + toggle accordion
        Row(
          children: [
            _stepHeaderInline('6', 'Sparepart (opsional)'),
            const Spacer(),
            TextButton.icon(
              onPressed: () async {
                final willExpand = !_sparepartExpanded;
                setState(() => _sparepartExpanded = willExpand);
                if (willExpand && _semuaSparepart.isEmpty) {
                  await _loadSparepart();
                }
              },
              icon: Icon(
                _sparepartExpanded ? Icons.expand_less : Icons.expand_more,
                size: 18,
              ),
              label: Text(_sparepartExpanded ? 'Tutup' : 'Pilih Part'),
              style: TextButton.styleFrom(
                  foregroundColor: Colors.blue.shade700,
                  padding: EdgeInsets.zero),
            ),
          ],
        ),

        // Info helper
        _infoBox(
          Icons.lightbulb_outline,
          Colors.grey,
          'Opsional — pilih jika kamu tahu sparepart yang dibutuhkan. '
          'Kasir akan mengkonfirmasi setelah diagnosa.',
        ),
        const SizedBox(height: 8),

        // Keranjang part (selalu tampil jika ada isi)
        if (_keranjangPart.isNotEmpty) ...[
          _buildKeranjangPart(),
          const SizedBox(height: 8),
        ],

        // Panel katalog (accordion)
        if (_sparepartExpanded) _buildKatalogSparepart(),
      ],
    );
  }

  // ── Keranjang / pilihan part yang sudah ditambah ────
  Widget _buildKeranjangPart() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shopping_cart, color: Colors.green.shade700, size: 18),
              const SizedBox(width: 6),
              Text(
                'Part yang diminta (${_keranjangPart.length} item)',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                    fontSize: 13),
              ),
            ],
          ),
          const Divider(height: 10),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _keranjangPart.length,
            separatorBuilder: (_, __) => const Divider(height: 8),
            itemBuilder: (_, i) {
              final item = _keranjangPart[i];
              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.sparepart.nama,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(
                          '${FormatHelper.currency(item.sparepart.hargaJual)} / ${item.sparepart.satuan}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  // Stepper jumlah
                  _buildStepper(item),
                  const SizedBox(width: 4),
                  // Subtotal
                  SizedBox(
                    width: 72,
                    child: Text(
                      FormatHelper.currency(item.subtotal),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),
                  // Hapus
                  IconButton(
                    icon:
                        Icon(Icons.close, size: 16, color: Colors.red.shade400),
                    onPressed: () => _hapusPart(i),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              );
            },
          ),
          const Divider(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Estimasi biaya part',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              Text(
                FormatHelper.currency(_totalEstimasiPart),
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.green.shade700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '* Harga final ditentukan kasir setelah diagnosa',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildStepper(BookingSparepartItem item) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => _kurangiPart(item.sparepart),
          borderRadius: BorderRadius.circular(4),
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.remove, size: 14),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('${item.jumlah}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        InkWell(
          onTap: () {
            if (item.jumlah < item.sparepart.stok) {
              _tambahPart(item.sparepart);
            } else {
              _snack('Stok tidak cukup (maks ${item.sparepart.stok})');
            }
          },
          borderRadius: BorderRadius.circular(4),
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.add, size: 14, color: Colors.white),
          ),
        ),
      ],
    );
  }

  // ── Katalog sparepart ─────────────────────────────────
  Widget _buildKatalogSparepart() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          // Search + filter kategori
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: TextField(
                      onChanged: (v) {
                        _searchPart = v;
                        _filterSparepart();
                      },
                      decoration: InputDecoration(
                        hintText: 'Cari sparepart...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        isDense: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Dropdown kategori
                if (_kategoriList.isNotEmpty)
                  SizedBox(
                    height: 38,
                    child: DropdownButton<int?>(
                      value: _filterKategoriId,
                      hint: const Text('Semua', style: TextStyle(fontSize: 13)),
                      underline: const SizedBox(),
                      items: [
                        const DropdownMenuItem(
                            value: null,
                            child:
                                Text('Semua', style: TextStyle(fontSize: 13))),
                        ..._kategoriList.map((k) => DropdownMenuItem(
                              value: k.id,
                              child: Text(k.nama,
                                  style: const TextStyle(fontSize: 13)),
                            )),
                      ],
                      onChanged: (v) {
                        setState(() => _filterKategoriId = v);
                        _filterSparepart();
                      },
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          // List sparepart
          if (_loadingSparepart)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_semuaSparepart.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text('Tidak ada sparepart ditemukan.',
                    style: TextStyle(color: Colors.grey.shade500)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _semuaSparepart.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 14),
              itemBuilder: (_, i) {
                final part = _semuaSparepart[i];
                final qty = _jumlahDiKeranjang(part.id);
                return ListTile(
                  dense: true,
                  title: Text(part.nama,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  subtitle: Text(
                    '${FormatHelper.currency(part.hargaJual)} / ${part.satuan}'
                    '  •  Stok: ${part.stok}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  trailing: qty == 0
                      ? TextButton(
                          onPressed:
                              part.stok > 0 ? () => _tambahPart(part) : null,
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6)),
                          ),
                          child: const Text('+ Tambah',
                              style: TextStyle(fontSize: 12)),
                        )
                      : _buildStepper(_keranjangPart
                          .firstWhere((e) => e.sparepart.id == part.id)),
                );
              },
            ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════
  //  SLOT GRID
  // ════════════════════════════════════════════════════
  Widget _buildSlotGrid() {
    final slots = _slotResponse!.slots;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2.4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: slots.length,
      itemBuilder: (_, i) {
        final slot = slots[i];
        final selected = _selectedSlot?.id == slot.id;

        final bgColor = !slot.tersedia
            ? Colors.grey.shade100
            : selected
                ? Colors.blue.shade700
                : Colors.white;
        final borderColor = !slot.tersedia
            ? Colors.grey.shade300
            : selected
                ? Colors.blue.shade700
                : Colors.blue.shade300;
        final textColor = !slot.tersedia
            ? Colors.grey.shade400
            : selected
                ? Colors.white
                : Colors.black87;

        return Tooltip(
          message: slot.alasan ?? slot.label,
          child: GestureDetector(
            onTap: slot.tersedia
                ? () => setState(() => _selectedSlot = slot)
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor, width: selected ? 2 : 1),
              ),
              child: Center(
                child: Text(
                  slot.jamMulai.substring(0, 5),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    color: textColor,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ════════════════════════════════════════════════════
  //  RINGKASAN CARD
  // ════════════════════════════════════════════════════
  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.check_circle, color: Colors.green.shade700, size: 18),
            const SizedBox(width: 6),
            Text('Ringkasan Booking',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.green.shade700)),
          ]),
          const Divider(height: 12),
          if (_selectedKendaraan != null)
            _summaryRow('Kendaraan', _selectedKendaraan!.label),
          if (_selectedDate != null)
            _summaryRow('Tanggal', _displayDate(_selectedDate!)),
          if (_selectedSlot != null) _summaryRow('Waktu', _selectedSlot!.label),
          if (_selectedJenis != null) ...[
            _summaryRow('Jenis Servis', _selectedJenis!.nama),
            _summaryRow('Est. Biaya Jasa',
                FormatHelper.currency(_selectedJenis!.hargaJasa)),
          ],
          // Tampilkan jika ada part di keranjang
          if (_keranjangPart.isNotEmpty) ...[
            _summaryRow(
              'Req. Sparepart',
              '${_keranjangPart.length} item '
                  '(~${FormatHelper.currency(_totalEstimasiPart)})',
            ),
          ],
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════
  //  WIDGET HELPERS
  // ════════════════════════════════════════════════════
  Widget _summaryRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 110,
                child: Text(label,
                    style:
                        TextStyle(fontSize: 13, color: Colors.grey.shade700))),
            Expanded(
                child: Text(value,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600))),
          ],
        ),
      );

  Widget _stepHeader(String no, String title) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                  color: Colors.blue.shade700, shape: BoxShape.circle),
              child: Center(
                child: Text(no,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ),
            ),
            const SizedBox(width: 8),
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      );

  // Versi inline (tanpa bottom padding, untuk pairing dengan widget lain)
  Widget _stepHeaderInline(String no, String title) => Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
                color: Colors.blue.shade700, shape: BoxShape.circle),
            child: Center(
              child: Text(no,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ),
          ),
          const SizedBox(width: 8),
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      );

  Widget _infoBox(IconData icon, Color color, String msg) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
                child: Text(msg, style: TextStyle(fontSize: 13, color: color))),
          ],
        ),
      );

  InputDecoration _deco(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.blue.shade700),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      );
}
