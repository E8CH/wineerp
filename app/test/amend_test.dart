import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wineerp_app/core/theme.dart';
import 'package:wineerp_app/data/history_repository.dart';
import 'package:wineerp_app/data/image_repository.dart';
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

/// 유효한 1x1 PNG(디코드 성공용).
final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

class _FakeImageRepo extends ImageRepository {
  _FakeImageRepo() : super(Dio());
  @override
  Future<Uint8List> load(String key) async => _png;
}

class _RoleController extends AuthController {
  _RoleController(this._role);

  final String _role;

  @override
  AuthState build() =>
      AuthState(token: 't', email: 'u@w.co', role: _role);
}

HistoryItem _item({String? imageKey}) => HistoryItem(
      id: 'rec-1',
      producer: 'Penfolds',
      modelName: 'Grange',
      vintage: 2016,
      quantity: 12,
      receivedAt: DateTime(2026, 7, 19, 10),
      staffEmail: 'staff@wineerp.co',
      representativeImageKey: imageKey,
    );

ProviderContainer _container(
  _FakeAmendRepo repo, {
  String role = 'staff',
  ImageRepository? images,
}) {
  final c = ProviderContainer(overrides: [
    receivingAmendRepositoryProvider.overrideWithValue(repo),
    authControllerProvider.overrideWith(() => _RoleController(role)),
    if (images != null) imageRepositoryProvider.overrideWithValue(images),
  ]);
  addTearDown(c.dispose);
  return c;
}

Widget _host(ProviderContainer c, {VoidCallback? onDone, HistoryItem? item}) =>
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AmendSheet(item: item ?? _item(), onDone: onDone ?? () {}),
        ),
      ),
    );

void main() {
  testWidgets('현재 수량이 채워진 채로 열린다', (tester) async {
    await tester.pumpWidget(_host(_container(_FakeAmendRepo())));
    expect(find.text('12'), findsWidgets);
  });

  testWidgets('사진 key가 있으면 시트 상단에 큰 사진을 그린다', (tester) async {
    await tester.pumpWidget(_host(
      _container(_FakeAmendRepo(), images: _FakeImageRepo()),
      item: _item(imageKey: 'labels/a.jpg'),
    ));
    await tester.pumpAndSettle();

    final photo = find.byKey(const Key('amend_photo'));
    expect(photo, findsOneWidget);
    expect(
      find.descendant(of: photo, matching: find.byType(Image)),
      findsOneWidget,
    );
  });

  testWidgets('사진 key가 없으면 상단 사진 자리를 비운다', (tester) async {
    // 초기 세팅 등 사진 없는 기록에서 큰 빈 박스로 시트가 길어지지 않도록.
    await tester.pumpWidget(_host(_container(_FakeAmendRepo())));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('amend_photo')), findsNothing);
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
