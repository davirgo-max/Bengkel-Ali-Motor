// lib/features/owner/screens/transaksi_owner_screen.dart

import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/currency_format.dart';
import '../../../core/utils/format_helper.dart';
import '../services/owner_service.dart';

class TransaksiOwnerScreen extends StatefulWidget {
  const TransaksiOwnerScreen({super.key});

  @override
  State<TransaksiOwnerScreen> createState() => _TransaksiOwnerScreenState();
}

class _TransaksiOwnerScreenState extends State<TransaksiOwnerScreen> {
  DateTime _tanggal = DateTime.now();
  List<dynamic> _list = [];
  Map<String, dynamic> _rekap = {};
  bool _loading = false;

  static const _bulan = [
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
    'Des',
  ];

  String get _tanggalParam =>
      '${_tanggal.year}-${_tanggal.month.toString().padLeft(2, '0')}-${_tanggal.day.toString().padLeft(2, '0')}';

  String get _tanggalLabel =>
      '${_tanggal.day} ${_bulan[_tanggal.month]} ${_tanggal.year}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res =
          await OwnerService.instance.getTransaksi(tanggal: _tanggalParam);
      if (!mounted) return;
      final data =
          res['success'] == true ? res['data'] as Map<String, dynamic>? : null;
      setState(() {
        _list = data?['transaksi'] as List? ?? [];
        _rekap = data?['rekap'] as Map<String, dynamic>? ?? {};
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pilihTanggal() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tanggal,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _tanggal) {
      setState(() => _tanggal = picked);
      _load();
    }
  }

  void _showDetail(Map<String, dynamic> trx) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _DetailBottomSheet(transaksiId: trx['id'] as int),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Transaksi'),
        backgroundColor: Colors.deepPurple.shade700,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          // ── Filter tanggal ─────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                const SizedBox(width: 10),
                Text(_tanggalLabel,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _pilihTanggal,
                  icon: const Icon(Icons.edit_calendar, size: 16),
                  label: const Text('Ganti', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.deepPurple.shade700,
                    side: BorderSide(color: Colors.deepPurple.shade700),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
              ],
            ),
          ),

          // ── Rekap harian ────────────────────────────────────
          if (!_loading && _rekap.isNotEmpty)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  _rekapItem(Icons.receipt_long, 'Transaksi',
                      '${_rekap['jumlah'] ?? 0}x', Colors.blue.shade700),
                  const SizedBox(width: 16),
                  _rekapItem(
                      Icons.payments,
                      'Total',
                      formatRupiah(_rekap['total'] ?? 0),
                      Colors.green.shade700),
                  const SizedBox(width: 16),
                  _rekapItem(Icons.money, 'Cash',
                      formatRupiah(_rekap['cash'] ?? 0), Colors.teal.shade700),
                ],
              ),
            ),

          const Divider(height: 1),

          // ── List transaksi ──────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _list.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long,
                                size: 56, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text('Tidak ada transaksi',
                                style: TextStyle(color: Colors.grey.shade500)),
                            Text('pada $_tanggalLabel',
                                style: TextStyle(
                                    color: Colors.grey.shade400, fontSize: 12)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _list.length,
                          itemBuilder: (_, i) => _TransaksiCard(
                            data: _list[i] as Map<String, dynamic>,
                            onTap: () =>
                                _showDetail(_list[i] as Map<String, dynamic>),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _rekapItem(IconData icon, String label, String value, Color color) =>
      Expanded(
        child: Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold, color: color),
                  overflow: TextOverflow.ellipsis),
              Text(label,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            ]),
          ),
        ]),
      );
}

// ── Transaksi card ──────────────────────────────────────────
class _TransaksiCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  const _TransaksiCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tipe = data['tipe'] as String? ?? '-';
    final isServis = tipe == 'servis';
    final status = data['status'] as String? ?? '-';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor:
                    isServis ? Colors.blue.shade50 : Colors.teal.shade50,
                radius: 20,
                child: Icon(
                  isServis ? Icons.build : Icons.shopping_bag,
                  size: 18,
                  color: isServis ? Colors.blue.shade700 : Colors.teal.shade700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(data['no_nota'] as String? ?? '-',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      const Spacer(),
                      _statusBadge(status),
                    ]),
                    const SizedBox(height: 3),
                    if (data['nama_pelanggan'] != null)
                      Text(data['nama_pelanggan'] as String,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade700)),
                    if (isServis && data['no_booking'] != null)
                      Text(
                          '${data['no_booking']} · '
                          '${data['merk'] ?? ''} ${data['model'] ?? ''} (${data['no_polisi'] ?? ''})',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(
                        data['metode_bayar'] == 'cash'
                            ? Icons.money
                            : Icons.account_balance,
                        size: 13,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${data['metode_bayar'] ?? '-'} · ${FormatHelper.tanggalWaktu(data['tanggal'] as String? ?? '')}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade400),
                      ),
                      const Spacer(),
                      Text(
                        formatRupiah(data['grand_total'] ?? 0),
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700),
                      ),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final color = status == 'lunas'
        ? Colors.green
        : status == 'pending'
            ? Colors.orange
            : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(status,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }
}

// ── Detail bottom sheet ─────────────────────────────────────
class _DetailBottomSheet extends StatefulWidget {
  final int transaksiId;
  const _DetailBottomSheet({required this.transaksiId});

  @override
  State<_DetailBottomSheet> createState() => _DetailBottomSheetState();
}

class _DetailBottomSheetState extends State<_DetailBottomSheet> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res =
        await OwnerService.instance.getDetailTransaksi(widget.transaksiId);
    if (!mounted) return;
    setState(() {
      _data =
          res['success'] == true ? res['data'] as Map<String, dynamic>? : null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      padding: const EdgeInsets.all(20),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _data == null
              ? const Center(child: Text('Gagal memuat detail'))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final trx = _data!['transaksi'] as Map<String, dynamic>;
    final items = _data!['items'] as List? ?? [];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(trx['no_nota'] as String? ?? '-',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text(
            '${trx['nama_kasir'] ?? '-'} · '
            '${FormatHelper.tanggalWaktu(trx['tanggal'] as String? ?? '')}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const Divider(height: 20),

          if (trx['nama_pelanggan'] != null) ...[
            _row('Pelanggan', trx['nama_pelanggan'] as String),
            if (trx['no_booking'] != null)
              _row('No Booking', trx['no_booking'] as String),
            if (trx['merk'] != null)
              _row('Kendaraan',
                  '${trx['merk']} ${trx['model']} (${trx['no_polisi']})'),
            if (trx['jenis_servis'] != null)
              _row('Jenis Servis', trx['jenis_servis'] as String),
            const Divider(height: 16),
          ],

          if (items.isNotEmpty) ...[
            const Text('Item Sparepart',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...items.map((it) {
              final item = it as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Expanded(
                    child: Text(
                      '${item['nama']} ×${item['jumlah']} ${item['satuan'] ?? ''}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  Text(formatRupiah(item['subtotal'] ?? 0),
                      style: const TextStyle(fontSize: 13)),
                ]),
              );
            }),
            const Divider(height: 16),
          ],

          // trx['total_jasa'] dkk berasal dari kolom DECIMAL di MySQL, yang
          // selalu dikirim PHP sebagai String di JSON (mis. "0.00"). Bandingkan
          // String langsung dengan `> 0` melempar NoSuchMethodError ("Class
          // 'String' has no instance method '>'"), jadi di-parse dulu ke num.
          if ((double.tryParse((trx['total_jasa'] ?? 0).toString()) ?? 0) > 0)
            _row('Jasa Servis', formatRupiah(trx['total_jasa'] ?? 0)),
          if ((double.tryParse((trx['total_sparepart'] ?? 0).toString()) ?? 0) >
              0)
            _row('Sparepart', formatRupiah(trx['total_sparepart'] ?? 0)),
          if ((double.tryParse((trx['diskon'] ?? 0).toString()) ?? 0) > 0)
            _row('Diskon', '- ${formatRupiah(trx['diskon'] ?? 0)}',
                valueColor: Colors.red),
          const Divider(height: 12),
          _row('Total', formatRupiah(trx['grand_total'] ?? 0),
              bold: true, valueColor: Colors.green.shade700),
          _row('Metode Bayar', trx['metode_bayar'] as String? ?? '-'),

          // Tombol lihat foto bukti transfer -- hanya muncul kalau metode
          // bayarnya transfer DAN memang ada file bukti yang sudah diunggah
          // kasir (kolom bukti_bayar di tabel transaksi).
          if (trx['metode_bayar'] == 'transfer' &&
              (trx['bukti_bayar'] as String? ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _lihatBuktiTransfer(
                    trx['bukti_bayar'] as String, trx['no_nota'] as String?),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Lihat Foto Bukti Pembayaran'),
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _lihatBuktiTransfer(String filename, String? noNota) {
    final url = '${AppConstants.uploadUrl}/bukti_bayar/$filename';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(noNota ?? 'Bukti Pembayaran',
                style: const TextStyle(fontSize: 14)),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (ctx, child, progress) => progress == null
                    ? child
                    : const CircularProgressIndicator(color: Colors.white),
                errorBuilder: (_, __, ___) => const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.broken_image_outlined,
                        color: Colors.white54, size: 64),
                    SizedBox(height: 12),
                    Text('Gagal memuat gambar',
                        style: TextStyle(color: Colors.white54)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value,
          {bool bold = false, Color? valueColor}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                    color: valueColor)),
          ],
        ),
      );
}
