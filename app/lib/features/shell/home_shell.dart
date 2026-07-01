import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dashboard/presentation/dashboard_screen.dart';
import '../events/presentation/calendar_screen.dart';
import '../finance/presentation/finance_screen.dart';
import '../maintenance/presentation/maintenance_screen.dart';
import '../profiles/data/profile_repository.dart';
import '../profiles/domain/profile.dart';
import 'more_screen.dart';

class _Tab {
  const _Tab(this.screen, this.icon, this.selectedIcon, this.label);
  final Widget screen;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Navegación principal. Muestra las secciones según el rol del usuario:
/// los administradores ven todo; coordinadores y trabajadores, lo suyo.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  List<_Tab> _tabsFor(UserRole role) {
    return [
      const _Tab(CalendarScreen(), Icons.calendar_month_outlined,
          Icons.calendar_month, 'Calendario'),
      if (role.isAdmin)
        const _Tab(DashboardScreen(), Icons.insights_outlined, Icons.insights,
            'Resumen'),
      if (role.isAdmin)
        const _Tab(FinanceScreen(), Icons.account_balance_wallet_outlined,
            Icons.account_balance_wallet, 'Finanzas'),
      const _Tab(MaintenanceScreen(), Icons.build_outlined, Icons.build,
          'Mantenim.'),
      const _Tab(MoreScreen(), Icons.menu, Icons.menu, 'Más'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final role = profileAsync.valueOrNull?.role ?? UserRole.worker;
    final tabs = _tabsFor(role);
    final index = _index.clamp(0, tabs.length - 1);

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: [for (final t in tabs) t.screen],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final t in tabs)
            NavigationDestination(
              icon: Icon(t.icon),
              selectedIcon: Icon(t.selectedIcon),
              label: t.label,
            ),
        ],
      ),
    );
  }
}
