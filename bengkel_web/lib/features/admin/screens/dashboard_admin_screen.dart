// lib/features/admin/screens/dashboard_admin_screen.dart
//
// Dashboard Admin — 4 stat card + tabel stok kritis
//                   + panel hari libur mendatang & status akun staff

import 'package:flutter/material.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/utils/format_helper.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/stat_card.dart';
import '../models/admin_models.dart';
import '../services/admin_service.dart';
import 'admin_shell.dart';

class DashboardAdminScreen extends StatefulWidget {
  const DashboardAdminScreen({super.key});

  @override
  State<DashboardAdminScreen> createState() => _DashboardAdminScreenState();
}

class _DashboardAdminScreenState extends State<DashboardAdminScreen> {
  final _svc = AdminService.instance;

  AdminDashboardData? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final data = await _svc.getDashboard();
    if (!mounted) return;
    if (data == null) {
      setState(() {
        _loading = false;
        _error = 'Gagal memuat data dashboard';
      });
      return;
    }
    setState(() {
      _loading = false;
      _data = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      currentRoute: '/admin/dashboard',
      pageTitle: 'Dashboard',
      actions: [
        TopbarButton(
          label: 'Refresh',
          icon: Icons.refresh,
          onPressed: _load,
        ),
      ],
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(60),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 40, color: Color(0xFFAAAAB8)),
              const SizedBox(height: 12),
              Text(_error!,
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xFF888899))),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 15),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    final d = _data!;
    final stat = d.statCard;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 4 Stat Card ─────────────────────────────────────
        StatRow(cards: [
          StatCard(
            label: 'Sparepart Kritis',
            value: '${stat.stokKritis}',
            sub: stat.stokKritis == 0
                ? 'Semua stok aman'
                : 'Perlu restock segera',
            valueColor: stat.stokKritis > 0
                ? const Color(0xFFA32D2D)
                : const Color(0xFF0F6E56),
          ),
          StatCard(
            label: 'Mekanik Aktif',
            value: '${stat.mekanikAktif}',
            sub: 'Siap terima servis',
          ),
          StatCard(
            label: 'Pelanggan Diblokir',
            value: '${stat.pelangganDiblokir}',
            sub: stat.pelangganDiblokir == 0
                ? 'Tidak ada blokir'
                : 'Aktif diblokir',
            valueColor:
                stat.pelangganDiblokir > 0 ? const Color(0xFF9C4A00) : null,
          ),
          StatCard(
            label: 'Hari Libur Bulan Ini',
            value: '${stat.hariLiburBulanIni}',
            sub: 'Bulan ${_bulanIni()}',
          ),
        ]),

        const SizedBox(height: 20),

        // ── Baris bawah: Stok Kritis + (Hari Libur & Status Staff) ──
        LayoutBuilder(builder: (ctx, constraints) {
          final wide = constraints.maxWidth > 800;
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildStokKritis(d.stokKritis)),
                const SizedBox(width: 16),
                SizedBox(
                  width: 280,
                  child: Column(
                    children: [
                      _buildHariLibur(d.hariLiburMendatang),
                      const SizedBox(height: 16),
                      _buildStatusStaff(d.statusStaff),
                    ],
                  ),
                ),
              ],
            );
          }
          return Column(
            children: [
              _buildStokKritis(d.stokKritis),
              const SizedBox(height: 16),
              _buildHariLibur(d.hariLiburMendatang),
              const SizedBox(height: 16),
              _buildStatusStaff(d.statusStaff),
            ],
          );
        }),
      ],
    );
  }

  // ── Panel: Tabel Stok Kritis ─────────────────────────────
  Widget _buildStokKritis(List<StokKritisItem> items) {
    return _PanelCard(
      title: 'Stok Kritis',
      icon: Icons.inventory_2_outlined,
      iconColor: const Color(0xFFA32D2D),
      trailing: items.isEmpty
          ? null
          : Text(
              '${items.length} item',
              style: const TextStyle(fontSize: 11, color: Color(0xFF888899)),
            ),
      child: items.isEmpty
          ? _emptyState(
              'Semua stok dalam kondisi aman', Icons.check_circle_outline)
          : Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    _th('Sparepart', flex: 3),
                    _th('Stok', flex: 1, center: true),
                    _th('Min', flex: 1, center: true),
                    _th('Status', flex: 1, center: true),
                  ]),
                ),
                const Divider(height: 0, thickness: 0.5),
                const SizedBox(height: 4),
                ...items.map((s) => _StokKritisRow(item: s)),
              ],
            ),
    );
  }

  Widget _th(String label, {int flex = 1, bool center = false}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        textAlign: center ? TextAlign.center : TextAlign.start,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: Color(0xFF888899),
          letterSpacing: 0.03,
        ),
      ),
    );
  }

  // ── Panel: Hari Libur Mendatang ──────────────────────────
  Widget _buildHariLibur(List<HariLiburModel> items) {
    return _PanelCard(
      title: 'Hari Libur Mendatang',
      icon: Icons.calendar_month_outlined,
      iconColor: AppTheme.primary,
      child: items.isEmpty
          ? _emptyState('Tidak ada hari libur\ndalam 30 hari ke depan',
              Icons.event_available)
          : Column(
              children: items.map((h) => _HariLiburRow(item: h)).toList(),
            ),
    );
  }

  // ── Panel: Status Staff ──────────────────────────────────
  Widget _buildStatusStaff(List<StatusStaffItem> items) {
    return _PanelCard(
      title: 'Status Akun Staff',
      icon: Icons.manage_accounts_outlined,
      iconColor: const Color(0xFF0F6E56),
      child: items.isEmpty
          ? _emptyState('Belum ada data staff', Icons.person_off_outlined)
          : Column(
              children: items.map((s) => _StatusStaffRow(item: s)).toList(),
            ),
    );
  }

  Widget _emptyState(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Icon(icon, size: 28, color: const Color(0xFFCCCCD8)),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Color(0xFFAAAAB8)),
          ),
        ],
      ),
    );
  }

  String _bulanIni() {
    const bulan = [
      '',
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember'
    ];
    return bulan[DateTime.now().month];
  }
}

// ── Baris tabel stok kritis ──────────────────────────────
class _StokKritisRow extends StatelessWidget {
  final StokKritisItem item;
  const _StokKritisRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final pillBg =
        item.habis ? const Color(0xFFFAEAEA) : const Color(0xFFFFF3E0);
    final pillFg =
        item.habis ? const Color(0xFFA32D2D) : const Color(0xFF9C4A00);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.nama,
                    style:
                        const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E)),
                    overflow: TextOverflow.ellipsis),
                if (item.kategori != null)
                  Text(item.kategori!,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF888899))),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '${item.stok} ${item.satuan}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: item.habis
                    ? const Color(0xFFA32D2D)
                    : const Color(0xFF9C4A00),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '${item.stokMinimum}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF888899)),
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: pillBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  item.habis ? 'Habis' : 'Menipis',
                  style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w500, color: pillFg),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Baris hari libur ─────────────────────────────────────
class _HariLiburRow extends StatelessWidget {
  final HariLiburModel item;
  const _HariLiburRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.tryParse(item.tanggal);
    final selisih = dt
        ?.difference(DateTime.now()
            .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0))
        .inDays;
    final selisihTxt = selisih != null
        ? (selisih == 0 ? 'Hari ini' : '$selisih hari lagi')
        : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.keterangan,
                    style:
                        const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(formatTanggal(item.tanggal),
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF888899))),
              ],
            ),
          ),
          if (selisihTxt.isNotEmpty)
            Text(selisihTxt,
                style: const TextStyle(fontSize: 11, color: Color(0xFF534AB7))),
        ],
      ),
    );
  }
}

// ── Baris status staff ───────────────────────────────────
class _StatusStaffRow extends StatelessWidget {
  final StatusStaffItem item;
  const _StatusStaffRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final label = item.role == 'kasir' ? 'Kasir' : 'Owner';
    final colors = avatarColorFor(item.role);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: colors[0],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                label[0],
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: colors[1]),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E))),
          ),
          _badge('${item.aktif} aktif', const Color(0xFFE1F5EE),
              const Color(0xFF0F6E56)),
          const SizedBox(width: 6),
          if (item.nonaktif > 0)
            _badge('${item.nonaktif} nonaktif', const Color(0xFFF1EFE8),
                const Color(0xFF888899)),
        ],
      ),
    );
  }

  Widget _badge(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style:
              TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: fg)),
    );
  }
}

// ── Panel card reusable ──────────────────────────────────
class _PanelCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget? trailing;
  final Widget child;

  const _PanelCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8EE), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 0, thickness: 0.5),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
