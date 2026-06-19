// lib/shared/widgets/data_table_card.dart

import 'package:flutter/material.dart';

/// Bungkus DataTable dengan border+radius senada mockup `.table-wrap`,
/// dan scroll horizontal otomatis bila kolom terlalu lebar.
class TableCard extends StatelessWidget {
  final List<DataColumn> columns;
  final List<DataRow> rows;
  final Widget? empty;
  final bool loading;
  final double? columnSpacing;
  final double? horizontalMargin;

  /// Jika true (default), tabel dipaksa selebar layar walau kontennya
  /// sempit — cocok untuk tabel berkolom banyak (sparepart, pelanggan, dll)
  /// agar tidak terlihat "menggantung" di kiri. Set false untuk tabel
  /// berkolom sedikit/pendek (mis. Hari Libur) supaya kolom tidak
  /// direnggangkan paksa mengisi sisa layar.
  final bool stretch;

  const TableCard({
    super.key,
    required this.columns,
    required this.rows,
    this.empty,
    this.loading = false,
    this.columnSpacing,
    this.horizontalMargin,
    this.stretch = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE8E8EE), width: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: loading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          : rows.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: empty ??
                        const Text(
                          'Tidak ada data',
                          style:
                              TextStyle(color: Color(0xFF888899), fontSize: 13),
                        ),
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: stretch ? MediaQuery.of(context).size.width : 0,
                    ),
                    child: DataTable(
                      columns: columns,
                      rows: rows,
                      columnSpacing: columnSpacing,
                      horizontalMargin: horizontalMargin,
                    ),
                  ),
                ),
    );
  }
}

/// Tombol ikon kecil bulat-sudut untuk baris aksi tabel (edit/hapus/dll).
class ActionIconButton extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback? onPressed;
  final Color? color;

  const ActionIconButton({
    super.key,
    required this.icon,
    this.tooltip,
    this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final btn = Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDDDE8)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Icon(icon, size: 15, color: color ?? const Color(0xFF666680)),
      ),
    );
    if (tooltip == null) return btn;
    return Tooltip(message: tooltip!, child: btn);
  }
}

class PaginationBar extends StatelessWidget {
  final int page;
  final int totalPages;
  final int totalItems;
  final int perPage;
  final ValueChanged<int> onPageChanged;

  const PaginationBar({
    super.key,
    required this.page,
    required this.totalPages,
    required this.totalItems,
    required this.perPage,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (totalItems == 0) return const SizedBox.shrink();
    final start = (page - 1) * perPage + 1;
    final end = (start + perPage - 1).clamp(0, totalItems);

    final pagesToShow = <int>{};
    pagesToShow.add(1);
    pagesToShow.add(totalPages);
    for (var p = page - 1; p <= page + 1; p++) {
      if (p >= 1 && p <= totalPages) pagesToShow.add(p);
    }
    final sorted = pagesToShow.toList()..sort();

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Menampilkan $start–$end dari $totalItems item',
            style: const TextStyle(fontSize: 11, color: Color(0xFF888899)),
          ),
          Row(
            children: [
              _navBtn(
                Icons.chevron_left,
                page > 1 ? () => onPageChanged(page - 1) : null,
              ),
              const SizedBox(width: 4),
              for (int i = 0; i < sorted.length; i++) ...[
                if (i > 0 && sorted[i] - sorted[i - 1] > 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '…',
                      style: TextStyle(fontSize: 12, color: Color(0xFF888899)),
                    ),
                  ),
                _pageBtn(sorted[i]),
                const SizedBox(width: 4),
              ],
              _navBtn(
                Icons.chevron_right,
                page < totalPages ? () => onPageChanged(page + 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback? onTap) => Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFDDDDE8)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Icon(
            icon,
            size: 16,
            color: onTap == null
                ? const Color(0xFFCCCCD6)
                : const Color(0xFF666680),
          ),
        ),
      );

  Widget _pageBtn(int p) {
    final active = p == page;
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: active ? const Color(0xFF534AB7) : null,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: active ? const Color(0xFF534AB7) : const Color(0xFFDDDDE8),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: active ? null : () => onPageChanged(p),
        child: Center(
          child: Text(
            '$p',
            style: TextStyle(
              fontSize: 12,
              color: active ? Colors.white : const Color(0xFF666680),
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
