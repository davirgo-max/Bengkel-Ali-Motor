import 'package:intl/intl.dart';

String formatRupiah(dynamic amount) {
  final num val = amount is num ? amount : num.tryParse(amount.toString()) ?? 0;
  return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(val);
}

String formatTanggal(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return '-';
  try {
    final dt = DateTime.parse(dateStr);
    return DateFormat('dd MMM yyyy', 'id_ID').format(dt);
  } catch (_) { return dateStr; }
}

String formatTanggalWaktu(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return '-';
  try {
    final dt = DateTime.parse(dateStr);
    return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(dt);
  } catch (_) { return dateStr; }
}
