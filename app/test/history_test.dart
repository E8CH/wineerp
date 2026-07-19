import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wineerp_app/core/theme.dart';
import 'package:wineerp_app/data/history_repository.dart';
import 'package:wineerp_app/features/receiving/history_screen.dart';
import 'package:wineerp_app/features/receiving/widgets/history_row.dart';

/// Story 4.1 — 입고 내역 조회 (FR9, UX-DR12).
class _FakeHistoryRepo extends HistoryRepository {
  _FakeHistoryRepo({this.items = const [], this.fail = false, this.delay})
      : super(Dio());

  final List<HistoryItem> items;
  final bool fail;
  final Duration? delay;
  final List<HistoryPeriod> requested = [];

  @override
  Future<List<HistoryItem>> list(HistoryPeriod period) async {
    requested.add(period);
    if (delay != null) await Future<void>.delayed(delay!);
    if (fail) throw Exception('boom');
    return items;
  }
}

HistoryItem _item({
  String id = 'r1',
  String model = 'Grange',
  int? vintage = 2016,
  int quantity = 3,
  String? memo,
  String? amendedBy,
  String source = 'receiving',
}) =>
    HistoryItem(
      id: id,
      producer: 'Penfolds',
      modelName: model,
      vintage: vintage,
      quantity: quantity,
      receivedAt: DateTime(2026, 7, 19, 14, 5),
      staffEmail: 'staff@wineerp.co',
      memo: memo,
      amendedBy: amendedBy,
      source: source,
    );

ProviderContainer _container(_FakeHistoryRepo repo) {
  final c = ProviderContainer(
    overrides: [historyRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(c.dispose);
  return c;
}

Widget _host(ProviderContainer c) => UncontrolledProviderScope(
      container: c,
      child: MaterialApp(theme: AppTheme.light, home: const HistoryScreen()),
    );

void main() {
  testWidgets('로딩 중에는 빈 화면이 아니라 스켈레톤을 보여준다', (tester) async {
    final repo = _FakeHistoryRepo(delay: const Duration(milliseconds: 200));
    await tester.pumpWidget(_host(_container(repo)));
    await tester.pump();

    expect(find.byKey(const Key('history_skeleton')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('기록이 없으면 빈 상태 안내가 뜬다', (tester) async {
    await tester.pumpWidget(_host(_container(_FakeHistoryRepo())));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('history_empty')), findsOneWidget);
    expect(find.textContaining('스캔 탭'), findsOneWidget);
  });

  testWidgets('행에 모델명·수량·시간이 표시된다', (tester) async {
    await tester.pumpWidget(_host(_container(
      _FakeHistoryRepo(items: [_item()]),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Grange'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.textContaining('7/19 14:05'), findsOneWidget);
  });

  testWidgets('NV는 연도 대신 NV로 표기된다', (tester) async {
    await tester.pumpWidget(_host(_container(
      _FakeHistoryRepo(items: [_item(vintage: null)]),
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining('NV'), findsOneWidget);
  });

  testWidgets('메모가 있으면 표시된다', (tester) async {
    await tester.pumpWidget(_host(_container(
      _FakeHistoryRepo(items: [_item(memo: '라벨 파손')]),
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('memo_text')), findsOneWidget);
    expect(find.text('라벨 파손'), findsOneWidget);
  });

  testWidgets('초기 세팅분은 라벨로 구분된다 (색 단독 금지)', (tester) async {
    // 구분하지 않으면 "세팅으로 넣은 10병"을 "오늘 입고된 10병"으로 읽는다.
    await tester.pumpWidget(_host(_container(
      _FakeHistoryRepo(items: [
        _item(id: 'a', source: 'initial_setup'),
        _item(id: 'b', model: 'Tignanello'),
      ]),
    )));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('setup_badge')), findsOneWidget);
    expect(find.byType(HistoryRow), findsNWidgets(2));
  });

  testWidgets('세그먼트를 바꾸면 해당 기간으로 다시 조회한다', (tester) async {
    final repo = _FakeHistoryRepo(items: [_item()]);
    await tester.pumpWidget(_host(_container(repo)));
    await tester.pumpAndSettle();
    expect(repo.requested, [HistoryPeriod.day]);

    await tester.tap(find.text('월간'));
    await tester.pumpAndSettle();
    expect(repo.requested.last, HistoryPeriod.month);
  });

  testWidgets('실패하면 오류 상태를 보여준다', (tester) async {
    await tester.pumpWidget(_host(_container(_FakeHistoryRepo(fail: true))));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('history_error')), findsOneWidget);
  });

  test('UTC 응답을 로컬 시각으로 변환한다', () {
    // 서버는 UTC ISO 8601을 준다(아키텍처 Format Patterns). 그대로 표시하면
    // 오전 입고가 전날 밤으로 보인다.
    final item = HistoryItem.fromJson({
      'id': 'x',
      'producer': 'P',
      'model_name': 'M',
      'vintage': 2020,
      'quantity': 1,
      'received_at': '2026-07-18T23:00:00Z',
      'staff_email': 's@w.co',
      'memo': null,
      'representative_image_key': null,
      'source': 'receiving',
    });
    expect(item.receivedAt.isUtc, isFalse);
    expect(
      item.receivedAt.toUtc(),
      DateTime.utc(2026, 7, 18, 23),
    );
  });

  testWidgets('수정된 기록은 누가 고쳤는지 표시한다', (tester) async {
    // 이게 없으면 최초 입고자 이름 옆에 남이 고친 수량이 뜬다(오귀속).
    await tester.pumpWidget(_host(_container(
      _FakeHistoryRepo(items: [_item(amendedBy: 'bob@wineerp.co')]),
    )));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('amended_badge')), findsOneWidget);
    expect(find.textContaining('수정됨 · bob'), findsOneWidget);
  });

  testWidgets('수정되지 않은 기록에는 배지가 없다', (tester) async {
    await tester.pumpWidget(_host(_container(
      _FakeHistoryRepo(items: [_item()]),
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('amended_badge')), findsNothing);
  });
}
