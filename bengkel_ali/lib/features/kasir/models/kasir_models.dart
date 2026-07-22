int _parseInt(dynamic v) => v == null ? 0 : int.tryParse(v.toString()) ?? 0;
double _parseDouble(dynamic v) =>
    v == null ? 0.0 : double.tryParse(v.toString()) ?? 0.0;

class KasirBookingModel {
  final int id;
  final String noBooking;
  final String tanggalServis;
  final String status;
  final String tipe;
  final String namaPelanggan;
  final String noHp;
  final String merk;
  final String model;
  final String noPolisi;
  final String? jenisServis;
  final String? slotLabel;
  final String? jamMulai;
  final int? servisId;
  final String? statusServis;
  final String? keluhan;
  final int partRequestMenunggu;

  const KasirBookingModel({
    required this.id,
    required this.noBooking,
    required this.tanggalServis,
    required this.status,
    required this.tipe,
    required this.namaPelanggan,
    required this.noHp,
    required this.merk,
    required this.model,
    required this.noPolisi,
    this.jenisServis,
    this.slotLabel,
    this.jamMulai,
    this.servisId,
    this.statusServis,
    this.keluhan,
    this.partRequestMenunggu = 0,
  });

  factory KasirBookingModel.fromJson(Map<String, dynamic> j) =>
      KasirBookingModel(
        id: _parseInt(j['id']),
        noBooking: j['no_booking'] as String,
        tanggalServis: j['tanggal_servis'] as String,
        status: j['status'] as String,
        tipe: j['tipe'] as String,
        namaPelanggan: j['nama_pelanggan'] as String,
        noHp: j['no_hp'] as String,
        merk: j['merk'] as String,
        model: j['model'] as String,
        noPolisi: j['no_polisi'] as String,
        jenisServis: j['jenis_servis'] as String?,
        slotLabel: j['slot_label'] as String?,
        jamMulai: j['jam_mulai'] as String?,
        servisId: j['servis_id'] != null ? _parseInt(j['servis_id']) : null,
        statusServis: j['status_servis'] as String?,
        keluhan: j['keluhan'] as String?,
        partRequestMenunggu: _parseInt(j['part_request_menunggu'] ?? 0),
      );

  bool get bisaDikonfirmasi => status == 'menunggu';
  bool get bisaDiaktifkan => status == 'dikonfirmasi';
  bool get bisaNoShow => ['menunggu', 'dikonfirmasi'].contains(status);
  bool get adaServis => servisId != null;
  bool get adaPartRequest => partRequestMenunggu > 0;
}

class KasirServisModel {
  final int id;
  final String status;
  final String? waktuMulai;
  final String noBooking;
  final String tanggalServis;
  final String namaPelanggan;
  final String merk;
  final String model;
  final String noPolisi;
  final String? jenisServis;
  final String? namaMekanik;

  const KasirServisModel({
    required this.id,
    required this.status,
    this.waktuMulai,
    required this.noBooking,
    required this.tanggalServis,
    required this.namaPelanggan,
    required this.merk,
    required this.model,
    required this.noPolisi,
    this.jenisServis,
    this.namaMekanik,
  });

  factory KasirServisModel.fromJson(Map<String, dynamic> j) => KasirServisModel(
        id: _parseInt(j['id']),
        status: j['status'] as String,
        waktuMulai: j['waktu_mulai'] as String?,
        noBooking: j['no_booking'] as String,
        tanggalServis: j['tanggal_servis'] as String,
        namaPelanggan: j['nama_pelanggan'] as String,
        merk: j['merk'] as String,
        model: j['model'] as String,
        noPolisi: j['no_polisi'] as String,
        jenisServis: j['jenis_servis'] as String?,
        namaMekanik: j['nama_mekanik'] as String?,
      );
}

class ServisSparepart {
  final int id;
  final int sparepartId;
  final String nama, satuan;
  final int jumlah;
  final double hargaJual, subtotal;
  final String sumber; // 'request' | 'rekomendasi' | 'manual'
  final String statusPersetujuan; // 'menunggu' | 'disetujui' | 'ditolak'
  final int stok;

  const ServisSparepart({
    required this.id,
    required this.sparepartId,
    required this.nama,
    required this.satuan,
    required this.jumlah,
    required this.hargaJual,
    required this.subtotal,
    required this.sumber,
    required this.statusPersetujuan,
    required this.stok,
  });

  factory ServisSparepart.fromJson(Map<String, dynamic> j) => ServisSparepart(
        id: _parseInt(j['id']),
        sparepartId: _parseInt(j['sparepart_id']),
        nama: j['nama'] as String? ?? '',
        satuan: j['satuan'] as String? ?? '',
        jumlah: _parseInt(j['jumlah']),
        hargaJual: _parseDouble(j['harga_jual']),
        subtotal: _parseDouble(j['subtotal']),
        sumber: j['sumber'] as String? ?? 'manual',
        statusPersetujuan: j['status_persetujuan'] as String? ?? 'disetujui',
        stok: _parseInt(j['stok']),
      );

  bool get isRequest => sumber == 'request';
  bool get isRekomendasi => sumber == 'rekomendasi';
  bool get isManual => sumber == 'manual';
  // Ditambah kasir di luar request pelanggan (rekomendasi atau input manual)
  bool get isDariKasir => sumber == 'rekomendasi' || sumber == 'manual';
  bool get isMenunggu => statusPersetujuan == 'menunggu';
  bool get isDisetujui => statusPersetujuan == 'disetujui';
  bool get isDitolak => statusPersetujuan == 'ditolak';
}

/// Sparepart yang diminta pelanggan saat booking, tapi BELUM diimpor ke
/// servis. Dipakai popup "Tentukan Sparepart" supaya kasir bisa pilih
/// per-item mana yang mau dimasukkan ke servis (bukan cuma toggle
/// impor-semua-atau-tidak).
class SparepartRequestPending {
  final int sparepartId;
  final String nama, satuan;
  final int jumlah, stok;
  final double hargaJual, subtotal;

  const SparepartRequestPending({
    required this.sparepartId,
    required this.nama,
    required this.satuan,
    required this.jumlah,
    required this.stok,
    required this.hargaJual,
    required this.subtotal,
  });

  factory SparepartRequestPending.fromJson(Map<String, dynamic> j) =>
      SparepartRequestPending(
        sparepartId: _parseInt(j['sparepart_id']),
        nama: j['nama'] as String? ?? '',
        satuan: j['satuan'] as String? ?? '',
        jumlah: _parseInt(j['jumlah']),
        stok: _parseInt(j['stok']),
        hargaJual: _parseDouble(j['harga_jual']),
        subtotal: _parseDouble(j['subtotal']),
      );
}

class MekanikModel {
  final int id;
  final String nama;
  const MekanikModel({required this.id, required this.nama});
  factory MekanikModel.fromJson(Map<String, dynamic> j) =>
      MekanikModel(id: _parseInt(j['id']), nama: j['nama'] as String);
}

class SparepartCariModel {
  final int id;
  final String kode;
  final String nama;
  final String satuan;
  final double hargaJual;
  final int stok;

  const SparepartCariModel({
    required this.id,
    required this.kode,
    required this.nama,
    required this.satuan,
    required this.hargaJual,
    required this.stok,
  });

  factory SparepartCariModel.fromJson(Map<String, dynamic> j) =>
      SparepartCariModel(
        id: _parseInt(j['id']),
        kode: j['kode'] as String,
        nama: j['nama'] as String,
        satuan: j['satuan'] as String,
        hargaJual: _parseDouble(j['harga_jual']),
        stok: _parseInt(j['stok']),
      );
}

class DetailServisModel {
  final Map<String, dynamic> servis;
  final List<ServisSparepart> sparepart;
  final List<MekanikModel> mekanikList;
  final List<Map<String, dynamic>> jenisServisList;
  final double totalJasa, totalPart, grandTotal;
  final bool adaMenungguPersetujuan;
  final List<SparepartRequestPending> sparepartRequestPending;

  const DetailServisModel({
    required this.servis,
    required this.sparepart,
    required this.mekanikList,
    required this.jenisServisList,
    required this.totalJasa,
    required this.totalPart,
    required this.grandTotal,
    required this.adaMenungguPersetujuan,
    required this.sparepartRequestPending,
  });

  factory DetailServisModel.fromJson(Map<String, dynamic> j) =>
      DetailServisModel(
        servis: j['servis'] as Map<String, dynamic>,
        sparepart: (j['sparepart'] as List)
            .map((e) => ServisSparepart.fromJson(e))
            .toList(),
        mekanikList: (j['mekanik_list'] as List)
            .map((e) => MekanikModel.fromJson(e))
            .toList(),
        jenisServisList: (j['jenis_servis_list'] as List? ?? [])
            .map((e) => {
                  ...e as Map<String, dynamic>,
                  'id': _parseInt(e['id']),
                })
            .toList(),
        totalJasa: _parseDouble(j['total_jasa']),
        totalPart: _parseDouble(j['total_part']),
        grandTotal: _parseDouble(j['grand_total']),
        adaMenungguPersetujuan: j['ada_menunggu_persetujuan'] as bool? ?? false,
        sparepartRequestPending: (j['sparepart_request_pending'] as List? ?? [])
            .map((e) =>
                SparepartRequestPending.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

// ── Model item di keranjang belanja ──────────────────────────
class KeranjangItem {
  final int sparepartId;
  final String kode;
  final String nama;
  final String satuan;
  final double hargaJual;
  final int stokTersedia;
  int jumlah;

  KeranjangItem({
    required this.sparepartId,
    required this.kode,
    required this.nama,
    required this.satuan,
    required this.hargaJual,
    required this.stokTersedia,
    this.jumlah = 1,
  });

  double get subtotal => hargaJual * jumlah;

  // Buat dari SparepartCariModel (reuse model yang sudah ada)
  factory KeranjangItem.fromSparepart(SparepartCariModel s) => KeranjangItem(
        sparepartId: s.id,
        kode: s.kode,
        nama: s.nama,
        satuan: s.satuan,
        hargaJual: s.hargaJual,
        stokTersedia: s.stok,
      );
}

// ── Request sparepart dari pelanggan saat booking ─────────────
class KasirBookingSparepartRequest {
  final int id;
  final int sparepartId;
  final String nama;
  final String satuan;
  final int jumlah;
  final double hargaJual;
  final double subtotal;
  final String status; // menunggu | disetujui | diganti | ditolak
  final String? catatan;
  final String? catatanKasir;

  const KasirBookingSparepartRequest({
    required this.id,
    required this.sparepartId,
    required this.nama,
    required this.satuan,
    required this.jumlah,
    required this.hargaJual,
    required this.subtotal,
    required this.status,
    this.catatan,
    this.catatanKasir,
  });

  factory KasirBookingSparepartRequest.fromJson(Map<String, dynamic> j) =>
      KasirBookingSparepartRequest(
        id: _parseInt(j['id']),
        sparepartId: _parseInt(j['sparepart_id']),
        nama: j['nama'] as String,
        satuan: j['satuan'] as String,
        jumlah: _parseInt(j['jumlah']),
        hargaJual: _parseDouble(j['harga_jual']),
        subtotal: _parseDouble(j['subtotal']),
        status: j['status'] as String? ?? 'menunggu',
        catatan: j['catatan'] as String?,
        catatanKasir: j['catatan_kasir'] as String?,
      );

  bool get isMenunggu => status == 'menunggu';
}

// ── Hasil transaksi dari API ──────────────────────────────────
class HasilTransaksiSparepart {
  final int transaksiId;
  final String noNota;
  final double grandTotal;
  final double jumlahBayar;
  final double kembalian;
  final String metodeBayar;
  final String tanggal;

  const HasilTransaksiSparepart({
    required this.transaksiId,
    required this.noNota,
    required this.grandTotal,
    required this.jumlahBayar,
    required this.kembalian,
    required this.metodeBayar,
    required this.tanggal,
  });

  factory HasilTransaksiSparepart.fromJson(Map<String, dynamic> j) =>
      HasilTransaksiSparepart(
        transaksiId: int.tryParse(j['transaksi_id'].toString()) ?? 0,
        noNota: j['no_nota'] as String? ?? '-',
        grandTotal: _parseDouble(j['grand_total']),
        jumlahBayar: _parseDouble(j['jumlah_bayar']),
        kembalian: _parseDouble(j['kembalian']),
        metodeBayar: j['metode_bayar'] as String? ?? 'cash',
        tanggal: j['tanggal'] as String? ?? '',
      );
}

// ── Model untuk item di keranjang beli stok ──────────────────
class BeliStokItem {
  final int sparepartId;
  final String kode;
  final String nama;
  final String satuan;
  final double hargaBeli; // bisa diedit user
  int jumlah;

  BeliStokItem({
    required this.sparepartId,
    required this.kode,
    required this.nama,
    required this.satuan,
    required this.hargaBeli,
    this.jumlah = 1,
  });

  double get subtotal => hargaBeli * jumlah;
}

// ── Model detail item dalam riwayat pembelian ────────────────
class DetailPembelianStok {
  final int id;
  final int sparepartId;
  final String nama;
  final String satuan;
  final int jumlah;
  final double hargaBeli;
  final double subtotal;

  const DetailPembelianStok({
    required this.id,
    required this.sparepartId,
    required this.nama,
    required this.satuan,
    required this.jumlah,
    required this.hargaBeli,
    required this.subtotal,
  });

  factory DetailPembelianStok.fromJson(Map<String, dynamic> j) =>
      DetailPembelianStok(
        id: _parseInt(j['id']),
        sparepartId: _parseInt(j['sparepart_id']),
        nama: j['nama'] as String? ?? '',
        satuan: j['satuan'] as String? ?? 'pcs',
        jumlah: _parseInt(j['jumlah']),
        hargaBeli: _parseDouble(j['harga_beli']),
        subtotal: _parseDouble(j['subtotal']),
      );
}

// ── Model header riwayat pembelian stok ─────────────────────
class PembelianStok {
  final int id;
  final String noPembelian;
  final String tanggal;
  final String? supplier;
  final double total;
  final String? keterangan;
  final String namaKasir;
  final List<DetailPembelianStok> details;

  const PembelianStok({
    required this.id,
    required this.noPembelian,
    required this.tanggal,
    this.supplier,
    required this.total,
    this.keterangan,
    required this.namaKasir,
    this.details = const [],
  });

  factory PembelianStok.fromJson(Map<String, dynamic> j) => PembelianStok(
        id: _parseInt(j['id']),
        noPembelian: j['no_pembelian'] as String? ?? '-',
        tanggal: j['tanggal'] as String? ?? '',
        supplier: j['supplier'] as String?,
        total: _parseDouble(j['total']),
        keterangan: j['keterangan'] as String?,
        namaKasir: j['nama_kasir'] as String? ?? '-',
        details: j['details'] != null
            ? (j['details'] as List)
                .map((e) => DetailPembelianStok.fromJson(e))
                .toList()
            : [],
      );
}
