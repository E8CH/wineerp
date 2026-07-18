import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/inventory/inventory_screen.dart';
import '../features/receiving/history_screen.dart';
import '../features/report/report_screen.dart';
import '../features/scan/scan_screen.dart';

/// 앱 라우터 — 하단 4탭 셸(스캔·내역·리포트·재고), 홈=스캔.
final appRouter = GoRouter(
  initialLocation: '/scan',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          _ScaffoldWithNav(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: '/scan', builder: (c, s) => const ScanScreen())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/history', builder: (c, s) => const HistoryScreen())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/report', builder: (c, s) => const ReportScreen())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/inventory', builder: (c, s) => const InventoryScreen())],
        ),
      ],
    ),
  ],
);

class _ScaffoldWithNav extends StatelessWidget {
  const _ScaffoldWithNav({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onTap,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_outlined),
            selectedIcon: Icon(Icons.qr_code_scanner),
            label: '스캔',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: '내역',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: '리포트',
          ),
          NavigationDestination(
            icon: Icon(Icons.wine_bar_outlined),
            selectedIcon: Icon(Icons.wine_bar),
            label: '재고',
          ),
        ],
      ),
    );
  }
}
