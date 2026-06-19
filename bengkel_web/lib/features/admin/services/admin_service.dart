// lib/features/admin/services/admin_service.dart

import '../../../core/network/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../models/admin_models.dart';

class AdminService {
  AdminService._();
  static final AdminService instance = AdminService._();

  final _api = ApiClient.instance;

  // ── Dashboard Admin ───────────────────────────────────────

  Future<AdminDashboardData?> getDashboard() async {
    final res = await _api.get(AppConstants.adminDashboardUrl);
    if (res['success'] != true) return null;
    final data = res['data'];
    if (data is! Map<String, dynamic>) return null;
    return AdminDashboardData.fromJson(data);
  }

  // ── Pengaturan Bengkel ─────────────────────────────────────

  Future<PengaturanBengkelModel?> getPengaturanBengkel() async {
    final res = await _api.get(AppConstants.adminPengaturanBengkelUrl);
    if (res['success'] != true) return null;
    final data = res['data'];
    if (data is! Map<String, dynamic>) return null;
    return PengaturanBengkelModel.fromJson(data);
  }

  Future<Map<String, dynamic>> updatePengaturanBengkel(
          Map<String, dynamic> data) =>
      _api.put(AppConstants.adminPengaturanBengkelUrl, data);

  // ── Sparepart ─────────────────────────────────────────────

  Future<Map<String, dynamic>> getSparepart({
    String? search,
    int? kategoriId,
    String tampilkan = 'semua',
  }) {
    final params = <String, String>{'tampilkan': tampilkan};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (kategoriId != null) params['kategori_id'] = '$kategoriId';
    return _api.get(AppConstants.adminSparepartUrl, query: params);
  }

  Future<Map<String, dynamic>> tambahSparepart(Map<String, dynamic> data) =>
      _api.post(AppConstants.adminSparepartUrl, data);

  Future<Map<String, dynamic>> editSparepart(
          int id, Map<String, dynamic> data) =>
      _api.put('${AppConstants.adminSparepartUrl}?id=$id', data);

  // FIX: tambah method toggle aktif/nonaktif sparepart
  Future<Map<String, dynamic>> toggleAktifSparepart(int id, bool aktif) =>
      _api.put('${AppConstants.adminSparepartUrl}?id=$id',
          {'action': 'toggle_aktif', 'is_aktif': aktif ? 1 : 0});

  Future<Map<String, dynamic>> hapusSparepart(int id) =>
      _api.delete('${AppConstants.adminSparepartUrl}?id=$id');

  Future<Map<String, dynamic>> uploadFotoSparepart({
    required int sparepartId,
    required List<int> fileBytes,
    required String fileName,
  }) =>
      _api.upload(
        AppConstants.adminSparepartUploadUrl,
        fields: {'sparepart_id': '$sparepartId'},
        fileField: 'foto',
        fileBytes: fileBytes,
        fileName: fileName,
      );

  // ── Mekanik ───────────────────────────────────────────────

  Future<List<MekanikModel>> getMekanik({String tampilkan = 'aktif'}) async {
    final res = await _api
        .get(AppConstants.adminMekanikUrl, query: {'tampilkan': tampilkan});
    if (res['success'] != true) return [];
    final data = res['data'];
    if (data is! List) return [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(MekanikModel.fromJson)
        .toList();
  }

  Future<Map<String, dynamic>> tambahMekanik({
    required String nama,
    String? noHp,
    String? spesialisasi,
  }) =>
      _api.post(AppConstants.adminMekanikUrl, {
        'nama': nama,
        if (noHp != null && noHp.isNotEmpty) 'no_hp': noHp,
        if (spesialisasi != null && spesialisasi.isNotEmpty)
          'spesialisasi': spesialisasi,
      });

  Future<Map<String, dynamic>> editMekanik(int id,
          {required String nama, String? noHp, String? spesialisasi}) =>
      _api.put('${AppConstants.adminMekanikUrl}?id=$id', {
        'nama': nama,
        if (noHp != null) 'no_hp': noHp,
        if (spesialisasi != null) 'spesialisasi': spesialisasi,
      });

  Future<Map<String, dynamic>> toggleAktifMekanik(int id, bool aktif) =>
      _api.put('${AppConstants.adminMekanikUrl}?id=$id',
          {'action': 'toggle_aktif', 'is_aktif': aktif ? 1 : 0});

  Future<Map<String, dynamic>> hapusMekanik(int id) =>
      _api.delete('${AppConstants.adminMekanikUrl}?id=$id');

  // ── Jenis Servis ──────────────────────────────────────────

  Future<List<JenisServisModel>> getJenisServis(
      {String tampilkan = 'semua'}) async {
    final res = await _api
        .get(AppConstants.adminJenisServisUrl, query: {'tampilkan': tampilkan});
    if (res['success'] != true) return [];
    final data = res['data'];
    if (data is! List) return [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(JenisServisModel.fromJson)
        .toList();
  }

  Future<Map<String, dynamic>> tambahJenisServis({
    required String nama,
    String? deskripsi,
    required double hargaJasa,
    required int estimasiMenit,
  }) =>
      _api.post(AppConstants.adminJenisServisUrl, {
        'nama': nama,
        if (deskripsi != null && deskripsi.isNotEmpty) 'deskripsi': deskripsi,
        'harga_jasa': hargaJasa,
        'estimasi_menit': estimasiMenit,
      });

  Future<Map<String, dynamic>> editJenisServis(
    int id, {
    required String nama,
    String? deskripsi,
    required double hargaJasa,
    required int estimasiMenit,
  }) =>
      _api.put('${AppConstants.adminJenisServisUrl}?id=$id', {
        'nama': nama,
        if (deskripsi != null) 'deskripsi': deskripsi,
        'harga_jasa': hargaJasa,
        'estimasi_menit': estimasiMenit,
      });

  Future<Map<String, dynamic>> toggleAktifJenisServis(int id, bool aktif) =>
      _api.put('${AppConstants.adminJenisServisUrl}?id=$id',
          {'action': 'toggle_aktif', 'is_aktif': aktif ? 1 : 0});

  Future<Map<String, dynamic>> hapusJenisServis(int id) =>
      _api.delete('${AppConstants.adminJenisServisUrl}?id=$id');

  // ── Akun Owner ────────────────────────────────────────────

  Future<Map<String, dynamic>> getOwnerInfo() =>
      _api.get(AppConstants.adminAkunOwnerUrl);

  Future<Map<String, dynamic>> resetPasswordOwner(String passwordBaru) =>
      _api.put(AppConstants.adminAkunOwnerUrl, {'password_baru': passwordBaru});

  // ── Akun Kasir ────────────────────────────────────────────

  Future<List<AkunKasirModel>> getAkunKasir() async {
    final res = await _api.get(AppConstants.adminAkunKasirUrl);
    if (res['success'] != true) return [];
    final data = res['data'];
    if (data is! List) return [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(AkunKasirModel.fromJson)
        .toList();
  }

  Future<Map<String, dynamic>> tambahKasir({
    required String nama,
    required String username,
    required String password,
  }) =>
      _api.post(AppConstants.adminAkunKasirUrl,
          {'nama': nama, 'username': username, 'password': password});

  Future<Map<String, dynamic>> toggleAktifKasir(int id, bool aktif) => _api.put(
      '${AppConstants.adminAkunKasirUrl}?id=$id', {'is_aktif': aktif ? 1 : 0});

  Future<Map<String, dynamic>> resetPasswordKasir(
          int id, String passwordBaru) =>
      _api.put('${AppConstants.adminAkunKasirUrl}?id=$id',
          {'action': 'reset_password', 'password_baru': passwordBaru});

  Future<Map<String, dynamic>> hapusKasir(int id) =>
      _api.delete('${AppConstants.adminAkunKasirUrl}?id=$id');

  // ── Pelanggan ─────────────────────────────────────────────

  Future<Map<String, dynamic>> getPelangganList({
    String? search,
    String filter = 'semua',
    int page = 1,
  }) {
    final params = <String, String>{'filter': filter, 'page': '$page'};
    if (search != null && search.isNotEmpty) params['search'] = search;
    return _api.get(AppConstants.adminPelangganUrl, query: params);
  }

  Future<Map<String, dynamic>> getDetailPelanggan(int id,
          {bool riwayat = false}) =>
      _api.get(AppConstants.adminPelangganUrl, query: {
        'id': '$id',
        if (riwayat) 'riwayat': '1',
      });

  Future<Map<String, dynamic>> bukaBlokirPelanggan(int id, {String? alasan}) =>
      _api.put('${AppConstants.adminPelangganUrl}?id=$id',
          {if (alasan != null) 'alasan': alasan});

  Future<Map<String, dynamic>> blokirManual(int id,
          {int? hari, required String alasan}) =>
      _api.put(AppConstants.adminBlokirUrl, {
        'pelanggan_id': id,
        'aksi': 'blokir_manual',
        'alasan': alasan,
        if (hari != null) 'hari': hari,
      });

  // ── Hari Libur ────────────────────────────────────────────

  Future<List<HariLiburModel>> getHariLibur({int? tahun}) async {
    final params = tahun != null ? {'tahun': '$tahun'} : null;
    final res = await _api.get(AppConstants.adminHariLiburUrl, query: params);
    if (res['success'] != true) return [];
    final data = res['data'];
    if (data is! List) return [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(HariLiburModel.fromJson)
        .toList();
  }

  Future<Map<String, dynamic>> tambahHariLibur(
          {required String tanggal, required String keterangan}) =>
      _api.post(AppConstants.adminHariLiburUrl,
          {'tanggal': tanggal, 'keterangan': keterangan});

  Future<Map<String, dynamic>> hapusHariLibur(int id) =>
      _api.delete('${AppConstants.adminHariLiburUrl}?id=$id');

  // ── Stok Menipis ──────────────────────────────────────────

  Future<Map<String, dynamic>> getStokMenipis() =>
      _api.get(AppConstants.adminStokMenipisUrl);
}
