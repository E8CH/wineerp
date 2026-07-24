import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wineerp_app/data/audit_repository.dart';
import 'package:wineerp_app/data/inventory_repository.dart';
import 'package:wineerp_app/data/wine_catalog_repository.dart';
import 'package:wineerp_app/features/auth/auth_controller.dart';
import 'package:wineerp_app/features/scan/scan_controller.dart';
import 'package:wineerp_app/main.dart';

/// 탭 재진입 시 데이터 재조회 — IndexedStack이 탭을 계속 살려둬(dispose 안 됨)
/// FutureProvider가 최초 1회만 캐시하던 문제를 검증한다. 특히 로그 탭은 어느 mutation도
/// 무효화하지 않아, 다른 탭에서 등록·수정·삭제를 해도 반영이 누락됐다.
///
/// 조회할 때마다 내용을 바꿔("조회 N") 재진입 시 화면이 갱신되는 것까지 확인한다.
class _CountingAuditRepo extends AuditRepository {
  _CountingAuditRepo() : super(Dio());

  int calls = 0;

  @override
  Future<List<AuditItem>> list() async {
    calls++;
    return [
      AuditItem(
        id: 'id-$calls',
        action: 'wine.create',
        actorEmail: 'm@w.co',
        summary: '조회 $calls',
        entityType: 'wine',
        createdAt: DateTime(2026, 7, 24, 10),
      ),
    ];
  }
}

class _ManagerController extends AuthController {
  @override
  AuthState build() =>
      const AuthState(token: 't', email: 'm@w.co', role: 'manager');
}

void main() {
  testWidgets('로그 탭을 나갔다 돌아오면 다시 읽어 최신 기록을 보여준다', (tester) async {
    final repo = _CountingAuditRepo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_ManagerController.new),
          cameraEnabledProvider.overrideWithValue(false),
          // 다른 탭이 실제 네트워크를 치지 않도록 빈 목록으로 대체.
          inventoryProvider.overrideWith((ref) async => const <InventoryItem>[]),
          catalogProvider
              .overrideWith((ref) async => const <ProductCatalogItem>[]),
          auditRepositoryProvider.overrideWithValue(repo),
        ],
        child: const WineerpApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 첫 방문: 로그 탭이 빌드되며 조회된다.
    await tester.tap(find.text('로그'));
    await tester.pumpAndSettle();
    expect(find.textContaining('조회 1'), findsOneWidget);
    final firstVisitCalls = repo.calls;
    expect(firstVisitCalls, greaterThanOrEqualTo(1));

    // 다른 탭(재고)으로 이동 — 그 사이 새 활동이 쌓였다고 가정한다.
    await tester.tap(find.text('재고'));
    await tester.pumpAndSettle();

    // 로그로 되돌아오면 다시 읽어 최신을 보여준다(캐시에 머물지 않는다).
    await tester.tap(find.text('로그'));
    await tester.pumpAndSettle();
    expect(repo.calls, greaterThan(firstVisitCalls),
        reason: '탭 재진입 시 데이터를 다시 읽어야 한다');
    expect(find.text('조회 ${repo.calls}'), findsOneWidget);
    expect(find.textContaining('조회 1'), findsNothing);
  });
}
