import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wineerp_app/core/theme.dart';
import 'package:wineerp_app/data/history_repository.dart';
import 'package:wineerp_app/features/auth/auth_controller.dart';
import 'package:wineerp_app/features/receiving/widgets/amend_sheet.dart';

/// Story 4.2 — 입고 수량 수정 (FR8, AR6).
class _FakeAmendRepo extends ReceivingAmendRepository {
  _FakeAmendRepo({this.fail = false}) : super(Dio());

  final bool fail;
  final List<Map<String, dynamic>> updates = [];
  final List<String> cancels = [];

  @override
  Future<void> updateQuantity(
    String recordId, {
    required int quantity,
    String? reason,
  }) async {
    if (fail) throw Exception('boom');
    updates.add({'id': recordId, 'quantity': quantity, 'reason': reason});
  }

  @override
  Future<void> cancel(String recordId) async {
    if (fail) throw Exception('boom');
    cancels.add(recordId);
  }
}

class _RoleController extends AuthController {
  _RoleController(this._role);

  final String _role;

  @override
  AuthState build() =>
      AuthState(token: 't', email: 'u@w.co', role: _role);
}

HistoryItem _item() => HistoryItem(
      id: 'rec-1',
      producer: 'Penfolds',
      modelName: 'Grange',
      vintage: 2016,
      quantity: 12,
      receivedAt: DateTime(2026, 7, 19, 10),
      staffEmail: 'staff@wineerp.co',
    );

ProviderContainer _container(_FakeAmendRepo repo, {String role = 'staff'}) {
  final c = ProviderContainer(overrides: [
    receivingAmendRepositoryProvider.overrideWithValue(repo),
    authControllerProvider.overrideWith(() => _RoleController(role)),
  ]);
  addTearDown(c.dispose);
  return c;
}

Widget _host(ProviderContainer c, {VoidCallback? onDone}) =>
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AmendSheet(item: _item(), onDone: onDone ?? () {}),
        ),
      ),
    );

void main() {
  testWidgets('현재 수량이 채워진 채로 열린다', (tester) async {
    await tester.pumpWidget(_host(_container(_FakeAmendRepo())));
    expect(find.text('12'), findsWidgets);
  });

  testWidgets('수량을 바꿔 저장하면 사유와 함께 전송된다', (tester) async {
    final repo = _FakeAmendRepo();
    await tester.pumpWidget(_host(_container(repo)));

    await tester.tap(find.byKey(const Key('quantity_decrease')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('amend_reason')), '오입력');
    await tester.pump();
    await tester.tap(find.byKey(const Key('amend_save')));
    await tester.pumpAndSettle();

    expect(repo.updates.single['quantity'], 11);
    expect(repo.updates.single['reason'], '오입력');
  });

  testWidgets('사유가 비면 null로 보낸다', (tester) async {
    final repo = _FakeAmendRepo();
    await tester.pumpWidget(_host(_container(repo)));
    await tester.tap(find.byKey(const Key('amend_save')));
    await tester.pumpAndSettle();
    expect(repo.updates.single['reason'], isNull);
  });

  testWidgets('저장이 끝나면 onDone으로 목록 갱신을 알린다', (tester) async {
    var done = false;
    await tester.pumpWidget(
      _host(_container(_FakeAmendRepo()), onDone: () => done = true),
    );
    await tester.tap(find.byKey(const Key('amend_save')));
    await tester.pumpAndSettle();
    expect(done, isTrue);
  });

  testWidgets('실패하면 시트를 닫지 않고 오류를 보여준다', (tester) async {
    var done = false;
    await tester.pumpWidget(
      _host(_container(_FakeAmendRepo(fail: true)), onDone: () => done = true),
    );
    await tester.tap(find.byKey(const Key('amend_save')));
    await tester.pumpAndSettle();

    expect(find.textContaining('저장 실패'), findsOneWidget);
    expect(done, isFalse, reason: '실패했는데 닫으면 수정된 줄 안다');
  });

  group('취소 권한 (manager 전용)', () {
    testWidgets('staff에게는 취소가 보이지 않는다', (tester) async {
      // 취소는 5년 보존 원장에서 재고를 빼는 일이고 복구 UI가 없다.
      await tester.pumpWidget(_host(_container(_FakeAmendRepo())));
      expect(find.byKey(const Key('amend_cancel_record')), findsNothing);
    });

    testWidgets('manager에게는 보이고 동작한다', (tester) async {
      final repo = _FakeAmendRepo();
      await tester.pumpWidget(_host(_container(repo, role: 'manager')));

      expect(find.byKey(const Key('amend_cancel_record')), findsOneWidget);
      await tester.tap(find.byKey(const Key('amend_cancel_record')));
      await tester.pumpAndSettle();
      expect(repo.cancels, ['rec-1']);
    });
  });
}
