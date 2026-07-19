import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wineerp_app/core/theme.dart';
import 'package:wineerp_app/data/scan_models.dart';
import 'package:wineerp_app/features/scan/scan_controller.dart';
import 'package:wineerp_app/features/scan/scan_screen.dart';

/// Story 2.5 — 스캔 결과 후보 수에 따른 분기(0 / 1 / 2+).
ScanResult _result(List<Map<String, dynamic>> products) =>
    ScanResult.fromJson({'code': 'C', 'products': products});

Map<String, dynamic> _product(
  String name,
  List<Map<String, dynamic>> vintages,
) => {
  'id': 'p-$name',
  'producer': '$name Estate',
  'model_name': name,
  'vintages': vintages,
};

Widget _app(ScanResult result) => ProviderScope(
      overrides: [
        cameraEnabledProvider.overrideWithValue(false),
        matchProvider.overrideWith((ref) => AsyncData(result)),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const ScanScreen()),
    );

void main() {
  testWidgets('후보 0개 → 미등록 안내 (신규 등록 유도)', (tester) async {
    await tester.pumpWidget(_app(_result([])));
    expect(find.text('미등록 와인'), findsOneWidget);
  });

  testWidgets('후보 1개 → 후보 목록 없이 확인 카드 직행', (tester) async {
    await tester.pumpWidget(_app(_result([
      _product('Grange', [
        {'id': 'v1', 'vintage': 2016},
      ]),
    ])));

    expect(find.text('빈티지 2016'), findsOneWidget);
    expect(find.byKey(const Key('candidate_not_listed')), findsNothing);
  });

  testWidgets('후보 2개 → 확인 카드 대신 후보 목록', (tester) async {
    await tester.pumpWidget(_app(_result([
      _product('Margaux', [
        {'id': 'v18', 'vintage': 2018},
        {'id': 'v15', 'vintage': 2015},
      ]),
    ])));

    expect(find.byKey(const Key('candidate_v18')), findsOneWidget);
    // 선택 전에는 확인 카드가 보이지 않는다.
    expect(find.textContaining('빈티지 20'), findsNothing);
  });

  testWidgets('제품이 여럿이면(공유 바코드) 빈티지가 각 1개여도 후보 목록', (tester) async {
    // 제품 수가 아니라 (제품×빈티지) 개수로 분기해야 한다.
    await tester.pumpWidget(_app(_result([
      _product('Monte Bello', [
        {'id': 'a', 'vintage': 2019},
      ]),
      _product('Geyserville', [
        {'id': 'b', 'vintage': 2020},
      ]),
    ])));

    expect(find.byKey(const Key('candidate_a')), findsOneWidget);
    expect(find.byKey(const Key('candidate_b')), findsOneWidget);
  });

  testWidgets('후보 선택 → 확인 카드로 이어지고 다시 선택으로 되돌아간다', (tester) async {
    await tester.pumpWidget(_app(_result([
      _product('Margaux', [
        {'id': 'v18', 'vintage': 2018},
        {'id': 'v15', 'vintage': 2015},
      ]),
    ])));

    await tester.tap(find.byKey(const Key('candidate_v15')));
    await tester.pumpAndSettle();
    expect(find.text('빈티지 2015'), findsOneWidget);

    await tester.tap(find.byKey(const Key('reselect_candidate')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('candidate_v18')), findsOneWidget);
    expect(find.text('빈티지 2015'), findsNothing);
  });

  testWidgets('"찾는 빈티지가 없어요" → 신규 등록 안내로 전환', (tester) async {
    await tester.pumpWidget(_app(_result([
      _product('Margaux', [
        {'id': 'v18', 'vintage': 2018},
        {'id': 'v15', 'vintage': 2015},
      ]),
    ])));

    await tester.tap(find.byKey(const Key('candidate_not_listed')));
    await tester.pumpAndSettle();
    expect(find.text('미등록 와인'), findsOneWidget);
  });

  testWidgets('NV만 있는 제품은 후보 1개로 확인 카드 직행', (tester) async {
    await tester.pumpWidget(_app(_result([
      _product('Impérial Brut', [
        {'id': 'nv', 'vintage': null},
      ]),
    ])));

    expect(find.text('빈티지 NV'), findsOneWidget);
  });
}
