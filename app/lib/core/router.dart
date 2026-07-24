import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/audit_repository.dart';
import '../data/history_repository.dart';
import '../data/inventory_repository.dart';
import '../data/report_repository.dart';
import '../data/wine_catalog_repository.dart';
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

class _ScaffoldWithNav extends ConsumerWidget {
  const _ScaffoldWithNav({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(WidgetRef ref, int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
    _refreshBranch(ref, index);
  }

  /// 탭에 들어올 때마다 그 탭의 데이터를 새로 읽는다.
  ///
  /// IndexedStack이 모든 탭을 앱 시작 시 빌드하고 계속 살려두므로(dispose 안 됨),
  /// FutureProvider는 최초 1회만 조회하고 캐시한 채로 머문다 — 다른 탭에서 등록·수정·
  /// 삭제·입고를 해도 반영이 누락됐다(특히 로그 탭은 어느 mutation도 무효화하지 않아
  /// 로그인 직후의 빈 결과가 계속 보였다). 탭 진입 시점에 무효화하면 무슨 변경이 있었든
  /// 항상 최신을 보여준다. 진입하는 탭은 곧 화면에 뜨고 구독 중이라, 무효화가 즉시
  /// 재조회로 이어지고 orphan 타이머 걱정도 없다(inventory_repository의 주의 참고).
  /// `AsyncValue.when`은 skipLoadingOnRefresh 기본값이 true라 재조회 중에도 이전
  /// 데이터를 유지해 깜빡이지 않는다. 스캔(0)은 리스트 데이터가 없어 건너뛴다.
  void _refreshBranch(WidgetRef ref, int index) {
    switch (index) {
      case 1: // 내역
        ref.invalidate(historyProvider);
      case 2: // 리포트
        ref.invalidate(reportProvider);
      case 3: // 재고 — autoDispose+리비전 패턴을 따른다
        ref.read(inventoryRevisionProvider.notifier).state++;
      case 4: // 모델(카탈로그) — 리비전 패턴을 따른다
        ref.read(catalogRevisionProvider.notifier).state++;
      case 5: // 로그(활동)
        ref.invalidate(auditProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 폴드 커버(≈280~344dp)·소형 기기에서 6개 탭 라벨이 잘리므로, 좁으면 선택된 탭만
    // 라벨을 보인다. 일반 폰(≥360dp, 예: S24 ~411dp)은 테마 기본값(항상 표시)을 쓴다.
    final narrow = MediaQuery.sizeOf(context).width < 360;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        labelBehavior: narrow
            ? NavigationDestinationLabelBehavior.onlyShowSelected
            : NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) => _onTap(ref, index),
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
