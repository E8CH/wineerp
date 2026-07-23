import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wineerp_app/core/theme.dart';
import 'package:wineerp_app/data/wine_catalog_repository.dart';
import 'package:wineerp_app/features/auth/auth_controller.dart';
import 'package:wineerp_app/features/catalog/catalog_screen.dart';

/// Story 7.x — 모델 카탈로그(목록·상세·수정·삭제).
class _FakeCatalogRepo extends WineCatalogRepository {
  _FakeCatalogRepo({this.items = const [], this.fail = false}) : super(Dio());

  final List<ProductCatalogItem> items;
  final bool fail;
  final List<String> deleted = [];
  final List<Map<String, dynamic>> updates = [];

  @override
  Future<List<ProductCatalogItem>> list() async {
    if (fail) throw Exception('boom');
    return items;
  }

  @override
  Future<ProductCatalogItem> update(
    String productId, {
    required String producer,
    required String modelName,
    String? region,
    String? country,
    String? grape,
  }) async {
    updates.add({'id': productId, 'producer': producer, 'model_name': modelName});
    return _item(id: productId, model: modelName, producer: producer);
  }

  @override
  Future<void> delete(String productId) async {
    deleted.add(productId);
  }
}

class _RoleController extends AuthController {
  _RoleController(this._role);
  final String _role;
  @override
  AuthState build() => AuthState(token: 't', email: 'u@w.co', role: _role);
}

ProductCatalogItem _item({
  String id = 'p1',
  String model = 'Grange',
  String producer = 'Penfolds',
  String? region = 'Barossa',
  String? country = '호주',
  String? grape = 'Shiraz',
  int totalStock = 12,
  DateTime? createdAt,
}) =>
    ProductCatalogItem(
      productId: id,
      producer: producer,
      modelName: model,
      region: region,
      country: country,
      grape: grape,
      totalStock: totalStock,
      createdAt: createdAt ?? DateTime(2026, 7, 23),
      vintages: [
        VintageStock(vintageId: '${id}v1', vintage: 2016, stock: totalStock),
      ],
    );

ProviderContainer _container(_FakeCatalogRepo repo, {String role = 'staff'}) {
  final c = ProviderContainer(overrides: [
    wineCatalogRepositoryProvider.overrideWithValue(repo),
    authControllerProvider.overrideWith(() => _RoleController(role)),
  ]);
  addTearDown(c.dispose);
  return c;
}

Widget _host(ProviderContainer c) => UncontrolledProviderScope(
      container: c,
      child: MaterialApp(theme: AppTheme.light, home: const CatalogScreen()),
    );

void main() {
  testWidgets('카드에 모델명·생산자·명세·재고 요약이 뜬다', (tester) async {
    await tester.pumpWidget(_host(_container(_FakeCatalogRepo(items: [_item()]))));
    await tester.pumpAndSettle();

    expect(find.text('Grange'), findsOneWidget);
    expect(find.text('Penfolds'), findsOneWidget);
    expect(find.textContaining('Barossa'), findsOneWidget);
    expect(find.textContaining('재고 12병'), findsOneWidget);
  });

  testWidgets('카드에 등록 날짜가 표시된다', (tester) async {
    await tester.pumpWidget(_host(_container(
      _FakeCatalogRepo(items: [_item(createdAt: DateTime(2026, 7, 23))]),
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining('등록 2026.7.23'), findsOneWidget);
  });

  testWidgets('검색어로 모델명·생산자를 거른다', (tester) async {
    await tester.pumpWidget(_host(_container(_FakeCatalogRepo(items: [
      _item(id: 'a', model: 'Grange', producer: 'Penfolds'),
      _item(id: 'b', model: 'Opus One', producer: 'Mondavi'),
    ]))));
    await tester.pumpAndSettle();
    expect(find.text('Grange'), findsOneWidget);
    expect(find.text('Opus One'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('catalog_search')), 'opus');
    await tester.pumpAndSettle();

    expect(find.text('Opus One'), findsOneWidget);
    expect(find.text('Grange'), findsNothing);
  });

  testWidgets('검색 결과가 없으면 빈 카탈로그와 구분되는 안내가 뜬다', (tester) async {
    await tester.pumpWidget(_host(_container(
      _FakeCatalogRepo(items: [_item(model: 'Grange')]),
    )));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('catalog_search')), 'zzz없음');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('catalog_no_results')), findsOneWidget);
    expect(find.byKey(const Key('catalog_empty')), findsNothing);
  });

  testWidgets('등록일 필터 진입점이 있다', (tester) async {
    await tester.pumpWidget(_host(_container(_FakeCatalogRepo(items: [_item()]))));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('catalog_date_filter')), findsOneWidget);
  });

  group('filterCatalog (순수 로직)', () {
    final old = _item(id: 'old', model: 'Old One', createdAt: DateTime(2020, 1, 1));
    final recent =
        _item(id: 'new', model: 'New One', createdAt: DateTime(2026, 7, 23));

    test('빈 검색·필터는 전부 통과', () {
      final r = filterCatalog([old, recent], query: '');
      expect(r.length, 2);
    });

    test('텍스트는 모델명/생산자/지역을 소문자 부분일치', () {
      expect(filterCatalog([old, recent], query: 'new').single.modelName,
          'New One');
      expect(filterCatalog([old, recent], query: 'penfolds').length, 2);
      expect(filterCatalog([old, recent], query: 'barossa').length, 2);
    });

    test('등록일 범위는 양끝 포함으로 거른다', () {
      final range = DateTimeRange(
        start: DateTime(2026, 7, 1),
        end: DateTime(2026, 7, 23), // 종료일 당일 등록분도 포함돼야 한다
      );
      final r = filterCatalog([old, recent], query: '', dateRange: range);
      expect(r.single.modelName, 'New One'); // 2020년 건은 제외
    });

    test('종료일 당일 등록분이 빠지지 않는다(날짜 비교)', () {
      // 시각으로 잘랐다면 2026-07-23 00:00 이후 등록분이 종료일 자정에 걸려 빠진다.
      final sameDay = DateTimeRange(
        start: DateTime(2026, 7, 23),
        end: DateTime(2026, 7, 23),
      );
      expect(
        filterCatalog([recent], query: '', dateRange: sameDay).length,
        1,
      );
    });
  });

  testWidgets('비어 있으면 빈 상태 안내가 뜬다', (tester) async {
    await tester.pumpWidget(_host(_container(_FakeCatalogRepo())));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('catalog_empty')), findsOneWidget);
  });

  testWidgets('실패하면 오류 상태를 보여준다', (tester) async {
    await tester.pumpWidget(_host(_container(_FakeCatalogRepo(fail: true))));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('catalog_error')), findsOneWidget);
  });

  testWidgets('카드를 탭하면 상세 시트가 뜬다(사진 자리 + 정보)', (tester) async {
    await tester.pumpWidget(_host(_container(_FakeCatalogRepo(items: [_item()]))));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Grange'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('catalog_detail_photo')), findsOneWidget);
    expect(find.text('지역'), findsOneWidget);
    expect(find.text('Barossa'), findsOneWidget);
    expect(find.text('품종'), findsOneWidget);
  });

  testWidgets('staff에게는 수정·삭제가 보이지 않는다', (tester) async {
    await tester.pumpWidget(
      _host(_container(_FakeCatalogRepo(items: [_item()]), role: 'staff')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grange'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('catalog_edit')), findsNothing);
    expect(find.byKey(const Key('catalog_delete')), findsNothing);
  });

  testWidgets('manager에게는 수정·삭제가 보인다', (tester) async {
    await tester.pumpWidget(
      _host(_container(_FakeCatalogRepo(items: [_item()]), role: 'manager')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grange'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('catalog_edit')), findsOneWidget);
    expect(find.byKey(const Key('catalog_delete')), findsOneWidget);
  });

  testWidgets('삭제는 경고창을 띄우고, 확인해야 실제로 삭제한다', (tester) async {
    final repo = _FakeCatalogRepo(items: [_item()]);
    await tester.pumpWidget(_host(_container(repo, role: 'manager')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grange'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('catalog_delete')));
    await tester.tap(find.byKey(const Key('catalog_delete')));
    await tester.pumpAndSettle();

    // 경고창이 떴고, 아직 삭제되지 않았다.
    expect(find.byKey(const Key('delete_warning_dialog')), findsOneWidget);
    expect(repo.deleted, isEmpty);

    await tester.tap(find.byKey(const Key('delete_confirm')));
    await tester.pumpAndSettle();
    expect(repo.deleted, ['p1']);
  });

  testWidgets('삭제 경고에서 취소하면 삭제하지 않는다', (tester) async {
    final repo = _FakeCatalogRepo(items: [_item()]);
    await tester.pumpWidget(_host(_container(repo, role: 'manager')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grange'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('catalog_delete')));
    await tester.tap(find.byKey(const Key('catalog_delete')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(repo.deleted, isEmpty);
  });

  testWidgets('수정 시트에서 저장하면 update가 호출된다', (tester) async {
    final repo = _FakeCatalogRepo(items: [_item()]);
    await tester.pumpWidget(_host(_container(repo, role: 'manager')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grange'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('catalog_edit')));
    await tester.tap(find.byKey(const Key('catalog_edit')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('edit_model_name')), 'Grange 수정');
    await tester.pump();
    await tester.tap(find.byKey(const Key('edit_save')));
    await tester.pumpAndSettle();

    expect(repo.updates.single['model_name'], 'Grange 수정');
  });
}
