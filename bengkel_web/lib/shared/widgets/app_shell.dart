// lib/shared/widgets/app_shell.dart
//
// Layout dasar dashboard: sidebar (logo, nav, user) + topbar + konten.
// Dipakai bersama oleh AdminShell, KasirShell, dan OwnerShell agar
// tampilan konsisten antar role (sesuai mockup).

import 'package:flutter/material.dart';
import '../../core/constants/app_theme.dart';
import '../../core/state/auth_state.dart';
import '../../core/utils/format_helper.dart';

class NavEntry {
  final String? sectionTitle; // jika diisi, item ini adalah header section
  final IconData? icon;
  final String? label;
  final String? route;

  const NavEntry.section(this.sectionTitle)
      : icon = null,
        label = null,
        route = null;

  const NavEntry.item({
    required this.icon,
    required this.label,
    required this.route,
  }) : sectionTitle = null;
}

class AppShell extends StatelessWidget {
  final String roleLabel;
  final Color roleBg;
  final Color roleFg;
  final List<NavEntry> nav;
  final String currentRoute;
  final ValueChanged<String> onNavigate;
  final String pageTitle;
  final List<Widget> actions;
  final Widget child;

  const AppShell({
    super.key,
    required this.roleLabel,
    required this.roleBg,
    required this.roleFg,
    required this.nav,
    required this.currentRoute,
    required this.onNavigate,
    required this.pageTitle,
    this.actions = const [],
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final user = AuthState.instance.user;
    final isNarrow = MediaQuery.of(context).size.width < 880;

    final sidebar = Container(
      width: 220,
      decoration: const BoxDecoration(
        color: AppTheme.sidebarBg,
        border: Border(
          right: BorderSide(color: Color(0xFFE8E8EE), width: 0.5),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFE8E8EE), width: 0.5),
              ),
            ),
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bengkel Ali Motor',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Dashboard Staff',
                  style: TextStyle(fontSize: 11, color: Color(0xFF888899)),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: roleBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    roleLabel,
                    style: TextStyle(fontSize: 10, color: roleFg),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: nav.map((e) {
                if (e.sectionTitle != null) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      e.sectionTitle!.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFFAAAAB8),
                        letterSpacing: 0.6,
                      ),
                    ),
                  );
                }
                final active = e.route == currentRoute;
                return InkWell(
                  onTap: () => onNavigate(e.route!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    color: active ? Colors.white : Colors.transparent,
                    child: Row(
                      children: [
                        Icon(
                          e.icon,
                          size: 17,
                          color: active ? roleFg : const Color(0xFF666680),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          e.label!,
                          style: TextStyle(
                            fontSize: 13,
                            color: active ? roleFg : const Color(0xFF444455),
                            fontWeight:
                                active ? FontWeight.w500 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFFE8E8EE), width: 0.5),
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _confirmLogout(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: roleBg,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          user != null ? initialsOf(user.nama) : '?',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: roleFg,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            user?.nama ?? '-',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                          Text(
                            user?.roleLabel ?? '',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF888899),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.logout,
                      size: 15,
                      color: Color(0xFFAAAAB8),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final main = Column(
      children: [
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Color(0xFFE8E8EE), width: 0.5),
            ),
          ),
          child: Row(
            children: [
              if (isNarrow)
                Builder(
                  builder: (ctx) => IconButton(
                    icon: const Icon(Icons.menu, size: 20),
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  ),
                ),
              Expanded(
                child: Text(
                  pageTitle,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A2E),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Wrap(spacing: 8, children: actions),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: AppTheme.canvasBg,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: child,
            ),
          ),
        ),
      ],
    );

    if (isNarrow) {
      return Scaffold(
        drawer: Drawer(child: sidebar),
        body: main,
      );
    }

    return Scaffold(
      body: Row(
        children: [
          sidebar,
          Expanded(child: main),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Keluar?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'Anda akan keluar dari dashboard staff.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await AuthState.instance.logout();
    }
  }
}

/// Tombol topbar (outline / primary) konsisten dengan style mockup.
class TopbarButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool primary;

  const TopbarButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return primary
        ? ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 15),
            label: Text(label),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            ),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 15),
            label: Text(label),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            ),
          );
  }
}
