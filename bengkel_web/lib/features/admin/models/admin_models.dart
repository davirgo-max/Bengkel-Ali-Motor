// lib/features/admin/models/admin_models.dart

int _int(dynamic v) => v == null ? 0 : (v is int ? v : int.tryParse('$v') ?? 0);
double _dbl(dynamic v) =>
    v == null ? 0.0 : (v is double ? v : double.tryParse('$v') ?? 0.0);
bool _bool(dynamic v) => v == true || v == 1 || v == '1';
String _str(dynamic v) => v == null ? '' : '$v';

// ── Kategori Sparepart ───────────────────────────────────
class KategoriModel {
  final int id;
  final String nama;
  const KategoriModel({required this.id, required this.nama});
  factory KategoriModel.fromJson(Map<String, dynamic> j) =>
      KategoriModel(id: _int(j['id']), nama: _str(j['nama']));
}

// ── Sparepart ─────────────────────────────────────────────
class SparepartModel {
  final int id;
  final String kode;
  final String nama;
  final String satuan;
  final double hargaBeli;
  final double hargaJual;
  final int stok;
  final int stokMinimum;
  final String? foto;
  final bool isAktif;
  final String? kategoriNama;
  final int? kategoriId;
  final bool stokMenipis;

  const SparepartModel({
    required this.id,
    required this.kode,
    required this.nama,
    required this.satuan,
    required this.hargaBeli,
    required this.hargaJual,
    required this.stok,
    required this.stokMinimum,
    this.foto,
    required this.isAktif,
    this.kategoriNama,
    this.kategoriId,
    required this.stokMenipis,
  });

  factory SparepartModel.fromJson(Map<String, dynamic> j) => SparepartModel(
        id: _int(j['id']),
        kode: _str(j['kode']),
        nama: _str(j['nama']),
        satuan: _str(j['satuan']),
        hargaBeli: _dbl(j['harga_beli']),
        hargaJual: _dbl(j['harga_jual']),
        stok: _int(j['stok']),
        stokMinimum: _int(j['stok_minimum']),
        foto: j['foto'] as String?,
        isAktif: _bool(j['is_aktif']),
        kategoriNama: j['kategori_nama'] as String?,
        kategoriId: j['kategori_id'] != null ? _int(j['kategori_id']) : null,
        stokMenipis: _bool(j['stok_menipis']),
      );

  bool get habis => stok == 0;
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
        id: _int(j['id']),
        nama: _str(j['nama']),
        noHp: j['no_hp'] as String?,
        spesialisasi: j['spesialisasi'] as String?,
        isAktif: _bool(j['is_aktif']),
        createdAt: _str(j['created_at']),
        jumlahServis: _int(j['jumlah_servis']),
      );
}

// ── Akun Owner ────────────────────────────────────────────
class OwnerInfoModel {
  final int id;
  final String nama;
  final String username;
  final String createdAt;

  const OwnerInfoModel({
    required this.id,
    required this.nama,
    required this.username,
    required this.createdAt,
  });

  factory OwnerInfoModel.fromJson(Map<String, dynamic> j) => OwnerInfoModel(
        id: _int(j['id']),
        nama: _str(j['nama']),
        username: _str(j['username']),
        createdAt: _str(j['created_at']),
      );
}

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
        id: _int(j['id']),
        nama: _str(j['nama']),
        username: _str(j['username']),
        isAktif: _bool(j['is_aktif']),
        createdAt: _str(j['created_at']),
      );
}

// ── Pelanggan (admin) ─────────────────────────────────────
class PelangganAdminModel {
  final int id;
  final String nama;
  final String? noHp;
  final String? email;
  final bool isDiblokir;
  final int totalNoshow;
  final String? blokirSampai;
  final String? blokirAlasan;
  final String createdAt;

  const PelangganAdminModel({
    required this.id,
    required this.nama,
    this.noHp,
    this.email,
    required this.isDiblokir,
    required this.totalNoshow,
    this.blokirSampai,
    this.blokirAlasan,
    required this.createdAt,
  });

  factory PelangganAdminModel.fromJson(Map<String, dynamic> j) =>
      PelangganAdminModel(
        id: _int(j['id']),
        nama: _str(j['nama']),
        noHp: j['no_hp'] as String?,
        email: j['email'] as String?,
        isDiblokir: _bool(j['is_diblokir']),
        totalNoshow: _int(j['total_noshow']),
        blokirSampai: j['blokir_sampai'] as String?,
        blokirAlasan: j['blokir_alasan'] as String?,
        createdAt: _str(j['created_at']),
      );

  bool get permanen => isDiblokir && blokirSampai == null;
}

class KendaraanModel {
  final int id;
  final String merk;
  final String model;
  final int? tahun;
  final String noPolisi;
  final String? warna;

  const KendaraanModel({
    required this.id,
    required this.merk,
    required this.model,
    this.tahun,
    required this.noPolisi,
    this.warna,
  });

  factory KendaraanModel.fromJson(Map<String, dynamic> j) => KendaraanModel(
        id: _int(j['id']),
        merk: _str(j['merk']),
        model: _str(j['model']),
        tahun: j['tahun'] != null ? _int(j['tahun']) : null,
        noPolisi: _str(j['no_polisi']),
        warna: j['warna'] as String?,
      );
}

class PenaltiModel {
  final int noshowKe;
  final int? blokirHari;
  final String? blokirMulai;
  final String? blokirSampai;
  final String createdAt;
  final String? noBooking;
  final String? tanggalServis;

  const PenaltiModel({
    required this.noshowKe,
    this.blokirHari,
    this.blokirMulai,
    this.blokirSampai,
    required this.createdAt,
    this.noBooking,
    this.tanggalServis,
  });

  factory PenaltiModel.fromJson(Map<String, dynamic> j) => PenaltiModel(
        noshowKe: _int(j['noshow_ke']),
        blokirHari: j['blokir_hari'] != null ? _int(j['blokir_hari']) : null,
        blokirMulai: j['blokir_mulai'] as String?,
        blokirSampai: j['blokir_sampai'] as String?,
        createdAt: _str(j['created_at']),
        noBooking: j['no_booking'] as String?,
        tanggalServis: j['tanggal_servis'] as String?,
      );
}

class RiwayatTransaksiModel {
  final int id;
  final String noTransaksi;
  final String tanggal;
  final String jenisServis;
  final double totalBayar;
  final String status;
  final String? mekanik;
  final String? noPolisi;

  const RiwayatTransaksiModel({
    required this.id,
    required this.noTransaksi,
    required this.tanggal,
    required this.jenisServis,
    required this.totalBayar,
    required this.status,
    this.mekanik,
    this.noPolisi,
  });

  factory RiwayatTransaksiModel.fromJson(Map<String, dynamic> j) =>
      RiwayatTransaksiModel(
        id: _int(j['id']),
        noTransaksi: _str(j['no_transaksi']),
        tanggal: _str(j['tanggal']),
        jenisServis: _str(j['jenis_servis']),
        totalBayar: _dbl(j['total_bayar']),
        status: _str(j['status']),
        mekanik: j['mekanik'] as String?,
        noPolisi: j['no_polisi'] as String?,
      );
}

class SparepartRequestModel {
  final int id;
  final String namaSparepart;
  final String satuan;
  final int jumlah;
  final double hargaJual;
  final double subtotal;
  final String status; // menunggu | disetujui | ditolak

  const SparepartRequestModel({
    required this.id,
    required this.namaSparepart,
    required this.satuan,
    required this.jumlah,
    required this.hargaJual,
    required this.subtotal,
    required this.status,
  });

  factory SparepartRequestModel.fromJson(Map<String, dynamic> j) =>
      SparepartRequestModel(
        id: _int(j['id']),
        namaSparepart: _str(j['nama_sparepart']),
        satuan: _str(j['satuan']),
        jumlah: _int(j['jumlah']),
        hargaJual: _dbl(j['harga_jual']),
        subtotal: _dbl(j['subtotal']),
        status: _str(j['status']),
      );
}

class BookingAktifModel {
  final int id;
  final String noBooking;
  final String tanggalServis;
  final String
      status; // menunggu | dikonfirmasi | aktif | dalam_servis | no_show | batal
  final String tipe; // online | walk_in
  final String? keluhan;
  final String? createdAt;
  // Kendaraan
  final String merk;
  final String model;
  final String noPolisi;
  final String? warna;
  final int? tahun;
  // Jenis servis
  final String? jenisServis;
  final double? hargaJasa;
  // Slot
  final String? slotLabel;
  final String? jamMulai;
  final String? jamSelesai;
  // Servis
  final int? servisId;
  final String? statusServis;
  final String? diagnosa;
  final String? waktuMulai;
  final String? waktuSelesai;
  final String? namaMekanik;
  // Sparepart request
  final List<SparepartRequestModel> sparepartRequest;

  const BookingAktifModel({
    required this.id,
    required this.noBooking,
    required this.tanggalServis,
    required this.status,
    required this.tipe,
    this.keluhan,
    this.createdAt,
    required this.merk,
    required this.model,
    required this.noPolisi,
    this.warna,
    this.tahun,
    this.jenisServis,
    this.hargaJasa,
    this.slotLabel,
    this.jamMulai,
    this.jamSelesai,
    this.servisId,
    this.statusServis,
    this.diagnosa,
    this.waktuMulai,
    this.waktuSelesai,
    this.namaMekanik,
    this.sparepartRequest = const [],
  });

  factory BookingAktifModel.fromJson(Map<String, dynamic> j) {
    final spList = (j['sparepart_request'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(SparepartRequestModel.fromJson)
        .toList();
    return BookingAktifModel(
      id: _int(j['id']),
      noBooking: _str(j['no_booking']),
      tanggalServis: _str(j['tanggal_servis']),
      status: _str(j['status']),
      tipe: _str(j['tipe']),
      keluhan: j['keluhan'] as String?,
      createdAt: j['created_at'] as String?,
      merk: _str(j['merk']),
      model: _str(j['model']),
      noPolisi: _str(j['no_polisi']),
      warna: j['warna'] as String?,
      tahun: j['tahun'] != null ? _int(j['tahun']) : null,
      jenisServis: j['jenis_servis'] as String?,
      hargaJasa: j['harga_jasa'] != null ? _dbl(j['harga_jasa']) : null,
      slotLabel: j['slot_label'] as String?,
      jamMulai: j['jam_mulai'] as String?,
      jamSelesai: j['jam_selesai'] as String?,
      servisId: j['servis_id'] != null ? _int(j['servis_id']) : null,
      statusServis: j['status_servis'] as String?,
      diagnosa: j['diagnosa'] as String?,
      waktuMulai: j['waktu_mulai'] as String?,
      waktuSelesai: j['waktu_selesai'] as String?,
      namaMekanik: j['nama_mekanik'] as String?,
      sparepartRequest: spList,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'menunggu':
        return 'Menunggu';
      case 'dikonfirmasi':
        return 'Dikonfirmasi';
      case 'aktif':
        return 'Aktif';
      case 'dalam_servis':
        return 'Dalam Servis';
      case 'no_show':
        return 'No-show';
      case 'batal':
      case 'dibatalkan':
        return 'Dibatalkan';
      default:
        return status;
    }
  }
}

class PelangganDetailModel {
  final PelangganAdminModel pelanggan;
  final String? alamat;
  final bool isAktif;
  final List<KendaraanModel> kendaraan;
  final List<PenaltiModel> riwayatPenalti;
  final List<RiwayatTransaksiModel> riwayatTransaksi;
  final List<BookingAktifModel> bookingAktif;

  const PelangganDetailModel({
    required this.pelanggan,
    this.alamat,
    required this.isAktif,
    required this.kendaraan,
    required this.riwayatPenalti,
    this.riwayatTransaksi = const [],
    this.bookingAktif = const [],
  });

  factory PelangganDetailModel.fromJson(Map<String, dynamic> j) {
    final p = j['pelanggan'] as Map<String, dynamic>? ?? {};
    final kendaraanList = (j['kendaraan'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(KendaraanModel.fromJson)
        .toList();
    final penaltiList = (j['riwayat_penalti'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(PenaltiModel.fromJson)
        .toList();
    final transaksiList = (j['riwayat_transaksi'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(RiwayatTransaksiModel.fromJson)
        .toList();
    final bookingAktifList = (j['booking_aktif'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(BookingAktifModel.fromJson)
        .toList();
    return PelangganDetailModel(
      pelanggan: PelangganAdminModel.fromJson(p),
      alamat: p['alamat'] as String?,
      isAktif: _bool(p['is_aktif']),
      kendaraan: kendaraanList,
      riwayatPenalti: penaltiList,
      riwayatTransaksi: transaksiList,
      bookingAktif: bookingAktifList,
    );
  }
}

// ── Dashboard Admin — Stat Card ───────────────────────────
class AdminDashboardStat {
  final int stokKritis;
  final int mekanikAktif;
  final int pelangganDiblokir;
  final int hariLiburBulanIni;

  const AdminDashboardStat({
    required this.stokKritis,
    required this.mekanikAktif,
    required this.pelangganDiblokir,
    required this.hariLiburBulanIni,
  });

  factory AdminDashboardStat.fromJson(Map<String, dynamic> j) =>
      AdminDashboardStat(
        stokKritis: _int(j['stok_kritis']),
        mekanikAktif: _int(j['mekanik_aktif']),
        pelangganDiblokir: _int(j['pelanggan_diblokir']),
        hariLiburBulanIni: _int(j['hari_libur_bulan_ini']),
      );
}

// ── Dashboard Admin — Stok Kritis ─────────────────────────
class StokKritisItem {
  final int id;
  final String kode;
  final String nama;
  final String satuan;
  final int stok;
  final int stokMinimum;
  final String? kategori;
  final bool habis;

  const StokKritisItem({
    required this.id,
    required this.kode,
    required this.nama,
    required this.satuan,
    required this.stok,
    required this.stokMinimum,
    this.kategori,
    required this.habis,
  });

  factory StokKritisItem.fromJson(Map<String, dynamic> j) => StokKritisItem(
        id: _int(j['id']),
        kode: _str(j['kode']),
        nama: _str(j['nama']),
        satuan: _str(j['satuan']),
        stok: _int(j['stok']),
        stokMinimum: _int(j['stok_minimum']),
        kategori: j['kategori'] as String?,
        habis: _bool(j['habis']),
      );
}

// ── Dashboard Admin — Status Staff ────────────────────────
class StatusStaffItem {
  final String role;
  final int aktif;
  final int nonaktif;
  final int total;

  const StatusStaffItem({
    required this.role,
    required this.aktif,
    required this.nonaktif,
    required this.total,
  });

  factory StatusStaffItem.fromJson(Map<String, dynamic> j) => StatusStaffItem(
        role: _str(j['role']),
        aktif: _int(j['aktif']),
        nonaktif: _int(j['nonaktif']),
        total: _int(j['total']),
      );
}

// ── Dashboard Admin — full response ──────────────────────
class AdminDashboardData {
  final AdminDashboardStat statCard;
  final List<StokKritisItem> stokKritis;
  final List<HariLiburModel> hariLiburMendatang;
  final List<StatusStaffItem> statusStaff;

  const AdminDashboardData({
    required this.statCard,
    required this.stokKritis,
    required this.hariLiburMendatang,
    required this.statusStaff,
  });

  factory AdminDashboardData.fromJson(Map<String, dynamic> j) {
    final stat = AdminDashboardStat.fromJson(
        (j['stat_card'] as Map<String, dynamic>?) ?? {});
    final stok = (j['stok_kritis'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(StokKritisItem.fromJson)
        .toList();
    final libur = (j['hari_libur_mendatang'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(HariLiburModel.fromJson)
        .toList();
    final staff = (j['status_staff'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(StatusStaffItem.fromJson)
        .toList();
    return AdminDashboardData(
      statCard: stat,
      stokKritis: stok,
      hariLiburMendatang: libur,
      statusStaff: staff,
    );
  }
}

// ── Pengaturan Bengkel ────────────────────────────────────
class PengaturanBengkelModel {
  final String namaBengkel;
  final String? alamatBengkel;
  final String? noHpBengkel;
  final String jamBuka;
  final String jamTutup;
  final int kuotaBookingHarian;
  final String? updatedAt;

  const PengaturanBengkelModel({
    required this.namaBengkel,
    this.alamatBengkel,
    this.noHpBengkel,
    required this.jamBuka,
    required this.jamTutup,
    required this.kuotaBookingHarian,
    this.updatedAt,
  });

  factory PengaturanBengkelModel.fromJson(Map<String, dynamic> j) =>
      PengaturanBengkelModel(
        namaBengkel: _str(j['nama_bengkel']),
        alamatBengkel: j['alamat_bengkel'] as String?,
        noHpBengkel: j['no_hp_bengkel'] as String?,
        jamBuka: _str(j['jam_buka']),
        jamTutup: _str(j['jam_tutup']),
        kuotaBookingHarian: _int(j['kuota_booking_harian']),
        updatedAt: j['updated_at'] as String?,
      );
}

// ── Jenis Servis ──────────────────────────────────────────
class JenisServisModel {
  final int id;
  final String nama;
  final String? deskripsi;
  final double hargaJasa;
  final int estimasiMenit;
  final bool isAktif;
  final String createdAt;
  final int jumlahDipakai;

  const JenisServisModel({
    required this.id,
    required this.nama,
    this.deskripsi,
    required this.hargaJasa,
    required this.estimasiMenit,
    required this.isAktif,
    required this.createdAt,
    required this.jumlahDipakai,
  });

  factory JenisServisModel.fromJson(Map<String, dynamic> j) => JenisServisModel(
        id: _int(j['id']),
        nama: _str(j['nama']),
        deskripsi: j['deskripsi'] as String?,
        hargaJasa: _dbl(j['harga_jasa']),
        estimasiMenit: _int(j['estimasi_menit']),
        isAktif: _bool(j['is_aktif']),
        createdAt: _str(j['created_at']),
        jumlahDipakai: _int(j['jumlah_dipakai']),
      );
}

// ── Hari Libur ────────────────────────────────────────────
class HariLiburModel {
  final int id;
  final String tanggal;
  final String keterangan;
  final String sumber; // 'manual' | 'api'

  const HariLiburModel({
    required this.id,
    required this.tanggal,
    required this.keterangan,
    required this.sumber,
  });

  factory HariLiburModel.fromJson(Map<String, dynamic> j) => HariLiburModel(
        id: _int(j['id']),
        tanggal: _str(j['tanggal']),
        keterangan: _str(j['keterangan']),
        sumber: _str(j['sumber']),
      );
}
