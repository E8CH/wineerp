import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/audit/audit_screen.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/login_screen.dart';
import '../features/catalog/catalog_screen.dart';
import '../features/inventory/inventory_screen.dart';
import '../features/receiving/history_screen.dart';
import '../features/report/report_screen.dart';
import '../features/scan/scan_screen.dart';

/// 인증 변화를 go_router에 알리는 브리지.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    ref.listen(authControllerProvider, (_, _) => notifyListeners());
  }
}

/// 앱 라우터 — 미인증 시 /login 리다이렉트, 그 외 하단 6탭 셸(홈=스캔).
/// 로그(활동 로그)는 관리자 전용이라 탭은 보이되 화면 안에서 차단한다(리포트와 동일).
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/scan',
    refreshListenable: _AuthRefresh(ref),
    redirect: (context, state) {
      final authed = ref.read(authControllerProvider).isAuthenticated;
      final loggingIn = state.matchedLocation == '/login';
      if (!authed) return loggingIn ? null : '/login';
      if (loggingIn) return '/scan';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
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
          StatefulShellBranch(
            routes: [GoRoute(path: '/catalog', builder: (c, s) => const CatalogScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/audit', builder: (c, s) => const AuditScreen())],
          ),
        ],
      ),
    ],
  );
});

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
          NavigationDestination(
            icon: Icon(Icons.style_outlined),
            selectedIcon: Icon(Icons.style),
            label: '모델',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: '로그',
          ),
        ],
      ),
    );
  }
}
