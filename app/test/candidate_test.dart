import 'package:flutter_test/flutter_test.dart';
import 'package:wineerp_app/data/scan_models.dart';

/// Story 2.5 — 후보 평탄화. 스캔 결과를 (product, vintage) 쌍으로 펼친다.
ScanResult _result(List<Map<String, dynamic>> products) =>
    ScanResult.fromJson({'code': 'X', 'products': products});

Map<String, dynamic> _product(
  String name, {
  List<Map<String, dynamic>> vintages = const [],
}) => {
  'id': 'p-$name',
  'producer': '$name Estate',
  'model_name': name,
  'vintages': vintages,
};

Map<String, dynamic> _vintage(String id, int? year) => {
  'id': id,
  'vintage': year,
};

void main() {
  test('미매칭 → 후보 0개', () {
    expect(_result([]).candidates, isEmpty);
  });

  test('단일 제품·단일 빈티지 → 후보 1개', () {
    final c = _result([
      _product('Grange', vintages: [_vintage('v1', 2016)]),
    ]).candidates;
    expect(c.length, 1);
    expect(c.single.year, 2016);
    expect(c.single.id, 'v1');
  });

  test('단일 제품·복수 빈티지 → 후보 2개 (서버 순서 보존)', () {
    final c = _result([
      _product('Margaux', vintages: [_vintage('v18', 2018), _vintage('v15', 2015)]),
    ]).candidates;
    expect(c.map((e) => e.year).toList(), [2018, 2015]);
    // 서버가 이미 정렬 계약을 지킴 — 프론트에서 재정렬하지 않는다.
  });

  test('복수 제품(공유 바코드) → 각 제품의 빈티지가 모두 후보', () {
    final c = _result([
      _product('Monte Bello', vintages: [_vintage('a', 2019)]),
      _product('Geyserville', vintages: [_vintage('b', 2020), _vintage('c', 2018)]),
    ]).candidates;
    expect(c.length, 3);
    expect(c.map((e) => e.product.modelName).toList(),
        ['Monte Bello', 'Geyserville', 'Geyserville']);
  });

  test('NV(vintage=null)도 정상 후보이며 라벨은 NV', () {
    final c = _result([
      _product('Impérial Brut', vintages: [_vintage('nv', null)]),
    ]).candidates;
    expect(c.single.vintageLabel, 'NV');
    expect(c.single.isSelectable, isTrue);
  });

  test('빈티지가 0개인 제품도 후보로 남되 선택 불가', () {
    // 후보에서 빠지면 스캔 결과가 조용히 사라진다.
    final c = _result([_product('Orphan')]).candidates;
    expect(c.length, 1);
    expect(c.single.isSelectable, isFalse);
    expect(c.single.vintageLabel, '빈티지 미등록');
  });

  test('후보 id는 빈티지 id 기준 (WineVintageRead에 == 없음)', () {
    final c = _result([
      _product('Margaux', vintages: [_vintage('v18', 2018), _vintage('v15', 2015)]),
    ]).candidates;
    expect(c.map((e) => e.id).toSet().length, 2);
  });
}
