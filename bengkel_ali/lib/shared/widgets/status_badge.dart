import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});

  static const _map = {
    'menunggu':       (Colors.orange, 'Menunggu'),
    'dikonfirmasi':   (Colors.blue,   'Dikonfirmasi'),
    'aktif':          (Colors.teal,   'Aktif'),
    'antrian':        (Colors.orange, 'Antrian'),
    'dikerjakan':     (Colors.blue,   'Dikerjakan'),
    'menunggu_part':  (Colors.purple, 'Tunggu Part'),
    'selesai_servis': (Colors.teal,   'Selesai Servis'),
    'selesai':        (Colors.green,  'Selesai'),
    'dibatalkan':     (Colors.red,    'Dibatalkan'),
    'no_show':        (Colors.grey,   'Tidak Hadir'),
  };

  @override
  Widget build(BuildContext context) {
    final info = _map[status];
    final color = info?.$1 ?? Colors.grey;
    final label = info?.$2 ?? status;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
