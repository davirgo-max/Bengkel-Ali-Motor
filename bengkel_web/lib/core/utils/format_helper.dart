// lib/core/utils/format_helper.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

String formatRupiah(dynamic amount) {
  final num val = amount is num ? amount : num.tryParse(amount.toString()) ?? 0;
  return NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  ).format(val);
}

/// Format singkat untuk kartu statistik, contoh: 4200000 -> "4,2 jt"
String formatRupiahSingkat(dynamic amount) {
  final num val = amount is num ? amount : num.tryParse(amount.toString()) ?? 0;
  final v = val.toDouble();
  if (v >= 1000000000) {
    return '${(v / 1000000000).toStringAsFixed(1).replaceAll('.', ',')} M';
  }
  if (v >= 1000000) {
    return '${(v / 1000000).toStringAsFixed(1).replaceAll('.', ',')} jt';
  }
  if (v >= 1000) {
    return '${(v / 1000).toStringAsFixed(0)} rb';
  }
  return v.toStringAsFixed(0);
}

String formatTanggal(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return '-';
  try {
    final dt = DateTime.parse(dateStr);
    return DateFormat('dd MMM yyyy', 'id_ID').format(dt);
  } catch (_) {
    return dateStr;
  }
}

String formatTanggalWaktu(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return '-';
  try {
    final dt = DateTime.parse(dateStr);
    return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(dt);
  } catch (_) {
    return dateStr;
  }
}

String initialsOf(String nama) {
  final parts = nama.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  return nama.isNotEmpty ? nama[0].toUpperCase() : '?';
}

/// Palet warna avatar yang konsisten (deterministik berdasar nama),
/// senada dengan warna pill di mockup (ungu/hijau/oranye/abu).
const List<List<Color>> avatarPalette = [
  [Color(0xFFEEEDFE), Color(0xFF3C3489)], // ungu
  [Color(0xFFE1F5EE), Color(0xFF085041)], // hijau
  [Color(0xFFFAEEDA), Color(0xFF633806)], // oranye
  [Color(0xFFE6F1FB), Color(0xFF0C447C)], // biru
  [Color(0xFFF1EFE8), Color(0xFF444441)], // abu
];

List<Color> avatarColorFor(String seed) {
  final idx =
      seed.codeUnits.fold<int>(0, (a, b) => a + b) % avatarPalette.length;
  return avatarPalette[idx];
}
