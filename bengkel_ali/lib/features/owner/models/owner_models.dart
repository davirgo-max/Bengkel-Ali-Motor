// lib/features/owner/models/owner_models.dart

int _parseInt(dynamic v) => v == null ? 0 : int.tryParse(v.toString()) ?? 0;
double _parseDouble(dynamic v) =>
    v == null ? 0.0 : double.tryParse(v.toString()) ?? 0.0;
bool _parseBool(dynamic v) => v == true || v == 1 || v == '1';

// ── Akun Kasir ────────────────────────────────────────────
class AkunKasirModel {
  final int id;
  final String nama;
  final String username;
  final bool isAktif;
  final String createdAt;

  const AkunKasirModel({
    required this.id,
    required this.nama,
    required this.username,
    required this.isAktif,
    required this.createdAt,
  });

  factory AkunKasirModel.fromJson(Map<String, dynamic> j) => AkunKasirModel(
        id: _parseInt(j['id']),
        nama: j['nama'] as String,
        username: j['username'] as String,
        isAktif: _parseBool(j['is_aktif']),
        createdAt: j['created_at'] as String? ?? '',
      );
}

// ── Dashboard Owner ───────────────────────────────────────
class DashboardOwnerData {
  final String tanggal;
  final Map<String, dynamic> booking;
  final Map<String, dynamic> servis;
  final Map<String, dynamic> pemasukan;
  final int menungguBayar;
  final int stokMenipis;

  const DashboardOwnerData({
    required this.tanggal,
    required this.booking,
    required this.servis,
    required this.pemasukan,
    required this.menungguBayar,
    required this.stokMenipis,
  });

  factory DashboardOwnerData.fromJson(Map<String, dynamic> j) =>
      DashboardOwnerData(
        tanggal: j['tanggal'] as String,
        booking: j['booking'] as Map<String, dynamic>? ?? {},
        servis: j['servis'] as Map<String, dynamic>? ?? {},
        pemasukan: j['pemasukan'] as Map<String, dynamic>? ?? {},
        menungguBayar:
            j['menunggu_bayar'] != null ? _parseInt(j['menunggu_bayar']) : 0,
        stokMenipis:
            j['stok_menipis'] != null ? _parseInt(j['stok_menipis']) : 0,
      );

  double get totalPemasukan => _parseDouble(pemasukan['total'] ?? 0);
  double get pemasukanCash => _parseDouble(pemasukan['cash'] ?? 0);
  double get pemasukanTransfer => _parseDouble(pemasukan['transfer'] ?? 0);
  int get jumlahTransaksi => pemasukan['jumlah_transaksi'] != null
      ? _parseInt(pemasukan['jumlah_transaksi'])
      : 0;
  int get totalBooking =>
      booking['total'] != null ? _parseInt(booking['total']) : 0;
  int get servisSelesai => servis['selesai_servis'] != null
      ? _parseInt(servis['selesai_servis'])
      : 0;
  int get noShow =>
      booking['no_show'] != null ? _parseInt(booking['no_show']) : 0;
}

// ── Laporan Servis ────────────────────────────────────────
class LaporanServisItem {
  final int id;
  final String noBooking;
  final String tanggalServis;
  final String namaPelanggan;
  final String merk;
  final String model;
  final String noPolisi;
  final String? jenisServis;
  final String? namaMekanik;
  final String status;
  final double totalBiaya;

  const LaporanServisItem({
    required this.id,
    required this.noBooking,
    required this.tanggalServis,
    required this.namaPelanggan,
    required this.merk,
    required this.model,
    required this.noPolisi,
    this.jenisServis,
    this.namaMekanik,
    required this.status,
    required this.totalBiaya,
  });

  factory LaporanServisItem.fromJson(Map<String, dynamic> j) =>
      LaporanServisItem(
        id: _parseInt(j['id']),
        noBooking: j['no_booking'] as String,
        tanggalServis: j['tanggal_servis'] as String,
        namaPelanggan: j['nama_pelanggan'] as String,
        merk: j['merk'] as String,
        model: j['model'] as String,
        noPolisi: j['no_polisi'] as String,
        jenisServis: j['jenis_servis'] as String?,
        namaMekanik: j['nama_mekanik'] as String?,
        status: j['status'] as String,
        totalBiaya: _parseDouble(j['total_biaya'] ?? 0),
      );
}

// ── Laporan Sparepart ─────────────────────────────────────
class LaporanSparepartItem {
  final int id;
  final String kode;
  final String nama;
  final String satuan;
  final int terjual;
  final double pendapatan;
  final double hpp;
  final int stokSaat;

  const LaporanSparepartItem({
    required this.id,
    required this.kode,
    required this.nama,
    required this.satuan,
    required this.terjual,
    required this.pendapatan,
    required this.hpp,
    required this.stokSaat,
  });

  factory LaporanSparepartItem.fromJson(Map<String, dynamic> j) =>
      LaporanSparepartItem(
        id: _parseInt(j['id']),
        kode: j['kode'] as String,
        nama: j['nama'] as String,
        satuan: j['satuan'] as String,
        terjual: _parseInt(j['terjual'] ?? 0),
        pendapatan: _parseDouble(j['pendapatan'] ?? 0),
        hpp: _parseDouble(j['hpp'] ?? 0),
        stokSaat: _parseInt(j['stok_saat'] ?? 0),
      );

  double get laba => pendapatan - hpp;
}

// ── Stok Menipis ──────────────────────────────────────────
class StokMenipisModel {
  final int id;
  final String kode;
  final String nama;
  final String satuan;
  final int stok;
  final int stokMinimum;

  const StokMenipisModel({
    required this.id,
    required this.kode,
    required this.nama,
    required this.satuan,
    required this.stok,
    required this.stokMinimum,
  });

  factory StokMenipisModel.fromJson(Map<String, dynamic> j) => StokMenipisModel(
        id: _parseInt(j['id']),
        kode: j['kode'] as String,
        nama: j['nama'] as String,
        satuan: j['satuan'] as String,
        stok: _parseInt(j['stok']),
        stokMinimum: _parseInt(j['stok_minimum']),
      );

  bool get kritis => stok == 0;
}

// ── Pengaturan Bengkel ────────────────────────────────────
class PengaturanBengkelModel {
  final int id;
  final int kuotaBookingHarian;
  final String jamBuka;
  final String jamTutup;
  final String namaBengkel;
  final String? alamatBengkel;
  final String? noHpBengkel;

  const PengaturanBengkelModel({
    required this.id,
    required this.kuotaBookingHarian,
    required this.jamBuka,
    required this.jamTutup,
    required this.namaBengkel,
    this.alamatBengkel,
    this.noHpBengkel,
  });

  factory PengaturanBengkelModel.fromJson(Map<String, dynamic> j) =>
      PengaturanBengkelModel(
        id: _parseInt(j['id']),
        kuotaBookingHarian: _parseInt(j['kuota_booking_harian']),
        jamBuka: j['jam_buka'] as String,
        jamTutup: j['jam_tutup'] as String,
        namaBengkel: j['nama_bengkel'] as String,
        alamatBengkel: j['alamat_bengkel'] as String?,
        noHpBengkel: j['no_hp_bengkel'] as String?,
      );
}

// ── Pelanggan Diblokir (versi owner) ─────────────────────
class PelangganBlokirModel {
  final int id;
  final String nama;
  final String noHp;
  final bool isBlokir;
  final String? blokirSampai;
  final String? blokirAlasan;
  final int totalNoshow;
  final bool permanen;

  const PelangganBlokirModel({
    required this.id,
    required this.nama,
    required this.noHp,
    required this.isBlokir,
    this.blokirSampai,
    this.blokirAlasan,
    required this.totalNoshow,
    required this.permanen,
  });

  factory PelangganBlokirModel.fromJson(Map<String, dynamic> j) =>
      PelangganBlokirModel(
        id: _parseInt(j['id']),
        nama: j['nama'] as String,
        noHp: j['no_hp'] as String,
        isBlokir: _parseBool(j['is_diblokir']),
        blokirSampai: j['blokir_sampai'] as String?,
        blokirAlasan: j['blokir_alasan'] as String?,
        totalNoshow: _parseInt(j['total_noshow'] ?? 0),
        permanen: j['permanen'] == true || j['blokir_sampai'] == null,
      );
}

// ── Mekanik ───────────────────────────────────────────────
class MekanikModel {
  final int id;
  final String nama;
  final String? noHp;
  final String? spesialisasi;
  final bool isAktif;
  final String createdAt;
  final int jumlahServis;

  const MekanikModel({
    required this.id,
    required this.nama,
    this.noHp,
    this.spesialisasi,
    required this.isAktif,
    required this.createdAt,
    required this.jumlahServis,
  });

  factory MekanikModel.fromJson(Map<String, dynamic> j) => MekanikModel(
        id: _parseInt(j['id']),
        nama: j['nama'] as String,
        noHp: j['no_hp'] as String?,
        spesialisasi: j['spesialisasi'] as String?,
        isAktif: _parseBool(j['is_aktif']),
        createdAt: j['created_at'] as String? ?? '',
        jumlahServis: _parseInt(j['jumlah_servis'] ?? 0),
      );
}
