// lib/features/kasir/screens/beli_stok_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/format_helper.dart';
import '../models/kasir_models.dart';
import '../services/kasir_service.dart';

class BeliStokScreen extends StatelessWidget {
  const BeliStokScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _CatatPembelianTab();
  }
}

// ════════════════════════════════════════════════════════════════
// TAB 1 — Catat Pembelian
// ════════════════════════════════════════════════════════════════
class _CatatPembelianTab extends StatefulWidget {
  const _CatatPembelianTab();

  @override
  State<_CatatPembelianTab> createState() => _CatatPembelianTabState();
}

class _CatatPembelianTabState extends State<_CatatPembelianTab> {
  final _searchCtrl = TextEditingController();
  final _supplierCtrl = TextEditingController();
  final _keteranganCtrl = TextEditingController();
  Timer? _debounce;

  List<SparepartCariModel> _hasilCari = [];
  final List<BeliStokItem> _keranjang = [];
  bool _loadingCari = false;
  bool _loadingSubmit = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _supplierCtrl.dispose();
    _keteranganCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── Search ─────────────────────────────────────────────────
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

  // ── Tambah ke keranjang ─────────────────────────────────────
  void _tambahKeKeranjang(SparepartCariModel s) {
    final idx = _keranjang.indexWhere((k) => k.sparepartId == s.id);
    if (idx >= 0) {
      setState(() => _keranjang[idx].jumlah++);
    } else {
      setState(() => _keranjang.add(BeliStokItem(
            sparepartId: s.id,
            kode: s.kode,
            nama: s.nama,
            satuan: s.satuan,
            hargaBeli: s.hargaJual,
          )));
    }
    _snack('${s.nama} ditambahkan');
  }

  // ── Edit harga beli ────────────────────────────────────────
  void _editHarga(int idx) {
    final item = _keranjang[idx];
    final ctrl = TextEditingController(text: item.hargaBeli.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            const Icon(Icons.edit, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(item.nama,
                  style: const TextStyle(fontSize: 15), maxLines: 2),
            ),
          ],
        ),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          autofocus: true,
          decoration: InputDecoration(
            prefixText: 'Rp ',
            labelText: 'Harga beli per satuan',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(ctrl.text) ?? item.hargaBeli;
              setState(() {
                _keranjang[idx] = BeliStokItem(
                  sparepartId: item.sparepartId,
                  kode: item.kode,
                  nama: item.nama,
                  satuan: item.satuan,
                  hargaBeli: val,
                  jumlah: item.jumlah,
                );
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  // ── Submit ─────────────────────────────────────────────────
  Future<void> _submit() async {
    if (_keranjang.isEmpty) {
      _snack('Keranjang masih kosong', isError: true);
      return;
    }
    final konfirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.inventory_2_outlined, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Konfirmasi Pembelian'),
          ],
        ),
        content: Text(
          'Catat pembelian ${_keranjang.length} item?\n'
          'Total: ${FormatHelper.currency(_totalBeli)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Ya, Catat'),
          ),
        ],
      ),
    );
    if (konfirm != true) return;

    setState(() => _loadingSubmit = true);
    final res = await KasirService.instance.beliStok(
      items: _keranjang
          .map((e) => {
                'sparepart_id': e.sparepartId,
                'jumlah': e.jumlah,
                'harga_beli': e.hargaBeli,
              })
          .toList(),
      supplier: _supplierCtrl.text.trim(),
      keterangan: _keteranganCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _loadingSubmit = false);

    if (res['success'] == true) {
      setState(() {
        _keranjang.clear();
        _hasilCari = [];
        _searchCtrl.clear();
        _supplierCtrl.clear();
        _keteranganCtrl.clear();
      });
      _snack('Pembelian berhasil! No: ${res['data']?['no_pembelian'] ?? ''}');
    } else {
      _snack(res['message'] ?? 'Gagal menyimpan', isError: true);
    }
  }

  double get _totalBeli => _keranjang.fold(0, (sum, e) => sum + e.subtotal);

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.danger : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.bgLight,
      child: Column(
        children: [
          // ── Toolbar: judul + tombol riwayat ──────────────
          Container(
            color: AppColors.cardBg,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.add_shopping_cart_outlined,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                const Text('Catat Pembelian Stok',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textPrimary)),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const _RiwayatSheet(),
                  ),
                  icon: const Icon(Icons.history, size: 16),
                  label: const Text('Riwayat', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Cari nama / kode sparepart...',
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                prefixIcon: _loadingCari
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primary),
                        ),
                      )
                    : const Icon(Icons.search, color: AppColors.primary),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear,
                            color: AppColors.textSecondary),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _hasilCari = []);
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.cardBg,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
          ),

          // ── Dropdown hasil cari ───────────────────────────
          if (_hasilCari.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _hasilCari.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: Colors.grey.shade100),
                itemBuilder: (_, i) {
                  final s = _hasilCari[i];
                  return ListTile(
                    dense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.inventory_2_outlined,
                          color: AppColors.primary, size: 18),
                    ),
                    title: Text(s.nama,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            fontSize: 13)),
                    subtitle: Text(
                      '${s.kode}  •  Stok ${s.stok} ${s.satuan}  •  ${FormatHelper.currency(s.hargaJual)}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                    trailing: GestureDetector(
                      onTap: () => _tambahKeKeranjang(s),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.add,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  );
                },
              ),
            ),

          // ── Supplier & Keterangan ──────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: _buildInputField(
                    controller: _supplierCtrl,
                    label: 'Supplier',
                    hint: 'Nama supplier...',
                    icon: Icons.store_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInputField(
                    controller: _keteranganCtrl,
                    label: 'Keterangan',
                    hint: 'Catatan...',
                    icon: Icons.notes_outlined,
                  ),
                ),
              ],
            ),
          ),

          // ── Label keranjang ───────────────────────────────
          if (_keranjang.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
              child: Row(
                children: [
                  const Icon(Icons.shopping_basket_outlined,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Keranjang (${_keranjang.length} item)',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                        fontSize: 13),
                  ),
                ],
              ),
            ),

          // ── List keranjang ────────────────────────────────
          Expanded(
            child: _keranjang.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_shopping_cart_outlined,
                            size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        const Text('Belum ada item',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        const Text('Cari sparepart di atas lalu tambahkan',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    itemCount: _keranjang.length,
                    itemBuilder: (_, i) => _KeranjangCard(
                      item: _keranjang[i],
                      onEditHarga: () => _editHarga(i),
                      onKurang: () => setState(() {
                        if (_keranjang[i].jumlah <= 1) {
                          _keranjang.removeAt(i);
                        } else {
                          _keranjang[i].jumlah--;
                        }
                      }),
                      onTambah: () => setState(() => _keranjang[i].jumlah++),
                      onHapus: () => setState(() => _keranjang.removeAt(i)),
                    ),
                  ),
          ),

          // ── Footer total & simpan ─────────────────────────
          if (_keranjang.isNotEmpty)
            SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Total Pembelian',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                          Text(
                            FormatHelper.currency(_totalBeli),
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _loadingSubmit ? null : _submit,
                      icon: _loadingSubmit
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_outlined),
                      label: const Text('Catat Pembelian'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        disabledBackgroundColor: Colors.grey.shade300,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.cardBg,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }
}

// ── Card item keranjang ────────────────────────────────────────
class _KeranjangCard extends StatelessWidget {
  final BeliStokItem item;
  final VoidCallback onEditHarga;
  final VoidCallback onKurang;
  final VoidCallback onTambah;
  final VoidCallback onHapus;

  const _KeranjangCard({
    required this.item,
    required this.onEditHarga,
    required this.onKurang,
    required this.onTambah,
    required this.onHapus,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      color: AppColors.cardBg,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Baris atas: nama + hapus
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.nama,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(item.kode,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: AppColors.danger.withOpacity(0.8), size: 20),
                  onPressed: onHapus,
                  tooltip: 'Hapus item',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Baris bawah: harga + kontrol jumlah
            Row(
              children: [
                // Harga beli + edit
                GestureDetector(
                  onTap: onEditHarga,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: AppColors.primary.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.edit,
                            size: 12, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Harga beli',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary)),
                            Text(
                              FormatHelper.currency(item.hargaBeli),
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                // Subtotal
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Subtotal',
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade500)),
                    Text(
                      FormatHelper.currency(item.subtotal),
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                // Qty control
                Row(
                  children: [
                    _QtyBtn(
                        icon: Icons.remove,
                        onTap: onKurang,
                        color: AppColors.danger),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('${item.jumlah}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    _QtyBtn(
                        icon: Icons.add,
                        onTap: onTambah,
                        color: AppColors.primary),
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
  final VoidCallback onTap;
  final Color color;
  const _QtyBtn({required this.icon, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Bottom Sheet: Riwayat Pembelian
// ════════════════════════════════════════════════════════════════
class _RiwayatSheet extends StatelessWidget {
  const _RiwayatSheet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.bgLight,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar + judul
            Container(
              decoration: const BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Icon(Icons.history, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  const Text('Riwayat Pembelian',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.textPrimary)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const Expanded(child: _RiwayatPembelianTab()),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TAB 2 — Riwayat Pembelian
// ════════════════════════════════════════════════════════════════
class _RiwayatPembelianTab extends StatefulWidget {
  const _RiwayatPembelianTab();

  @override
  State<_RiwayatPembelianTab> createState() => _RiwayatPembelianTabState();
}

class _RiwayatPembelianTabState extends State<_RiwayatPembelianTab> {
  List<PembelianStok> _list = [];
  bool _loading = false;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final tgl =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final result =
        await KasirService.instance.getRiwayatPembelian(dari: tgl, sampai: tgl);
    if (!mounted) return;
    setState(() {
      _list = result;
      _loading = false;
    });
  }

  Future<void> _pilihTanggal() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.bgLight,
      child: Column(
        children: [
          // ── Filter tanggal ─────────────────────────────────
          Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ListTile(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.calendar_today,
                    color: AppColors.primary, size: 18),
              ),
              title: Text(
                '${_selectedDate.day.toString().padLeft(2, '0')} / '
                '${_selectedDate.month.toString().padLeft(2, '0')} / '
                '${_selectedDate.year}',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              subtitle: const Text('Tap untuk ganti tanggal',
                  style:
                      TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              onTap: _pilihTanggal,
              trailing: IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.primary),
                onPressed: _load,
                tooltip: 'Refresh',
              ),
            ),
          ),

          // ── List riwayat ───────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _list.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.receipt_long_outlined,
                                size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            const Text('Tidak ada pembelian',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500)),
                            const SizedBox(height: 4),
                            const Text('pada tanggal ini',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                        itemCount: _list.length,
                        itemBuilder: (_, i) => _RiwayatCard(p: _list[i]),
                      ),
          ),
        ],
      ),
    );
  }
}

// ── Card riwayat pembelian ─────────────────────────────────────
class _RiwayatCard extends StatelessWidget {
  final PembelianStok p;
  const _RiwayatCard({required this.p});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      color: AppColors.cardBg,
      child: ExpansionTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        collapsedShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.inventory_2_outlined,
              color: AppColors.success, size: 20),
        ),
        title: Text(p.noPembelian,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                fontSize: 14)),
        subtitle: Text(
          '${p.supplier ?? 'Tanpa supplier'}  •  ${p.namaKasir}',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              FormatHelper.currency(p.total),
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                  fontSize: 14),
            ),
            Text('${p.details.length} item',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
        children: [
          const Divider(height: 1),
          if (p.details.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Tidak ada detail',
                  style: TextStyle(color: AppColors.textSecondary)),
            )
          else
            ...p.details.map(
              (d) => ListTile(
                dense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                leading: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.settings_outlined,
                      size: 16, color: AppColors.primary),
                ),
                title: Text(d.nama,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textPrimary)),
                subtitle: Text(
                  '${FormatHelper.currency(d.hargaBeli)} × ${d.jumlah} ${d.satuan}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
                trailing: Text(
                  FormatHelper.currency(d.subtotal),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                      fontSize: 13),
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
