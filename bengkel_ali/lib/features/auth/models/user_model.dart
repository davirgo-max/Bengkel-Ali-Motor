// lib/features/auth/models/user_model.dart

class UserModel {
  final int id;
  final String nama;
  final String role; // 'owner' | 'kasir' | 'pelanggan'
  final String? username; // untuk kasir/owner/admin
  final String? noHp; // untuk pelanggan
  final String? email; // untuk pelanggan

  const UserModel({
    required this.id,
    required this.nama,
    required this.role,
    this.username,
    this.noHp,
    this.email,
  });

  factory UserModel.fromJson(Map<String, dynamic> json, String role) {
    return UserModel(
      id: json['id'] as int,
      nama: json['nama'] as String,
      role: role,
      username: json['username'] as String?,
      noHp: json['no_hp'] as String?,
      email: json['email'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nama': nama,
        'role': role,
        'username': username,
        'no_hp': noHp,
        'email': email,
      };

  bool get isPelanggan => role == 'pelanggan';
  bool get isKasir => role == 'kasir';
  bool get isOwner => role == 'owner';
  bool get isAdmin => role == 'admin';
}
