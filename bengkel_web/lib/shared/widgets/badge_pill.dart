// lib/shared/widgets/badge_pill.dart

import 'package:flutter/material.dart';

enum PillColor { green, red, amber, blue, purple, grey }

class BadgePill extends StatelessWidget {
  final String text;
  final PillColor color;
  final IconData? icon;

  const BadgePill({
    super.key,
    required this.text,
    required this.color,
    this.icon,
  });

  ({Color bg, Color fg}) get _colors {
    switch (color) {
      case PillColor.green:
        return (bg: const Color(0xFFE1F5EE), fg: const Color(0xFF085041));
      case PillColor.red:
        return (bg: const Color(0xFFFCEBEB), fg: const Color(0xFF791F1F));
      case PillColor.amber:
        return (bg: const Color(0xFFFAEEDA), fg: const Color(0xFF633806));
      case PillColor.blue:
        return (bg: const Color(0xFFE6F1FB), fg: const Color(0xFF0C447C));
      case PillColor.purple:
        return (bg: const Color(0xFFEEEDFE), fg: const Color(0xFF3C3489));
      case PillColor.grey:
        return (bg: const Color(0xFFF1EFE8), fg: const Color(0xFF444441));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: c.fg),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: c.fg,
            ),
          ),
        ],
      ),
    );
  }
}
