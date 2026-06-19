// lib/features/kasir/screens/jual_sparepart_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/format_helper.dart';
import '../models/kasir_models.dart';
import '../services/kasir_service.dart';

class JualSparepartScreen extends StatefulWidget {
  const JualSparepartScreen({super.key});

  @override
  State<JualSparepartScreen> createState() => _JualSparepartScreenState();
}

class _JualSparepartScreenState extends State<JualSparepartScreen> {
  // ── State ─────────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  List<SparepartCariModel> _hasilCari = [];
  final List<KeranjangItem> _keranjang = [];
  bool _loadingCari = false;
  bool _showKeranjang = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── Cari Sparepart (debounce 400ms) ───────────────────────
  void _onSearchChanged(String val) {
    _debounce?.cancel();
    if (val.trim().length < 2) {
      setState(() => _hasilCari = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _loadingCari = true);
      final hasil = await KasirService.instance.cariSparepart(val.trim());
      if (!mounted) return;
      setState(() {
        _hasilCari = hasil;
        _loadingCari = false;
      });
    });
  }

  // ── Tambah ke keranjang ───────────────────────────────────
  void _tambahKeKeranjang(SparepartCariModel s) {
    if (s.stok <= 0) {
      _snack('Stok ${s.nama} habis', isError: true);
      return;
    }
    final idx = _keranjang.indexWhere((k) => k.sparepartId == s.id);
    if (idx >= 0) {
      final item = _keranjang[idx];
      if (item.jumlah >= item.stokTersedia) {
        _snack('Stok tidak mencukupi (maks ${item.stokTersedia})',
            isError: true);
        return;
      }
      setState(() => _keranjang[idx].jumlah++);
    } else {
      setState(() => _keranjang.add(KeranjangItem.fromSparepart(s)));
    }
    _snack('${s.nama} ditambahkan ke keranjang');
  }

  // ── Ubah jumlah di keranjang ──────────────────────────────
  void _ubahJumlah(int idx, int delta) {
    final item = _keranjang[idx];
    final newJml = item.jumlah + delta;
    if (newJml <= 0) {
      setState(() => _keranjang.removeAt(idx));
    } else if (newJml > item.stokTersedia) {
      _snack('Stok tidak mencukupi (maks ${item.stokTersedia})', isError: true);
    } else {
      setState(() => _keranjang[idx].jumlah = newJml);
    }
  }

  // ── Total keranjang ───────────────────────────────────────
  double get _totalKeranjang =>
      _keranjang.fold(0, (sum, i) => sum + i.subtotal);

  int get _totalItem => _keranjang.fold(0, (sum, i) => sum + i.jumlah);

  // ── Buka dialog checkout ──────────────────────────────────
  void _bukaPembayaran() {
    if (_keranjang.isEmpty) {
      _snack('Keranjang masih kosong', isError: true);
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CheckoutSheet(
        keranjang: List.from(_keranjang),
        total: _totalKeranjang,
        onBerhasil: (hasil) {
          Navigator.pop(context); // tutup sheet
          _tampilkanStruk(hasil);
          setState(() {
            _keranjang.clear();
            _hasilCari = [];
            _searchCtrl.clear();
            _showKeranjang = false;
          });
        },
      ),
    );
  }

  // ── Tampilkan struk setelah berhasil ──────────────────────
  void _tampilkanStruk(HasilTransaksiSparepart hasil) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _StrukDialog(hasil: hasil),
    );
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.danger : AppColors.success,
      duration: const Duration(seconds: 2),
    ));
  }

  // ── BUILD ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Jual Sparepart'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          // Tombol keranjang dengan badge
          Stack(
            children: [
              IconButton(
                icon: Icon(
                  _showKeranjang
                      ? Icons.shopping_cart
                      : Icons.shopping_cart_outlined,
                ),
                tooltip: 'Keranjang',
                onPressed: () =>
                    setState(() => _showKeranjang = !_showKeranjang),
              ),
              if (_keranjang.isNotEmpty)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$_totalItem',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _showKeranjang ? _buildKeranjang() : _buildCariSparepart(),
      // Tombol Bayar fixed di bawah saat keranjang tampil
      bottomNavigationBar: _showKeranjang && _keranjang.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total ($_totalItem item)',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600)),
                          Text(
                            FormatHelper.currency(_totalKeranjang),
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _bukaPembayaran,
                      icon: const Icon(Icons.payment),
                      label: const Text('Bayar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  // ── View: Cari Sparepart ──────────────────────────────────
  Widget _buildCariSparepart() {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Cari nama / kode sparepart...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _hasilCari = []);
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),
        ),

        // Hasil pencarian
        Expanded(
          child: _loadingCari
              ? const Center(child: CircularProgressIndicator())
              : _hasilCari.isEmpty
                  ? _buildEmptySearch()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                      itemCount: _hasilCari.length,
                      itemBuilder: (_, i) => _SparepartCard(
                        sparepart: _hasilCari[i],
                        onTambah: () => _tambahKeKeranjang(_hasilCari[i]),
                        jumlahDiKeranjang: _keranjang
                            .firstWhere(
                              (k) => k.sparepartId == _hasilCari[i].id,
                              orElse: () => KeranjangItem(
                                sparepartId: 0,
                                kode: '',
                                nama: '',
                                satuan: '',
                                hargaJual: 0,
                                stokTersedia: 0,
                                jumlah: 0,
                              ),
                            )
                            .jumlah,
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildEmptySearch() {
    final isTyping = _searchCtrl.text.isNotEmpty;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isTyping ? Icons.search_off_outlined : Icons.inventory_2_outlined,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 12),
          Text(
            isTyping ? 'Sparepart tidak ditemukan' : 'Cari sparepart dulu',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            isTyping
                ? 'Coba kata kunci lain atau cek kode'
                : 'Ketik minimal 2 huruf untuk mulai mencari',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ── View: Keranjang ───────────────────────────────────────
  Widget _buildKeranjang() {
    if (_keranjang.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined,
                size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('Keranjang kosong',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.search),
              label: const Text('Cari Sparepart'),
              onPressed: () => setState(() => _showKeranjang = false),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
      itemCount: _keranjang.length,
      itemBuilder: (_, i) => _KeranjangCard(
        item: _keranjang[i],
        onKurang: () => _ubahJumlah(i, -1),
        onTambah: () => _ubahJumlah(i, 1),
        onHapus: () => setState(() => _keranjang.removeAt(i)),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Widget: Card Sparepart (hasil pencarian)
// ══════════════════════════════════════════════════════════════
class _SparepartCard extends StatelessWidget {
  final SparepartCariModel sparepart;
  final VoidCallback onTambah;
  final int jumlahDiKeranjang;

  const _SparepartCard({
    required this.sparepart,
    required this.onTambah,
    required this.jumlahDiKeranjang,
  });

  @override
  Widget build(BuildContext context) {
    final stokHabis = sparepart.stok <= 0;
    final sudahDiKeranjang = jumlahDiKeranjang > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Info sparepart
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          sparepart.nama,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (sudahDiKeranjang) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Text(
                            '×$jumlahDiKeranjang',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    sparepart.kode,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        FormatHelper.currency(sparepart.hargaJual),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            fontSize: 14),
                      ),
                      Text(
                        ' / ${sparepart.satuan}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Stok badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: stokHabis
                          ? Colors.red.shade50
                          : sparepart.stok <= 5
                              ? Colors.orange.shade50
                              : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      stokHabis
                          ? 'Stok habis'
                          : 'Stok: ${sparepart.stok} ${sparepart.satuan}',
                      style: TextStyle(
                        fontSize: 11,
                        color: stokHabis
                            ? Colors.red.shade700
                            : sparepart.stok <= 5
                                ? Colors.orange.shade700
                                : Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Tombol tambah
            ElevatedButton(
              onPressed: stokHabis ? null : onTambah,
              style: ElevatedButton.styleFrom(
                backgroundColor: sudahDiKeranjang
                    ? Colors.green.shade600
                    : AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(44, 44),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                disabledBackgroundColor: Colors.grey.shade300,
              ),
              child: Icon(
                sudahDiKeranjang ? Icons.add_shopping_cart : Icons.add,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Widget: Card item keranjang
// ══════════════════════════════════════════════════════════════
class _KeranjangCard extends StatelessWidget {
  final KeranjangItem item;
  final VoidCallback onKurang;
  final VoidCallback onTambah;
  final VoidCallback onHapus;

  const _KeranjangCard({
    required this.item,
    required this.onKurang,
    required this.onTambah,
    required this.onHapus,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.nama,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.kode,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: Colors.red.shade400, size: 20),
                  onPressed: onHapus,
                  tooltip: 'Hapus dari keranjang',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Harga per item
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${FormatHelper.currency(item.hargaJual)} / ${item.satuan}',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    Text(
                      FormatHelper.currency(item.subtotal),
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary),
                    ),
                  ],
                ),
                // Kontrol jumlah
                Row(
                  children: [
                    _QtyBtn(
                      icon: Icons.remove,
                      onTap: onKurang,
                      color: Colors.red.shade400,
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${item.jumlah}',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                    _QtyBtn(
                      icon: Icons.add,
                      onTap: item.jumlah < item.stokTersedia ? onTambah : null,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;

  const _QtyBtn({required this.icon, this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: onTap != null ? color.withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                onTap != null ? color.withOpacity(0.4) : Colors.grey.shade300,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: onTap != null ? color : Colors.grey.shade400,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// BottomSheet: Checkout / Pembayaran
// ══════════════════════════════════════════════════════════════
class _CheckoutSheet extends StatefulWidget {
  final List<KeranjangItem> keranjang;
  final double total;
  final void Function(HasilTransaksiSparepart) onBerhasil;

  const _CheckoutSheet({
    required this.keranjang,
    required this.total,
    required this.onBerhasil,
  });

  @override
  State<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<_CheckoutSheet> {
  String _metodeBayar = 'cash';
  final _bayarCtrl = TextEditingController();
  bool _submitting = false;

  double get _jumlahBayar =>
      double.tryParse(_bayarCtrl.text.replaceAll('.', '')) ?? 0;
  double get _kembalian =>
      (_jumlahBayar - widget.total).clamp(0, double.infinity);
  bool get _cukup => _metodeBayar == 'transfer' || _jumlahBayar >= widget.total;

  @override
  void initState() {
    super.initState();
    // Default isi otomatis
    _bayarCtrl.text = widget.total.toInt().toString();
  }

  @override
  void dispose() {
    _bayarCtrl.dispose();
    super.dispose();
  }

  Future<void> _prosesBayar() async {
    if (!_cukup) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Jumlah bayar kurang dari total'),
        backgroundColor: AppColors.danger,
      ));
      return;
    }

    setState(() => _submitting = true);

    final items = widget.keranjang
        .map((k) => {
              'sparepart_id': k.sparepartId,
              'jumlah': k.jumlah,
              'harga_jual': k.hargaJual,
            })
        .toList();

    final res = await KasirService.instance.buatTransaksiSparepart(
      items: items,
      metodeBayar: _metodeBayar,
      jumlahBayar: _metodeBayar == 'transfer' ? widget.total : _jumlahBayar,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (res['success'] == true) {
      final hasil = HasilTransaksiSparepart.fromJson(
          res['data'] as Map<String, dynamic>? ?? {});
      widget.onBerhasil(hasil);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['message'] as String? ?? 'Transaksi gagal'),
        backgroundColor: AppColors.danger,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            const Text('Pembayaran',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Ringkasan item
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  ...widget.keranjang.map((k) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${k.nama} ×${k.jumlah}',
                                style: const TextStyle(fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              FormatHelper.currency(k.subtotal),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      )),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        FormatHelper.currency(widget.total),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            fontSize: 16),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Metode bayar
            const Text('Metode Pembayaran',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                _MetodeBayarBtn(
                  label: 'Cash',
                  icon: Icons.payments_outlined,
                  selected: _metodeBayar == 'cash',
                  onTap: () => setState(() => _metodeBayar = 'cash'),
                ),
                const SizedBox(width: 10),
                _MetodeBayarBtn(
                  label: 'Transfer',
                  icon: Icons.account_balance_outlined,
                  selected: _metodeBayar == 'transfer',
                  onTap: () => setState(() => _metodeBayar = 'transfer'),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Input jumlah bayar (hanya untuk cash)
            if (_metodeBayar == 'cash') ...[
              const Text('Jumlah Bayar',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _bayarCtrl,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              if (_jumlahBayar >= widget.total && _jumlahBayar > 0) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Kembalian',
                          style: TextStyle(fontWeight: FontWeight.w500)),
                      Text(
                        FormatHelper.currency(_kembalian),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                            fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
            ],

            // Tombol bayar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_submitting || !_cukup) ? null : _prosesBayar,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                    _submitting ? 'Memproses...' : 'Konfirmasi Pembayaran'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetodeBayarBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _MetodeBayarBtn({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withOpacity(0.1)
                : Colors.grey.shade50,
            border: Border.all(
              color: selected ? AppColors.primary : Colors.grey.shade300,
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: selected ? AppColors.primary : Colors.grey.shade500),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    color: selected ? AppColors.primary : Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Dialog: Struk setelah transaksi berhasil
// ══════════════════════════════════════════════════════════════
class _StrukDialog extends StatelessWidget {
  final HasilTransaksiSparepart hasil;

  const _StrukDialog({required this.hasil});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon sukses
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle,
                  color: Colors.green.shade600, size: 48),
            ),
            const SizedBox(height: 16),
            const Text('Transaksi Berhasil!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              hasil.noNota,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 16),
            const Divider(),
            _StrukRow('Total', FormatHelper.currency(hasil.grandTotal),
                bold: true),
            _StrukRow('Bayar (${hasil.metodeBayar.toUpperCase()})',
                FormatHelper.currency(hasil.jumlahBayar)),
            if (hasil.kembalian > 0)
              _StrukRow('Kembalian', FormatHelper.currency(hasil.kembalian),
                  color: Colors.green.shade700),
            const Divider(),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Selesai'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StrukRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;

  const _StrukRow(this.label, this.value, {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                  color: color ?? (bold ? AppColors.primary : Colors.black87),
                  fontSize: bold ? 15 : 13)),
        ],
      ),
    );
  }
}
