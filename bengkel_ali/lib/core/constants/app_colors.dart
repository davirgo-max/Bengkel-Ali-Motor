import 'package:flutter/material.dart';

class AppColors {
  AppColors._();
  static const primary     = Color(0xFF1565C0);
  static const primaryLight= Color(0xFF1E88E5);
  static const accent      = Color(0xFFFF6F00);
  static const success     = Color(0xFF2E7D32);
  static const warning     = Color(0xFFF57F17);
  static const danger      = Color(0xFFC62828);
  static const bgLight     = Color(0xFFF5F7FA);
  static const textPrimary = Color(0xFF1A1A2E);
  static const textSecondary = Color(0xFF6B7280);
  static const cardBg      = Colors.white;

  // Status booking/servis
  static Color statusColor(String status) {
    switch (status) {
      case 'menunggu':       return const Color(0xFFF57F17);
      case 'dikonfirmasi':   return const Color(0xFF1565C0);
      case 'aktif':
      case 'dikerjakan':     return const Color(0xFF6A1B9A);
      case 'menunggu_part':  return const Color(0xFFE65100);
      case 'selesai_servis':
      case 'selesai':        return const Color(0xFF2E7D32);
      case 'dibatalkan':
      case 'no_show':        return const Color(0xFFC62828);
      case 'antrian':        return const Color(0xFF00838F);
      default:               return const Color(0xFF6B7280);
    }
  }

  static String statusLabel(String status) {
    switch (status) {
      case 'menunggu':       return 'Menunggu';
      case 'dikonfirmasi':   return 'Dikonfirmasi';
      case 'aktif':          return 'Aktif';
      case 'antrian':        return 'Dalam Antrian';
      case 'dikerjakan':     return 'Sedang Dikerjakan';
      case 'menunggu_part':  return 'Menunggu Sparepart';
      case 'selesai_servis': return 'Servis Selesai';
      case 'selesai':        return 'Selesai';
      case 'dibatalkan':     return 'Dibatalkan';
      case 'no_show':        return 'Tidak Hadir';
      default:               return status;
    }
  }
}
