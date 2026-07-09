import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../accounting/presentation/investments_screen.dart';
import '../auth/data/auth_repository.dart';
import '../dashboard/presentation/dashboard_screen.dart';
import '../events/presentation/calendar_screen.dart';
import '../finance/presentation/finance_screen.dart';
import '../maintenance/presentation/maintenance_screen.dart';
import '../profiles/data/profile_repository.dart';
import '../profiles/domain/profile.dart';
import '../profiles/presentation/team_screen.dart';

/// Una entrada del menú lateral.
class _NavPage {
  const _NavPage(this.label, this.icon, this.group, this.body);
  final String label;
  final IconData icon;
  final String group; // 'PRINCIPAL' | 'GESTIÓN'
  final Widget body;
}

const _breakpoint = 900.0;

/// Navegación principal con barra lateral izquierda (estilo panel de gestión).
/// En pantallas anchas queda fija; en el celular se abre con el botón ☰.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  List<_NavPage> _pagesFor(UserRole role) {
    return [
      const _NavPage('Calendario', Icons.calendar_month_rounded, 'PRINCIPAL',
          CalendarScreen()),
      if (role.isAdmin)
        const _NavPage(
            'Resumen', Icons.dashboard_rounded, 'PRINCIPAL', DashboardScreen()),
      if (role.isAdmin)
        const _NavPage('Finanzas', Icons.account_balance_wallet_rounded,
            'GESTIÓN', FinanceScreen()),
      if (role.isAdmin)
        const _NavPage('Inversiones', Icons.savings_rounded, 'GESTIÓN',
            InvestmentsScreen()),
      const _NavPage(
          'Mantenimiento', Icons.build_rounded, 'GESTIÓN', MaintenanceScreen()),
      if (role.isAdmin)
        const _NavPage('Equipo', Icons.groups_rounded, 'GESTIÓN', TeamScreen()),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final role = profile?.role ?? UserRole.worker;
    final pages = _pagesFor(role);
    final index = _index.clamp(0, pages.length - 1);
    final current = pages[index];
    final wide = MediaQuery.of(context).size.width >= _breakpoint;

    void onSelect(int i) {
      setState(() => _index = i);
      if (!wide) Navigator.of(context).maybePop(); // cerrar drawer
    }

    final sidebar = _Sidebar(
      pages: pages,
      selected: index,
      onSelect: onSelect,
      profile: profile,
      onLogout: () => ref.read(authRepositoryProvider).signOut(),
    );

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            SizedBox(width: 264, child: sidebar),
            const VerticalDivider(width: 1),
            Expanded(
              child: _PageArea(title: current.label, child: current.body),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        width: 280,
        backgroundColor: AppColors.sidebar,
        child: sidebar,
      ),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(current.label),
      ),
      body: current.body,
    );
  }
}

/// Área de contenido en pantallas anchas: barra superior con el título + página.
class _PageArea extends StatelessWidget {
  const _PageArea({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          alignment: Alignment.centerLeft,
          decoration: const BoxDecoration(
            border:
                Border(bottom: BorderSide(color: AppColors.border, width: 1)),
          ),
          child: Text(title,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800)),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.pages,
    required this.selected,
    required this.onSelect,
    required this.profile,
    required this.onLogout,
  });

  final List<_NavPage> pages;
  final int selected;
  final ValueChanged<int> onSelect;
  final Profile? profile;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    // Agrupar por sección conservando el índice global.
    final groups = <String, List<int>>{};
    for (var i = 0; i < pages.length; i++) {
      groups.putIfAbsent(pages[i].group, () => []).add(i);
    }

    return Container(
      color: AppColors.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Logo
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.brand, AppColors.kids],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.celebration_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('IUPI',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1)),
                    Text('Gestión del salón',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final entry in groups.entries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  for (final i in entry.value)
                    _SidebarItem(
                      icon: pages[i].icon,
                      label: pages[i].label,
                      selected: i == selected,
                      onTap: () => onSelect(i),
                    ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          _ProfileFooter(profile: profile, onLogout: onLogout),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? AppColors.brand.withValues(alpha: 0.16) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon,
                    size: 20,
                    color: selected ? AppColors.brand : AppColors.textMuted),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color:
                        selected ? AppColors.textStrong : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileFooter extends StatelessWidget {
  const _ProfileFooter({required this.profile, required this.onLogout});
  final Profile? profile;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final name = profile?.displayName ?? 'Usuario';
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.brand,
            child: Text(
              name.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                Text(profile?.role.label ?? '',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout_rounded, color: AppColors.textMuted),
            onPressed: onLogout,
          ),
        ],
      ),
    );
  }
}
