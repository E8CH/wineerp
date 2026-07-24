import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wineerp_app/core/theme.dart';
import 'package:wineerp_app/data/audit_repository.dart';
import 'package:wineerp_app/features/audit/audit_screen.dart';
import 'package:wineerp_app/features/auth/auth_controller.dart';

/// 활동 로그(감사) — 관리자 전용, 연속 리스트, 탭 시 상세.
class _FakeAuditRepo extends AuditRepository {
  _FakeAuditRepo(this._items, {this.fail = false}) : super(Dio());

  final List<AuditItem> _items;
  final bool fail;
  int calls = 0;

  @override
  Future<List<AuditItem>> list() async {
    calls++;
    if (fail) throw Exception('boom');
    return _items;
  }
}

class _RoleController extends AuthController {
  _RoleController(this._role);

  final String _role;

  @override
  AuthState build() => AuthState(token: 't', email: 'u@w.co', role: _role);
}

AuditItem _item({
  String action = 'receiving.create',
  String summary = 'Test Maison Cuvée 2019 · 12병 입고',
  String actor = 'staff@wineerp.co',
  Map<String, dynamic> detail = const {'quantity': 12},
}) =>
    AuditItem(
      id: 'id-$action',
      action: action,
      actorEmail: actor,
      summary: summary,
      entityType: 'receiving',
      createdAt: DateTime(2026, 7, 24, 14, 30),
      detail: detail,
    );

ProviderContainer _container(
  _FakeAuditRepo repo, {
  String role = 'manager',
}) {
  final c = ProviderContainer(overrides: [
    auditRepositoryProvider.overrideWithValue(repo),
    authControllerProvider.overrideWith(() => _RoleController(role)),
  ]);
  addTearDown(c.dispose);
  return c;
}

Widget _host(ProviderContainer c) => UncontrolledProviderScope(
      container: c,
      child: MaterialApp(theme: AppTheme.light, home: const AuditScreen()),
    );

void main() {
  group('권한', () {
    testWidgets('staff에게는 로그가 보이지 않는다', (tester) async {
      final repo = _FakeAuditRepo([_item()]);
      await tester.pumpWidget(_host(_container(repo, role: 'staff')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('audit_forbidden')), findsOneWidget);
      expect(repo.calls, 0, reason: '차단됐으면 호출도 하지 않는다');
    });

    testWidgets('manager에게는 로그가 보인다', (tester) async {
      await tester.pumpWidget(_host(_container(_FakeAuditRepo([_item()]))));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('audit_forbidden')), findsNothing);
      expect(find.textContaining('12병 입고'), findsOneWidget);
    });
  });

  group('리스트', () {
    testWidgets('카드가 아닌 연속 리스트(구분선)로 그린다', (tester) async {
      final repo = _FakeAuditRepo([
        _item(action: 'wine.create', summary: '모델 A 등록'),
        _item(action: 'wine.archive', summary: '모델 A 삭제'),
      ]);
      await tester.pumpWidget(_host(_container(repo)));
      await tester.pumpAndSettle();

      // 요구사항: 카드 형태가 아니어야 한다.
      expect(find.byType(Card), findsNothing);
      expect(find.byType(Divider), findsWidgets);
      expect(find.byType(ListTile), findsNWidgets(2));
    });

    testWidgets('액션별 한글 라벨이 뜬다', (tester) async {
      await tester.pumpWidget(
        _host(_container(_FakeAuditRepo([_item(action: 'wine.archive')]))),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('모델 삭제'), findsOneWidget);
    });
  });

  group('상세', () {
    testWidgets('행을 누르면 상세 시트에 수량 변경이 나온다', (tester) async {
      final repo = _FakeAuditRepo([
        _item(
          action: 'receiving.amend',
          summary: '수량 수정',
          detail: const {'before_quantity': 10, 'after_quantity': 15},
        ),
      ]);
      await tester.pumpWidget(_host(_container(repo)));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ListTile).first);
      await tester.pumpAndSettle();

      // before→after가 사람이 읽는 형태로 보여야 한다.
      expect(find.textContaining('10병 → 15병'), findsOneWidget);
      expect(find.text('작업자'), findsOneWidget);
    });

    testWidgets('모델 수정은 바뀐 필드만 before→after로 보여준다', (tester) async {
      final repo = _FakeAuditRepo([
        _item(
          action: 'wine.update',
          summary: '모델 정보 수정',
          detail: const {
            'before': {'model_name': '옛이름', 'producer': '같은곳'},
            'after': {'model_name': '새이름', 'producer': '같은곳'},
          },
        ),
      ]);
      await tester.pumpWidget(_host(_container(repo)));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ListTile).first);
      await tester.pumpAndSettle();

      expect(find.textContaining('옛이름 → 새이름'), findsOneWidget);
      // 안 바뀐 필드(생산자)는 표시하지 않는다 — 잡음을 줄인다.
      expect(find.text('생산자'), findsNothing);
    });
  });

  group('상태', () {
    testWidgets('비어 있으면 빈 상태', (tester) async {
      await tester.pumpWidget(_host(_container(_FakeAuditRepo([]))));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('audit_empty')), findsOneWidget);
    });

    testWidgets('실패하면 오류 상태', (tester) async {
      await tester.pumpWidget(
        _host(_container(_FakeAuditRepo([], fail: true))),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('audit_error')), findsOneWidget);
    });
  });
}
