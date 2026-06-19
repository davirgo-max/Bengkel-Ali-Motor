// lib/shared/widgets/stat_card.dart

import 'package:flutter/material.dart';
import '../../core/constants/app_theme.dart';

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final Color? valueColor;
  final bool subUp;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.sub,
    this.valueColor,
    this.subUp = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.sidebarBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8E8EE), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF888899)),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: valueColor ?? const Color(0xFF1A1A2E),
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 3),
            Text(
              sub!,
              style: TextStyle(
                fontSize: 11,
                color: subUp
                    ? const Color(0xFF0F6E56)
                    : const Color(0xFF888899),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Baris kartu statistik responsif (wrap otomatis di layar sempit).
class StatRow extends StatelessWidget {
  final List<StatCard> cards;
  const StatRow({super.key, required this.cards});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final perRow = constraints.maxWidth > 900
            ? 4
            : (constraints.maxWidth > 560 ? 2 : 1);
        final width = (constraints.maxWidth - (perRow - 1) * 12) / perRow;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards.map((c) => SizedBox(width: width, child: c)).toList(),
        );
      },
    );
  }
}
