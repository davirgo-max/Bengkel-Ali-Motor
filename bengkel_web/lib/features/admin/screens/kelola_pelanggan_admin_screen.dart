// lib/features/admin/screens/kelola_pelanggan_admin_screen.dart

import 'package:flutter/material.dart';
// import '../../../core/constants/app_theme.dart';
import '../../../core/utils/format_helper.dart';
import '../../../shared/widgets/app_dialogs.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/badge_pill.dart';
import '../../../shared/widgets/date_table_card.dart';
import '../../../shared/widgets/toolbar_controls.dart';
import '../models/admin_models.dart';
import '../services/admin_service.dart';
import 'admin_shell.dart';

class KelolaPelangganAdminScreen extends StatefulWidget {
  const KelolaPelangganAdminScreen({super.key});

  @override
  State<KelolaPelangganAdminScreen> createState() =>
      _KelolaPelangganAdminScreenState();
}

class _KelolaPelangganAdminScreenState
    extends State<KelolaPelangganAdminScreen> {
  final _svc = AdminService.instance;
  final _searchCtrl = TextEditingController();

  List<PelangganAdminModel> _items = [];
  bool _loading = true;
  String? _error;
  String _filter = 'semua';
  int _page = 1;
  int _totalPages = 1;
  int _total = 0;

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
    final res = await _svc.getPelangganList(
      search: _searchCtrl.text,
      filter: _filter,
      page: _page,
    );
    if (!mounted) return;
    if (res['success'] != true) {
      setState(() {
        _loading = false;
        _error = res['message'] ?? 'Gagal memuat data';
      });
      return;
    }
    final data = res['data'] as Map<String, dynamic>? ?? {};
    final rawList = data['pelanggan'] as List? ?? [];
    setState(() {
      _loading = false;
      _items = rawList
          .whereType<Map<String, dynamic>>()
          .map(PelangganAdminModel.fromJson)
          .toList();
      _total = (data['total'] as num?)?.toInt() ?? 0;
      _totalPages = (data['total_halaman'] as num?)?.toInt() ?? 1;
    });
  }

  void _gotoPage(int p) {
    setState(() => _page = p);
    _load();
  }

  // ── Detail pelanggan ─────────────────────────────────────

  Future<void> _showDetail(PelangganAdminModel item) async {
    final nav = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);

    nav.push(PageRouteBuilder(
      opaque: false,
      barrierDismissible: false,
      barrierColor: Colors.black26,
      pageBuilder: (_, __, ___) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          ),
        ),
      ),
    ));

    final res = await _svc.getDetailPelanggan(item.id, riwayat: true);

    if (!mounted) return;
    nav.pop();

    if (res['success'] != true) {
      messenger.showSnackBar(SnackBar(
        content: Text(res['message'] ?? 'Gagal memuat detail'),
        backgroundColor: const Color(0xFFA32D2D),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    final data = res['data'];
    if (data == null || data is! Map<String, dynamic>) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Format data tidak valid'),
        backgroundColor: Color(0xFFA32D2D),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    final detail = PelangganDetailModel.fromJson(data);
    if (!mounted) return;

    // Tampilkan dialog detail — pakai StatefulWidget agar bisa blokir/buka
    // dari dalam dialog tanpa Assertion error
    await showDialog<void>(
      context: context,
      builder: (ctx) => _PelangganDetailDialog(
        detail: detail,
        svc: _svc,
        onBlokirChanged: () {
          Navigator.pop(ctx);
          _load();
        },
      ),
    );
  }

  // ── Blokir / buka blokir (dari tabel) ───────────────────

  Future<void> _bukaBlokir(PelangganAdminModel item) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Buka Blokir Pelanggan?',
      message: '${item.nama} akan bisa booking servis kembali.',
      confirmText: 'Buka Blokir',
    );
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final res = await _svc.bukaBlokirPelanggan(item.id);
    if (!mounted) return;
    if (res['success'] == true) {
      _load();
      messenger.showSnackBar(const SnackBar(
        content: Text('Blokir berhasil dibuka'),
        behavior: SnackBarBehavior.floating,
      ));
    } else {
      messenger.showSnackBar(SnackBar(
        content: Text(res['message'] ?? 'Gagal membuka blokir'),
        backgroundColor: const Color(0xFFA32D2D),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // FIX: _blokirManualDialog juga direfactor ke StatefulWidget terpisah
  Future<void> _blokirManualDialog(PelangganAdminModel item) async {
    final messenger = ScaffoldMessenger.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => _BlokirManualDialog(
        pelanggan: item,
        svc: _svc,
        onSaved: () {
          Navigator.pop(ctx);
          _load();
          messenger.showSnackBar(const SnackBar(
            content: Text('Pelanggan berhasil diblokir'),
            behavior: SnackBarBehavior.floating,
          ));
        },
        onError: (msg) => showAppSnackBar(ctx, msg, error: true),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      currentRoute: '/admin/pelanggan',
      pageTitle: 'Kelola Pelanggan',
      actions: [
        TopbarButton(
          label: 'Refresh',
          icon: Icons.refresh,
          onPressed: _load,
        ),
      ],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              SearchField(
                hint: 'Cari nama / email / no HP...',
                controller: _searchCtrl,
                onChanged: (_) {
                  _page = 1;
                  _load();
                },
                maxWidth: 300,
              ),
              const SizedBox(width: 10),
              FilterDropdown<String>(
                value: _filter,
                onChanged: (v) {
                  if (v != null) setState(() => _filter = v);
                  _page = 1;
                  _load();
                },
                items: const [
                  DropdownMenuItem(value: 'semua', child: Text('Semua Status')),
                  DropdownMenuItem(value: 'aktif', child: Text('Aktif')),
                  DropdownMenuItem(value: 'diblokir', child: Text('Diblokir')),
                ],
              ),
              const Spacer(),
              Text('$_total pelanggan',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF888899))),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        TableCard(
          loading: _loading,
          empty: _error != null
              ? Text(_error!, style: const TextStyle(color: Color(0xFFA32D2D)))
              : const Text('Belum ada data pelanggan.',
                  style: TextStyle(color: Color(0xFF888899))),
          columns: const [
            DataColumn(label: Text('NAMA')),
            DataColumn(label: Text('KONTAK')),
            DataColumn(label: Text('NO-SHOW')),
            DataColumn(label: Text('STATUS')),
            DataColumn(label: Text('AKSI')),
          ],
          rows: _items.map((p) {
            return DataRow(cells: [
              DataCell(
                InkWell(
                  onTap: () => _showDetail(p),
                  child: Text(p.nama,
                      style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline)),
                ),
              ),
              DataCell(Text(p.noHp ?? p.email ?? '—')),
              DataCell(Text('${p.totalNoshow}x')),
              DataCell(BadgePill(
                text: p.isDiblokir ? 'Diblokir' : 'Aktif',
                color: p.isDiblokir ? PillColor.red : PillColor.green,
              )),
              DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                ActionIconButton(
                  icon: Icons.visibility_outlined,
                  tooltip: 'Lihat Detail',
                  onPressed: () => _showDetail(p),
                ),
                const SizedBox(width: 4),
                if (p.isDiblokir)
                  ActionIconButton(
                    icon: Icons.lock_open_outlined,
                    tooltip: 'Buka Blokir',
                    color: const Color(0xFF0F6E56),
                    onPressed: () => _bukaBlokir(p),
                  )
                else
                  ActionIconButton(
                    icon: Icons.block_outlined,
                    tooltip: 'Blokir Manual',
                    color: const Color(0xFFA32D2D),
                    onPressed: () => _blokirManualDialog(p),
                  ),
              ])),
            ]);
          }).toList(),
        ),
        if (!_loading && _items.isNotEmpty)
          PaginationBar(
            page: _page,
            totalPages: _totalPages,
            totalItems: _total,
            perPage: 20,
            onPageChanged: _gotoPage,
          ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Dialog Detail Pelanggan — StatefulWidget dengan tab
// ══════════════════════════════════════════════════════════════════════════════

class _PelangganDetailDialog extends StatefulWidget {
  final PelangganDetailModel detail;
  final AdminService svc;
  final VoidCallback onBlokirChanged;

  const _PelangganDetailDialog({
    required this.detail,
    required this.svc,
    required this.onBlokirChanged,
  });

  @override
  State<_PelangganDetailDialog> createState() => _PelangganDetailDialogState();
}

class _PelangganDetailDialogState extends State<_PelangganDetailDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _bukaBlokir() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Buka Blokir?',
      message:
          '${widget.detail.pelanggan.nama} akan bisa booking servis kembali.',
      confirmText: 'Buka Blokir',
    );
    if (!ok || !mounted) return;
    final res =
        await widget.svc.bukaBlokirPelanggan(widget.detail.pelanggan.id);
    if (!mounted) return;
    if (res['success'] == true) {
      widget.onBlokirChanged();
    } else {
      showAppSnackBar(context, res['message'] ?? 'Gagal membuka blokir',
          error: true);
    }
  }

  Future<void> _blokirManual() async {
    final messenger = ScaffoldMessenger.of(context);
    // Tutup dulu dialog detail, lalu buka dialog blokir
    Navigator.pop(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => _BlokirManualDialog(
        pelanggan: widget.detail.pelanggan,
        svc: widget.svc,
        onSaved: () {
          Navigator.pop(ctx);
          widget.onBlokirChanged();
          messenger.showSnackBar(const SnackBar(
            content: Text('Pelanggan berhasil diblokir'),
            behavior: SnackBarBehavior.floating,
          ));
        },
        onError: (msg) => showAppSnackBar(ctx, msg, error: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.detail.pelanggan;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Column(children: [
          // ── Header ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 16, 0),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.nama,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (p.noHp != null) p.noHp!,
                          if (p.email != null) p.email!,
                        ].join(' · '),
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF888899)),
                      ),
                    ]),
              ),
              // Tombol blokir / buka blokir di header
              if (p.isDiblokir)
                OutlinedButton.icon(
                  onPressed: _bukaBlokir,
                  icon: const Icon(Icons.lock_open_outlined, size: 15),
                  label: const Text('Buka Blokir'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F6E56)),
                )
              else
                OutlinedButton.icon(
                  onPressed: _blokirManual,
                  icon: const Icon(Icons.block_outlined, size: 15),
                  label: const Text('Blokir'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFA32D2D)),
                ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 20, color: Color(0xFF888899)),
                ),
              ),
            ]),
          ),

          // ── Info singkat & status ─────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
            child: Row(children: [
              _chip('No-show: ${p.totalNoshow}x',
                  p.totalNoshow > 0 ? const Color(0xFFFAEEDA) : null),
              const SizedBox(width: 8),
              BadgePill(
                text: p.isDiblokir ? 'Diblokir' : 'Aktif',
                color: p.isDiblokir ? PillColor.red : PillColor.green,
              ),
              if (p.isDiblokir && p.blokirSampai != null) ...[
                const SizedBox(width: 8),
                Text('s.d. ${formatTanggal(p.blokirSampai)}',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF888899))),
              ],
            ]),
          ),

          // ── Tab Bar ────────────────────────────────────────
          const SizedBox(height: 12),
          TabBar(
            controller: _tabCtrl,
            labelStyle:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            tabs: [
              const Tab(text: 'Info & Kendaraan'),
              const Tab(text: 'Transaksi'),
              Tab(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Booking'),
                  if (widget.detail.bookingAktif.isNotEmpty) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3C3489),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${widget.detail.bookingAktif.length}',
                        style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ]),
              ),
              const Tab(text: 'Penalti'),
            ],
          ),

          // ── Tab Content ────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _tabInfoKendaraan(),
                _tabTransaksi(),
                _tabBookingAktif(),
                _tabPenalti(),
              ],
            ),
          ),

          // ── Footer ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tutup'),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  // Tab 1: Info & Kendaraan
  Widget _tabInfoKendaraan() {
    final d = widget.detail;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: _infoLine('No. HP', d.pelanggan.noHp ?? '—')),
          Expanded(child: _infoLine('Email', d.pelanggan.email ?? '—')),
        ]),
        const SizedBox(height: 12),
        _infoLine('Alamat', d.alamat ?? '—'),
        const SizedBox(height: 20),
        const Text('Kendaraan Terdaftar',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (d.kendaraan.isEmpty)
          const Text('Belum ada kendaraan terdaftar.',
              style: TextStyle(fontSize: 12, color: Color(0xFF888899)))
        else
          ...d.kendaraan.map((k) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F8FB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E5EF)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.directions_car_outlined,
                        size: 15, color: Color(0xFF888899)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${k.merk} ${k.model}${k.tahun != null ? ' (${k.tahun})' : ''} — ${k.noPolisi}${k.warna != null ? ' · ${k.warna}' : ''}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ]),
                ),
              )),
      ]),
    );
  }

  // Tab 2: Riwayat Transaksi
  Widget _tabTransaksi() {
    final list = widget.detail.riwayatTransaksi;
    if (list.isEmpty) {
      return const Center(
        child: Text('Belum ada riwayat transaksi.',
            style: TextStyle(fontSize: 13, color: Color(0xFF888899))),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: list.map((t) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8FB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E5EF)),
            ),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.noTransaksi,
                          style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text(
                        '${t.jenisServis}${t.noPolisi != null ? ' · ${t.noPolisi}' : ''}${t.mekanik != null ? ' · ${t.mekanik}' : ''}',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF888899)),
                      ),
                      Text(formatTanggal(t.tanggal),
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF888899))),
                    ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(formatRupiah(t.totalBayar),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                BadgePill(
                  text: t.status,
                  color:
                      t.status == 'selesai' ? PillColor.green : PillColor.grey,
                ),
              ]),
            ]),
          );
        }).toList(),
      ),
    );
  }

  // Tab 3: Booking belum selesai
  Widget _tabBookingAktif() {
    final list = widget.detail.bookingAktif;
    if (list.isEmpty) {
      return const Center(
        child: Text('Tidak ada booking yang sedang berjalan.',
            style: TextStyle(fontSize: 13, color: Color(0xFF888899))),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final b = list[i];
        return _BookingCard(
          booking: b,
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => _BookingDetailDialog(booking: b),
          ),
        );
      },
    );
  }

  // Tab 4: Penalti No-show
  Widget _tabPenalti() {
    final list = widget.detail.riwayatPenalti;
    if (list.isEmpty) {
      return const Center(
        child: Text('Tidak ada riwayat penalti.',
            style: TextStyle(fontSize: 13, color: Color(0xFF888899))),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: list.map((p) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFCEBEB),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('No-show ke-${p.noshowKe}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF791F1F))),
              if (p.noBooking != null)
                Text('Booking ${p.noBooking}',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF791F1F))),
              if (p.blokirHari != null)
                Text(
                  'Diblokir ${p.blokirHari} hari (${formatTanggal(p.blokirMulai)} – ${formatTanggal(p.blokirSampai)})',
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF791F1F)),
                ),
            ]),
          );
        }).toList(),
      ),
    );
  }

  Widget _infoLine(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF888899))),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 13)),
        ],
      );

  Widget _chip(String text, Color? bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg ?? const Color(0xFFF1F1F6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: const TextStyle(fontSize: 11, color: Color(0xFF444455))),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// Card booking belum selesai
// ══════════════════════════════════════════════════════════════════════════════

class _BookingCard extends StatelessWidget {
  final BookingAktifModel booking;
  final VoidCallback onTap;

  const _BookingCard({required this.booking, required this.onTap});

  static const _statusColor = {
    'menunggu': Color(0xFF888899),
    'dikonfirmasi': Color(0xFF0C447C),
    'aktif': Color(0xFF085041),
    'dalam_servis': Color(0xFF633806),
    'no_show': Color(0xFFA32D2D),
    'batal': Color(0xFFA32D2D),
    'dibatalkan': Color(0xFFA32D2D),
  };

  static const _statusBg = {
    'menunggu': Color(0xFFF1F1F6),
    'dikonfirmasi': Color(0xFFE6F1FB),
    'aktif': Color(0xFFE1F5EE),
    'dalam_servis': Color(0xFFFAEEDA),
    'no_show': Color(0xFFFCEBEB),
    'batal': Color(0xFFFCEBEB),
    'dibatalkan': Color(0xFFFCEBEB),
  };

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final fg = _statusColor[b.status] ?? const Color(0xFF888899);
    final bg = _statusBg[b.status] ?? const Color(0xFFF1F1F6);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8FB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E5EF)),
        ),
        child: Row(children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(b.noBooking,
                    style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                      color: bg, borderRadius: BorderRadius.circular(20)),
                  child: Text(b.statusLabel,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: fg)),
                ),
                if (b.tipe == 'walk_in') ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: const Color(0xFFEEEDFE),
                        borderRadius: BorderRadius.circular(20)),
                    child: const Text('Walk-in',
                        style:
                            TextStyle(fontSize: 10, color: Color(0xFF3C3489))),
                  ),
                ],
              ]),
              const SizedBox(height: 4),
              Text(
                '${b.merk} ${b.model} · ${b.noPolisi}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF444455)),
              ),
              Text(
                '${b.jenisServis ?? 'Servis Umum'} · ${formatTanggal(b.tanggalServis)}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF888899)),
              ),
              if (b.namaMekanik != null)
                Text('Mekanik: ${b.namaMekanik}',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF888899))),
            ]),
          ),
          const Icon(Icons.chevron_right, size: 18, color: Color(0xFFCCCCD8)),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Dialog Detail Booking — read-only, hanya lihat
// ══════════════════════════════════════════════════════════════════════════════

class _BookingDetailDialog extends StatelessWidget {
  final BookingAktifModel booking;

  const _BookingDetailDialog({required this.booking});

  static const _statusColor = {
    'menunggu': Color(0xFF888899),
    'dikonfirmasi': Color(0xFF0C447C),
    'aktif': Color(0xFF085041),
    'dalam_servis': Color(0xFF633806),
    'no_show': Color(0xFFA32D2D),
    'batal': Color(0xFFA32D2D),
    'dibatalkan': Color(0xFFA32D2D),
  };

  static const _statusBg = {
    'menunggu': Color(0xFFF1F1F6),
    'dikonfirmasi': Color(0xFFE6F1FB),
    'aktif': Color(0xFFE1F5EE),
    'dalam_servis': Color(0xFFFAEEDA),
    'no_show': Color(0xFFFCEBEB),
    'batal': Color(0xFFFCEBEB),
    'dibatalkan': Color(0xFFFCEBEB),
  };

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final fg = _statusColor[b.status] ?? const Color(0xFF888899);
    final bg = _statusBg[b.status] ?? const Color(0xFFF1F1F6);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 14, 12),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.noBooking,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace')),
                      const SizedBox(height: 4),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(20)),
                          child: Text(b.statusLabel,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: fg)),
                        ),
                        if (b.tipe == 'walk_in') ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                                color: const Color(0xFFEEEDFE),
                                borderRadius: BorderRadius.circular(20)),
                            child: const Text('Walk-in',
                                style: TextStyle(
                                    fontSize: 11, color: Color(0xFF3C3489))),
                          ),
                        ],
                      ]),
                    ]),
              ),
              InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 20, color: Color(0xFF888899)),
                ),
              ),
            ]),
          ),
          const Divider(height: 1),

          // Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Kendaraan ──────────────────────────────
                    _section('Kendaraan'),
                    _row('Kendaraan',
                        '${b.merk} ${b.model}${b.tahun != null ? ' (${b.tahun})' : ''}'),
                    _row('No. Polisi', b.noPolisi),
                    if (b.warna != null) _row('Warna', b.warna!),
                    const SizedBox(height: 16),

                    // ── Servis ─────────────────────────────────
                    _section('Servis'),
                    _row('Jenis Servis', b.jenisServis ?? '—'),
                    if (b.hargaJasa != null)
                      _row('Harga Jasa', formatRupiah(b.hargaJasa)),
                    _row('Tanggal', formatTanggal(b.tanggalServis)),
                    if (b.slotLabel != null)
                      _row('Slot Waktu',
                          '${b.slotLabel}${b.jamMulai != null ? ' (${b.jamMulai!.substring(0, 5)}–${b.jamSelesai?.substring(0, 5) ?? ''})' : ''}'),
                    if (b.keluhan != null && b.keluhan!.isNotEmpty)
                      _row('Keluhan', b.keluhan!),
                    const SizedBox(height: 16),

                    // ── Progress Servis (jika sudah ada) ───────
                    if (b.servisId != null) ...[
                      _section('Progress Servis'),
                      if (b.namaMekanik != null)
                        _row('Mekanik', b.namaMekanik!),
                      if (b.statusServis != null)
                        _row('Status Servis', b.statusServis!),
                      if (b.diagnosa != null && b.diagnosa!.isNotEmpty)
                        _row('Diagnosa', b.diagnosa!),
                      if (b.waktuMulai != null)
                        _row('Mulai', formatTanggalWaktu(b.waktuMulai)),
                      if (b.waktuSelesai != null)
                        _row('Selesai', formatTanggalWaktu(b.waktuSelesai)),
                      const SizedBox(height: 16),
                    ],

                    // ── Request Sparepart (jika ada) ───────────
                    if (b.sparepartRequest.isNotEmpty) ...[
                      _section('Request Sparepart Pelanggan'),
                      const SizedBox(height: 4),
                      ...b.sparepartRequest.map((sp) {
                        final spFg = sp.status == 'disetujui'
                            ? const Color(0xFF085041)
                            : sp.status == 'ditolak'
                                ? const Color(0xFFA32D2D)
                                : const Color(0xFF888899);
                        final spBg = sp.status == 'disetujui'
                            ? const Color(0xFFE1F5EE)
                            : sp.status == 'ditolak'
                                ? const Color(0xFFFCEBEB)
                                : const Color(0xFFF1F1F6);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F8FB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE5E5EF)),
                          ),
                          child: Row(children: [
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(sp.namaSparepart,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500)),
                                    Text(
                                      '${sp.jumlah} ${sp.satuan}  ×  ${formatRupiah(sp.hargaJual)}  =  ${formatRupiah(sp.subtotal)}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF888899)),
                                    ),
                                  ]),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                  color: spBg,
                                  borderRadius: BorderRadius.circular(20)),
                              child: Text(sp.status,
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: spFg)),
                            ),
                          ]),
                        );
                      }),
                    ],
                  ]),
            ),
          ),

          // Footer
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tutup'),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF888899),
                letterSpacing: 0.5)),
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: Color(0xFF888899))),
          ),
          const Text(': ',
              style: TextStyle(fontSize: 12, color: Color(0xFF888899))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ]),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// ══════════════════════════════════════════════════════════════════════════════

class _BlokirManualDialog extends StatefulWidget {
  final PelangganAdminModel pelanggan;
  final AdminService svc;
  final VoidCallback onSaved;
  final void Function(String msg) onError;

  const _BlokirManualDialog({
    required this.pelanggan,
    required this.svc,
    required this.onSaved,
    required this.onError,
  });

  @override
  State<_BlokirManualDialog> createState() => _BlokirManualDialogState();
}

class _BlokirManualDialogState extends State<_BlokirManualDialog> {
  late final TextEditingController _alasanCtrl;
  late final TextEditingController _hariCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _alasanCtrl = TextEditingController();
    _hariCtrl = TextEditingController(text: '7');
  }

  @override
  void dispose() {
    _alasanCtrl.dispose();
    _hariCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final alasan = _alasanCtrl.text.trim();
    if (alasan.isEmpty) {
      widget.onError('Alasan blokir wajib diisi');
      return;
    }
    setState(() => _saving = true);
    final res = await widget.svc.blokirManual(
      widget.pelanggan.id,
      alasan: alasan,
      hari: int.tryParse(_hariCtrl.text),
    );
    if (!mounted) return;
    if (res['success'] == true) {
      widget.onSaved();
    } else {
      setState(() => _saving = false);
      widget.onError(res['message'] ?? 'Gagal memblokir');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(
                    'Blokir Manual — ${widget.pelanggan.nama}',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600),
                  ),
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
              const FieldLabel('Lama Blokir (hari)'),
              TextField(
                controller: _hariCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    hintText: 'Kosongkan untuk blokir permanen'),
              ),
              const SizedBox(height: 14),
              const FieldLabel('Alasan', required: true),
              TextField(
                controller: _alasanCtrl,
                maxLines: 2,
                decoration:
                    const InputDecoration(hintText: 'Alasan pemblokiran'),
              ),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Batal')),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFA32D2D)),
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Blokir Pelanggan'),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
