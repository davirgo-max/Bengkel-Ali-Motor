// lib/features/auth/models/user_model.dart

import 'dart:convert';

class UserModel {
  final int id;
  final String nama;
  final String role;
  final String? username;

  const UserModel({
    required this.id,
    required this.nama,
    required this.role,
    this.username,
  });

  /// [json] adalah objek user (mis. dari `data['user']`), [role] dari `data['role']`.
  factory UserModel.fromJson(Map<String, dynamic> json, String role) =>
      UserModel(
        id: json['id'] is int ? json['id'] as int : int.parse('${json['id']}'),
        nama: json['nama'] as String,
        role: role,
        username: json['username'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nama': nama,
    'role': role,
    'username': username,
  };

  String toJsonString() => jsonEncode(toJson());

  factory UserModel.fromJsonString(String s) {
    final m = jsonDecode(s) as Map<String, dynamic>;
    return UserModel(
      id: m['id'] as int,
      nama: m['nama'] as String,
      role: m['role'] as String,
      username: m['username'] as String?,
    );
  }

  bool get isAdmin => role == 'admin';
  bool get isKasir => role == 'kasir';
  bool get isOwner => role == 'owner';

  String get initials {
    final parts = nama.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return nama.isNotEmpty ? nama[0].toUpperCase() : '?';
  }

  String get roleLabel {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'kasir':
        return 'Kasir';
      case 'owner':
        return 'Owner';
      default:
        return role;
    }
  }
}
