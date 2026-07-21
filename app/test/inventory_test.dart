import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wineerp_app/core/theme.dart';
import 'package:wineerp_app/data/inventory_repository.dart';
import 'package:wineerp_app/features/inventory/inventory_screen.dart';

/// Story 6.2 — 재고 목록 (UX-DR3 재고 탭).
class _FakeInventoryRepo extends InventoryRepository {
  _FakeInventoryRepo({this.items = const [], this.fail = false, this.delay})
      : super(Dio());

  final List<InventoryItem> items;
  final bool fail;
  final Duration? delay;
  int calls = 0;

  @override
  Future<List<InventoryItem>> list() async {
    calls++;
    if (delay != null) await Future<void>.delayed(delay!);
    if (fail) throw Exception('boom');
    return items;
  }
}

InventoryItem _item({
  String model = 'Grange',
  String producer = 'Penfolds',
  int? vintage = 2016,
  int stock = 12,
  String vintageId = 'v1',
  String? imageKey,
}) =>
    InventoryItem(
      wineProductId: 'p1',
      producer: producer,
      modelName: model,
      vintageId: vintageId,
      vintage: vintage,
      stock: stock,
      representativeImageKey: imageKey,
    );

ProviderContainer _container(_FakeInventoryRepo repo) {
  final c = ProviderContainer(
    overrides: [inventoryRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(c.dispose);
  return c;
}

Widget _host(ProviderContainer c) => UncontrolledProviderScope(
      container: c,
      child: MaterialApp(theme: AppTheme.light, home: const InventoryScreen()),
    );

void main() {
  testWidgets('로딩 중에는 스피너를 보여준다', (tester) async {
    final repo = _FakeInventoryRepo(delay: const Duration(milliseconds: 200));
    await tester.pumpWidget(_host(_container(repo)));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('비어 있으면 빈 상태 안내가 뜬다', (tester) async {
    await tester.pumpWidget(_host(_container(_FakeInventoryRepo())));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('inventory_empty')), findsOneWidget);
    expect(find.textContaining('스캔 탭'), findsOneWidget);
  });

  testWidgets('실패하면 오류 상태를 보여준다', (tester) async {
    await tester.pumpWidget(_host(_container(_FakeInventoryRepo(fail: true))));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('inventory_error')), findsOneWidget);
  });

  testWidgets('행에 모델명·생산자·빈티지·현재고가 표시된다', (tester) async {
    await tester.pumpWidget(_host(_container(
      _FakeInventoryRepo(items: [_item()]),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Grange'), findsOneWidget);
    expect(find.textContaining('Penfolds'), findsOneWidget);
    expect(find.textContaining('2016'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('NV는 연도 대신 NV로 표기된다', (tester) async {
    await tester.pumpWidget(_host(_container(
      _FakeInventoryRepo(items: [_item(vintage: null)]),
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining('NV'), findsOneWidget);
  });

  testWidgets('재고 0인 와인도 목록에 남는다', (tester) async {
    // 숨기면 등록됐는데 안 보이는 "왜 없지"가 된다.
    await tester.pumpWidget(_host(_container(
      _FakeInventoryRepo(items: [
        _item(model: 'Untouched', vintageId: 'v0', stock: 0),
        _item(model: 'Grange', vintageId: 'v1', stock: 12),
      ]),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Untouched'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.byKey(const Key('stock_count')), findsNWidgets(2));
  });

  testWidgets('새로고침 버튼은 재고를 다시 조회한다', (tester) async {
    final repo = _FakeInventoryRepo(items: [_item()]);
    await tester.pumpWidget(_host(_container(repo)));
    await tester.pumpAndSettle();
    expect(repo.calls, 1);

    await tester.tap(find.byKey(const Key('inventory_refresh')));
    await tester.pumpAndSettle();
    expect(repo.calls, 2);
  });

  testWidgets('리비전이 오르면(입고·등록 후) 재고를 다시 조회한다', (tester) async {
    // 입고 컨트롤러가 bumpInventory로 올리는 그 리비전이다. 재고가 stale로
    // 남지 않도록 inventoryProvider가 리비전을 watch하는지 고정한다.
    final repo = _FakeInventoryRepo(items: [_item()]);
    final c = _container(repo);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();
    expect(repo.calls, 1);

    c.read(inventoryRevisionProvider.notifier).state++;
    await tester.pumpAndSettle();
    expect(repo.calls, 2);
  });

  testWidgets('큰 글꼴(3x)에서도 재고 행이 오버플로하지 않는다', (tester) async {
    // 과거 확인 카드가 200% 글꼴에서 조용히 클리핑된 전례가 있다. 긴 모델명 + 3자리
    // 재고를 3배 배율로 렌더해 RenderFlex 오버플로가 안 나는지 고정한다.
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final c = _container(_FakeInventoryRepo(items: [
      _item(
        model: '아주 긴 와인 모델명이 줄바꿈되어야 하는 경우 Château Very Long',
        producer: 'Some Long Producer Name',
        stock: 999,
      ),
    ]));
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        theme: AppTheme.light,
        home: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(3.0)),
          child: InventoryScreen(),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
