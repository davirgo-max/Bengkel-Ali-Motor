// lib/features/pelanggan/models/pelanggan_models.dart
// Satu file model untuk semua kebutuhan fitur pelanggan

// ── Helper parsing aman ───────────────────────────────────
int _parseInt(dynamic v) => v == null ? 0 : int.tryParse(v.toString()) ?? 0;
double _parseDouble(dynamic v) =>
    v == null ? 0.0 : double.tryParse(v.toString()) ?? 0.0;

// ── Kendaraan ─────────────────────────────────────────────
class KendaraanModel {
  final int id;
  final String merk, model, noPolisi;
  final int? tahun;
  final String? warna;

  const KendaraanModel({
    required this.id,
    required this.merk,
    required this.model,
    required this.noPolisi,
    this.tahun,
    this.warna,
  });

  factory KendaraanModel.fromJson(Map<String, dynamic> j) => KendaraanModel(
        id: _parseInt(j['id']),
        merk: j['merk'] ?? '',
        model: j['model'] ?? '',
        noPolisi: j['no_polisi'] ?? '',
        tahun: j['tahun'] != null ? int.tryParse(j['tahun'].toString()) : null,
        warna: j['warna'] as String?,
      );

  String get label => '$merk $model • $noPolisi';
}

// ── Sparepart ─────────────────────────────────────────────
class SparepartModel {
  final int id, stok;
  final String kode, nama, satuan;
  final double hargaJual;
  final String? foto, kategori, deskripsi;
  final bool tersedia;

  const SparepartModel({
    required this.id,
    required this.kode,
    required this.nama,
    required this.satuan,
    required this.hargaJual,
    required this.stok,
    this.foto,
    this.kategori,
    this.deskripsi,
    required this.tersedia,
  });

  factory SparepartModel.fromJson(Map<String, dynamic> j) => SparepartModel(
        id: _parseInt(j['id']),
        kode: j['kode'] ?? '',
        nama: j['nama'] ?? '',
        satuan: j['satuan'] ?? 'pcs',
        hargaJual: _parseDouble(j['harga_jual'] ?? 0),
        stok: _parseInt(j['stok'] ?? 0),
        foto: j['foto'] as String?,
        kategori: j['kategori'] as String?,
        deskripsi: j['deskripsi'] as String?,
        tersedia:
            j['tersedia'] == true || j['tersedia'] == 1 || j['tersedia'] == '1',
      );
}

// ── Kategori Sparepart ────────────────────────────────────
class KategoriModel {
  final int id;
  final String nama;

  const KategoriModel({required this.id, required this.nama});

  factory KategoriModel.fromJson(Map<String, dynamic> j) =>
      KategoriModel(id: _parseInt(j['id']), nama: j['nama'] ?? '');
}

// ── Jenis Servis ──────────────────────────────────────────
class JenisServisModel {
  final int id, estimasiMenit;
  final String nama;
  final double hargaJasa;
  final String? deskripsi;

  const JenisServisModel({
    required this.id,
    required this.nama,
    required this.hargaJasa,
    required this.estimasiMenit,
    this.deskripsi,
  });

  factory JenisServisModel.fromJson(Map<String, dynamic> j) => JenisServisModel(
        id: _parseInt(j['id']),
        nama: j['nama'] ?? '',
        hargaJasa: _parseDouble(j['harga_jasa'] ?? 0),
        estimasiMenit: _parseInt(j['estimasi_menit'] ?? 60),
        deskripsi: j['deskripsi'] as String?,
      );
}

// ── Slot Waktu ────────────────────────────────────────────
class SlotWaktuModel {
  final int id;
  final String jamMulai, jamSelesai, label;
  final bool tersedia;
  final String? alasan;

  const SlotWaktuModel({
    required this.id,
    required this.jamMulai,
    required this.jamSelesai,
    required this.label,
    required this.tersedia,
    this.alasan,
  });

  factory SlotWaktuModel.fromJson(Map<String, dynamic> j) => SlotWaktuModel(
        id: _parseInt(j['id']),
        jamMulai: j['jam_mulai'] as String,
        jamSelesai: j['jam_selesai'] as String,
        label: j['label'] as String,
        tersedia:
            j['tersedia'] == true || j['tersedia'] == 1 || j['tersedia'] == '1',
        alasan: j['alasan'] as String?,
      );
}

class SlotResponse {
  final int slotDibutuhkan;
  final String estimasiSelesai;
  final List<SlotWaktuModel> slots;

  const SlotResponse({
    required this.slotDibutuhkan,
    required this.estimasiSelesai,
    required this.slots,
  });

  factory SlotResponse.fromJson(Map<String, dynamic> j) => SlotResponse(
        slotDibutuhkan: _parseInt(j['slot_dibutuhkan']),
        estimasiSelesai: j['estimasi_selesai'] as String,
        slots: (j['slots'] as List)
            .map((e) => SlotWaktuModel.fromJson(e))
            .toList(),
      );
}

// ── Booking ───────────────────────────────────────────────
class BookingModel {
  final int id;
  final String noBooking, tanggalServis, status, tipe, merk, model, noPolisi;
  final String? jenisServis, statusServis, catatanKasir;

  const BookingModel({
    required this.id,
    required this.noBooking,
    required this.tanggalServis,
    required this.status,
    required this.tipe,
    required this.merk,
    required this.model,
    required this.noPolisi,
    this.jenisServis,
    this.statusServis,
    this.catatanKasir,
  });

  factory BookingModel.fromJson(Map<String, dynamic> j) => BookingModel(
        id: _parseInt(j['id']),
        noBooking: j['no_booking'] ?? '',
        tanggalServis: j['tanggal_servis'] ?? '',
        status: j['status'] ?? '',
        tipe: j['tipe'] ?? 'booking',
        merk: j['merk'] ?? '',
        model: j['model'] ?? '',
        noPolisi: j['no_polisi'] ?? '',
        jenisServis: j['jenis_servis'] as String?,
        statusServis: j['status_servis'] as String?,
        catatanKasir: j['catatan_kasir'] as String?,
      );
}

// ── Notifikasi ────────────────────────────────────────────
class NotifikasiModel {
  final int id;
  final String tipe, judul, pesan, createdAt;
  final bool isRead;

  const NotifikasiModel({
    required this.id,
    required this.tipe,
    required this.judul,
    required this.pesan,
    required this.createdAt,
    required this.isRead,
  });

  factory NotifikasiModel.fromJson(Map<String, dynamic> j) => NotifikasiModel(
        id: _parseInt(j['id']),
        tipe: j['tipe'] ?? '',
        judul: j['judul'] ?? '',
        pesan: j['pesan'] ?? '',
        createdAt: j['created_at'] ?? '',
        isRead:
            j['is_read'] == true || j['is_read'] == 1 || j['is_read'] == '1',
      );
}

// ── Sparepart di Servis ───────────────────────────────────
class ServisSparepartModel {
  final String nama, satuan;
  final int jumlah;
  final double hargaJual, subtotal;
  final bool disetujui;

  const ServisSparepartModel({
    required this.nama,
    required this.satuan,
    required this.jumlah,
    required this.hargaJual,
    required this.subtotal,
    required this.disetujui,
  });

  factory ServisSparepartModel.fromJson(Map<String, dynamic> j) =>
      ServisSparepartModel(
        nama: j['nama'] ?? '',
        satuan: j['satuan'] ?? 'pcs',
        jumlah: _parseInt(j['jumlah'] ?? 1),
        hargaJual: _parseDouble(j['harga_jual'] ?? 0),
        subtotal: _parseDouble(j['subtotal'] ?? 0),
        disetujui: j['disetujui'] == true ||
            j['disetujui'] == 1 ||
            j['disetujui'] == '1',
      );
}

// ── Detail Servis ─────────────────────────────────────────
class ServisDetailModel {
  final int id;
  final String status, noBooking, tanggalServis, merk, model, noPolisi;
  final double hargaJasa, estimasiTotal;
  final String? diagnosa, mekanik, jenisServis, waktuMulai, waktuSelesai;
  final List<ServisSparepartModel> spareparts;

  const ServisDetailModel({
    required this.id,
    required this.status,
    required this.noBooking,
    required this.tanggalServis,
    required this.merk,
    required this.model,
    required this.noPolisi,
    required this.hargaJasa,
    required this.estimasiTotal,
    required this.spareparts,
    this.diagnosa,
    this.mekanik,
    this.jenisServis,
    this.waktuMulai,
    this.waktuSelesai,
  });

  factory ServisDetailModel.fromJson(Map<String, dynamic> j) {
    final s = j['servis'] as Map<String, dynamic>;
    final spList = (j['sparepart'] as List? ?? [])
        .map((e) => ServisSparepartModel.fromJson(e))
        .toList();
    return ServisDetailModel(
      id: _parseInt(s['id']),
      status: s['status'] ?? '',
      noBooking: s['no_booking'] ?? '',
      tanggalServis: s['tanggal_servis'] ?? '',
      merk: s['merk'] ?? '',
      model: s['model'] ?? '',
      noPolisi: s['no_polisi'] ?? '',
      diagnosa: s['diagnosa'] as String?,
      mekanik: s['mekanik'] as String?,
      jenisServis: s['jenis_servis'] as String?,
      hargaJasa: _parseDouble(s['harga_jasa'] ?? 0),
      waktuMulai: s['waktu_mulai'] as String?,
      waktuSelesai: s['waktu_selesai'] as String?,
      estimasiTotal: _parseDouble(j['estimasi_total'] ?? 0),
      spareparts: spList,
    );
  }
}

// ── Request Sparepart saat Booking (baru) ─────────────────
// Mewakili satu item sparepart yang dipilih pelanggan di form booking.
// Ini adalah state lokal di UI sebelum dikirim ke server.
class BookingSparepartItem {
  final SparepartModel sparepart;
  int jumlah;
  final String? catatan;

  BookingSparepartItem({
    required this.sparepart,
    this.jumlah = 1,
    this.catatan,
  });

  double get subtotal => sparepart.hargaJual * jumlah;

  Map<String, dynamic> toJson() => {
        'sparepart_id': sparepart.id,
        'jumlah': jumlah,
        'harga_jual': sparepart.hargaJual,
        'subtotal': subtotal,
        if (catatan != null && catatan!.isNotEmpty) 'catatan': catatan,
      };
}

// ── Model response request sparepart dari server ──────────
// Dipakai untuk menampilkan status review kasir di detail booking.
class BookingSparepartRequestModel {
  final int id;
  final int sparepartId, jumlah;
  final String namaPart, satuan, status;
  final double hargaJual, subtotal;
  final String? catatan, catatanKasir;

  const BookingSparepartRequestModel({
    required this.id,
    required this.sparepartId,
    required this.namaPart,
    required this.satuan,
    required this.jumlah,
    required this.hargaJual,
    required this.subtotal,
    required this.status,
    this.catatan,
    this.catatanKasir,
  });

  factory BookingSparepartRequestModel.fromJson(Map<String, dynamic> j) =>
      BookingSparepartRequestModel(
        id: _parseInt(j['id']),
        sparepartId: _parseInt(j['sparepart_id']),
        namaPart: j['nama'] ?? j['nama_part'] ?? '',
        satuan: j['satuan'] ?? 'pcs',
        jumlah: _parseInt(j['jumlah'] ?? 1),
        hargaJual: _parseDouble(j['harga_jual'] ?? 0),
        subtotal: _parseDouble(j['subtotal'] ?? 0),
        status: j['status'] ?? 'menunggu',
        catatan: j['catatan'] as String?,
        catatanKasir: j['catatan_kasir'] as String?,
      );

  /// Label badge status untuk UI
  String get statusLabel {
    switch (status) {
      case 'disetujui':
        return 'Disetujui';
      case 'diganti':
        return 'Diganti';
      case 'ditolak':
        return 'Ditolak';
      default:
        return 'Menunggu';
    }
  }
}
