// lib/features/kasir/screens/transaksi_kasir_screen.dart

import 'package:flutter/material.dart';
import '../../../core/utils/format_helper.dart';
import '../services/kasir_service.dart';
import 'servis_kasir_screen.dart';

class TransaksiKasirScreen extends StatefulWidget {
  const TransaksiKasirScreen({super.key});
  @override
  State<TransaksiKasirScreen> createState() => _TransaksiKasirScreenState();
}

class _TransaksiKasirScreenState extends State<TransaksiKasirScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _list = [];
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final tgl = _fmtDate(_selectedDate);
      final res = await KasirService.instance.getRiwayatTransaksi(tanggal: tgl);
      if (!mounted) return;
      setState(() {
        final rawData = res['data']?['transaksi'];
        _list = (res['success'] == true && rawData is List)
            ? List<Map<String, dynamic>>.from(rawData)
            : [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _list = [];
        _loading = false;
      });
    }
  }

  Future<void> _pilihTanggal() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadData();
    }
  }

  String _fmtDate(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  void _bukaaNota(Map<String, dynamic> data) {
    // Sama seperti di _TransaksiCard: id/grand_total dari API bisa berupa
    // String (kolom DECIMAL selalu dikirim PHP sebagai string di JSON),
    // jadi jangan pakai `as num?` langsung -- itu bikin fungsi ini crash
    // diam-diam sebelum sempat Navigator.push, alias tombol "terasa" tidak
    // merespons sama sekali.
    final trxId = int.tryParse(data['id'].toString());
    if (trxId == null) return;
    final noNota = data['no_nota'] as String? ?? '';
    final metodeBayar = data['metode_bayar'] as String? ?? 'cash';
    final grandTotal = double.tryParse(
            (data['grand_total'] ?? data['total'] ?? 0).toString()) ??
        0;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotaScreen(
          transaksiId: trxId,
          noNota: noNota,
          metodeBayar: metodeBayar,
          grandTotal: grandTotal,
          jumlahBayar: grandTotal,
          kembalian: 0,
          fromRiwayat: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Riwayat Transaksi'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter Tanggal ──────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: GestureDetector(
              onTap: _pilihTanggal,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 16, color: Colors.indigo.shade700),
                    const SizedBox(width: 8),
                    Text(FormatHelper.tanggal(_fmtDate(_selectedDate)),
                        style: const TextStyle(fontSize: 13)),
                    const Spacer(),
                    Icon(Icons.arrow_drop_down, color: Colors.grey.shade500),
                  ],
                ),
              ),
            ),
          ),

          // ── List Transaksi ──────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _list.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined,
                                size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text('Belum ada transaksi',
                                style: TextStyle(color: Colors.grey.shade500)),
                            const SizedBox(height: 8),
                            Text('Transaksi muncul setelah pembayaran selesai',
                                style: TextStyle(
                                    color: Colors.grey.shade400, fontSize: 12)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _list.length,
                          itemBuilder: (_, i) => _TransaksiCard(
                            data: _list[i],
                            onTap: () => _bukaaNota(_list[i]),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ── Kartu Transaksi ───────────────────────────────────────
class _TransaksiCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  const _TransaksiCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final metodeBayar = data['metode_bayar'] as String? ?? 'cash';
    final tipe = data['tipe'] as String? ?? 'servis';
    final isSparepart = tipe == 'penjualan_sparepart';
    final total = double.tryParse(
            (data['grand_total'] ?? data['total'] ?? 0).toString()) ??
        0;

    final judulText = isSparepart
        ? (data['no_nota'] as String? ?? '-')
        : (data['no_booking'] as String? ?? '-');

    final subtitleText = isSparepart
        ? 'Penjualan Sparepart (Tanpa Pelanggan)'
        : (data['nama_pelanggan'] as String? ?? '-');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(judulText,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isSparepart
                          ? Colors.orange.shade50
                          : Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isSparepart
                          ? 'SPAREPART'
                          : (data['no_booking'] != null
                              ? 'BOOKING'
                              : 'WALK-IN'),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSparepart
                              ? Colors.orange.shade700
                              : Colors.purple.shade700),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: metodeBayar == 'transfer'
                          ? Colors.teal.shade50
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      metodeBayar.toUpperCase(),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: metodeBayar == 'transfer'
                              ? Colors.teal.shade700
                              : Colors.blue.shade700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(subtitleText,
                  style: TextStyle(
                      fontSize: 13,
                      color: isSparepart
                          ? Colors.orange.shade400
                          : Colors.grey.shade600,
                      fontStyle:
                          isSparepart ? FontStyle.italic : FontStyle.normal)),
              const Divider(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total Bayar',
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  Text(FormatHelper.currency(total),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.teal)),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.receipt_long, size: 16),
                  label: const Text('Lihat / Cetak Nota'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.indigo.shade700,
                    side: BorderSide(color: Colors.indigo.shade200),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
