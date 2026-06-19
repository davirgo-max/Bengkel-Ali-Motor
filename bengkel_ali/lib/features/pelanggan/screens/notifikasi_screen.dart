import 'package:flutter/material.dart';
import '../services/pelanggan_service.dart';
import '../models/pelanggan_models.dart';
import '../../../core/utils/format_helper.dart';

class NotifikasiScreen extends StatefulWidget {
  const NotifikasiScreen({super.key});
  @override
  State<NotifikasiScreen> createState() => _NotifikasiScreenState();
}

class _NotifikasiScreenState extends State<NotifikasiScreen> {
  List<NotifikasiModel> _list = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await PelangganService.instance.getNotifikasi();
    if (mounted) {
      setState(() {
        if (res['success'] == true) {
          _list = (res['data']['notifikasi'] as List)
              .map((e) => NotifikasiModel.fromJson(e))
              .toList();
        }
        _loading = false;
      });
    }
  }

  Future<void> _bacaSemua() async {
    await PelangganService.instance.tandaiSemuaDibaca();
    _load();
  }

  static const _iconMap = {
    'booking_konfirmasi': (Icons.check_circle, Colors.green),
    'booking_reminder': (Icons.alarm, Colors.orange),
    'servis_mulai': (Icons.build, Colors.blue),
    'servis_sparepart': (Icons.inventory, Colors.purple),
    'servis_selesai': (Icons.done_all, Colors.teal),
    'booking_dibatalkan': (Icons.cancel, Colors.red),
    'umum': (Icons.notifications, Colors.grey),
  };

  @override
  Widget build(BuildContext context) {
    final unread = _list.where((n) => !n.isRead).length;
    return Scaffold(
      appBar: AppBar(
        title: Text('Notifikasi${unread > 0 ? ' ($unread)' : ''}'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: _bacaSemua,
              child: const Text('Baca Semua',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _list.isEmpty
              ? Center(
                  child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_off,
                        size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text('Belum ada notifikasi',
                        style: TextStyle(color: Colors.grey.shade500)),
                  ],
                ))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    itemCount: _list.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 72),
                    itemBuilder: (_, i) {
                      final n = _list[i];
                      final info = _iconMap[n.tipe] ?? _iconMap['umum']!;
                      return ListTile(
                        tileColor: n.isRead ? null : Colors.blue.shade50,
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: info.$2.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(info.$1, color: info.$2, size: 22),
                        ),
                        title: Text(n.judul,
                            style: TextStyle(
                              fontWeight: n.isRead
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                              fontSize: 14,
                            )),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(n.pesan, style: const TextStyle(fontSize: 13)),
                            const SizedBox(height: 2),
                            Text(FormatHelper.tanggalWaktu(n.createdAt),
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey.shade500)),
                          ],
                        ),
                        onTap: () async {
                          if (!n.isRead) {
                            await PelangganService.instance.tandaiDibaca(n.id);
                            _load();
                          }
                        },
                      );
                    },
                  ),
                ),
    );
  }
}
