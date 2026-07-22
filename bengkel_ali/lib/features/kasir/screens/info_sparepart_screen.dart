// lib/features/kasir/screens/info_sparepart_screen.dart
//
// "Info Suku Cadang" untuk kasir -- sama persis dengan tampilan katalog
// suku cadang di sisi pelanggan (search, filter kategori, foto, harga,
// stok), tapi hanya untuk MELIHAT. Tidak ada tambah ke keranjang / jual
// di sini -- untuk transaksi jual/beli tetap lewat menu "Sparepart" di
// tab bawah.

import 'package:flutter/material.dart';
import '../services/kasir_service.dart';
import '../../pelanggan/models/pelanggan_models.dart';
import '../../pelanggan/screens/sparepart_screen.dart'
    show SparepartImage, SparepartHeroImage, StokBadge;
import '../../../core/utils/format_helper.dart';

class InfoSparepartScreen extends StatefulWidget {
  const InfoSparepartScreen({super.key});
  @override
  State<InfoSparepartScreen> createState() => _InfoSparepartScreenState();
}

class _InfoSparepartScreenState extends State<InfoSparepartScreen> {
  List<SparepartModel> _list = [];
  List<KategoriModel> _kategori = [];
  int? _selectedKategori;
  bool _loading = true;
  String _search = '';
  final _searchCtrl = TextEditingController();

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
    final res = await KasirService.instance.getInfoSparepart(
      search: _search.isEmpty ? null : _search,
      kategoriId: _selectedKategori,
    );
    if (mounted && res['success'] == true) {
      final data = res['data'] as Map<String, dynamic>;
      setState(() {
        _list = (data['sparepart'] as List)
            .map((e) => SparepartModel.fromJson(e))
            .toList();
        _kategori = (data['kategori'] as List)
            .map((e) => KategoriModel.fromJson(e))
            .toList();
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Info Suku Cadang'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Cari nama / kode sparepart...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _search = '');
                          _load();
                        })
                    : null,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) => setState(() => _search = v),
              onSubmitted: (_) => _load(),
            ),
          ),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _chip('Semua', null),
                ..._kategori.map((k) => _chip(k.nama, k.id)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _list.isEmpty
                    ? Center(
                        child: Text('Tidak ada sparepart',
                            style: TextStyle(color: Colors.grey.shade500)))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: _list.length,
                          itemBuilder: (_, i) => _InfoSparepartCard(
                            item: _list[i],
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => _InfoSparepartDetailScreen(
                                        id: _list[i].id))),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, int? id) {
    final active = _selectedKategori == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label,
            style:
                TextStyle(fontSize: 12, color: active ? Colors.white : null)),
        selected: active,
        selectedColor: Colors.indigo.shade700,
        onSelected: (_) {
          setState(() => _selectedKategori = id);
          _load();
        },
      ),
    );
  }
}

class _InfoSparepartCard extends StatelessWidget {
  final SparepartModel item;
  final VoidCallback onTap;
  const _InfoSparepartCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SparepartImage(foto: item.foto, size: 70),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.kategori != null)
                      Text(item.kategori!,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500)),
                    const SizedBox(height: 2),
                    Text(item.nama,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(FormatHelper.currency(item.hargaJual),
                        style: TextStyle(
                            color: Colors.indigo.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StokBadge(tersedia: item.tersedia),
                  const SizedBox(height: 4),
                  Text('${item.stok} ${item.satuan}',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoSparepartDetailScreen extends StatefulWidget {
  final int id;
  const _InfoSparepartDetailScreen({required this.id});
  @override
  State<_InfoSparepartDetailScreen> createState() =>
      _InfoSparepartDetailScreenState();
}

class _InfoSparepartDetailScreenState
    extends State<_InfoSparepartDetailScreen> {
  SparepartModel? _item;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    KasirService.instance.getInfoSparepartDetail(widget.id).then((res) {
      if (mounted && res['success'] == true) {
        setState(() {
          _item = SparepartModel.fromJson(res['data']);
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Suku Cadang'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _item == null
              ? const Center(child: Text('Data tidak ditemukan'))
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SparepartHeroImage(foto: _item!.foto),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_item!.kategori != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.teal.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(_item!.kategori!,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.teal.shade700)),
                              ),
                            const SizedBox(height: 8),
                            Text(_item!.nama,
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold)),
                            Text(_item!.kode,
                                style: TextStyle(
                                    color: Colors.grey.shade500, fontSize: 13)),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  FormatHelper.currency(_item!.hargaJual),
                                  style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.indigo.shade700),
                                ),
                                StokBadge(tersedia: _item!.tersedia),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Card(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Column(children: [
                                  _row('Satuan', _item!.satuan),
                                  _row('Stok',
                                      '${_item!.stok} ${_item!.satuan}'),
                                  _row(
                                      'Status',
                                      _item!.tersedia
                                          ? '✅ Tersedia'
                                          : '❌ Habis'),
                                ]),
                              ),
                            ),
                            if (_item!.deskripsi != null &&
                                _item!.deskripsi!.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              const Text('Deskripsi',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15)),
                              const SizedBox(height: 8),
                              Text(_item!.deskripsi!,
                                  style: TextStyle(
                                      color: Colors.grey.shade700,
                                      height: 1.5)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _row(String label, String value) => ListTile(
        dense: true,
        title: Text(label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        trailing: Text(value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      );
}
