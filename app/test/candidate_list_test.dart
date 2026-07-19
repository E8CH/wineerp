import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wineerp_app/core/theme.dart';
import 'package:wineerp_app/data/scan_models.dart';
import 'package:wineerp_app/features/receiving/widgets/candidate_list.dart';

/// Story 2.5 — CandidateList (UX-DR7).
ScanResult _margaux() => ScanResult.fromJson({
      'code': '3760000000015',
      'products': [
        {
          'id': 'p1',
          'producer': 'Château Margaux',
          'model_name': 'Château Margaux',
          'vintages': [
            {'id': 'v18', 'vintage': 2018},
            {'id': 'v15', 'vintage': 2015},
            {'id': 'nv', 'vintage': null},
          ],
        },
      ],
    });

Widget _host({
  required List<VintageCandidate> candidates,
  String? selectedId,
  ValueChanged<VintageCandidate>? onSelect,
  VoidCallback? onNotListed,
}) =>
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: CandidateList(
          candidates: candidates,
          selectedId: selectedId,
          onSelect: onSelect ?? (_) {},
          onNotListed: onNotListed ?? () {},
        ),
      ),
    );

void main() {
  testWidgets('후보를 서버 순서대로 렌더하고 NV를 정상 표기한다', (tester) async {
    await tester.pumpWidget(_host(candidates: _margaux().candidates));

    expect(find.text('2018'), findsOneWidget);
    expect(find.text('2015'), findsOneWidget);
    expect(find.text('NV'), findsOneWidget);
    expect(find.byKey(const Key('candidate_v18')), findsOneWidget);
  });

  testWidgets('한 탭으로 후보를 선택한다', (tester) async {
    VintageCandidate? picked;
    await tester.pumpWidget(_host(
      candidates: _margaux().candidates,
      onSelect: (c) => picked = c,
    ));

    await tester.tap(find.byKey(const Key('candidate_v15')));
    await tester.pump();

    expect(picked, isNotNull);
    expect(picked!.year, 2015);
  });

  testWidgets('선택 상태를 색만이 아니라 아이콘·텍스트로도 표시한다', (tester) async {
    await tester.pumpWidget(
      _host(candidates: _margaux().candidates, selectedId: 'v18'),
    );

    // WCAG — 색 단독 전달 금지
    expect(find.text('선택됨'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('"찾는 빈티지가 없어요" 탈출구를 제공한다', (tester) async {
    var escaped = false;
    await tester.pumpWidget(_host(
      candidates: _margaux().candidates,
      onNotListed: () => escaped = true,
    ));

    final escape = find.byKey(const Key('candidate_not_listed'));
    expect(escape, findsOneWidget);
    await tester.tap(escape);
    await tester.pump();
    expect(escaped, isTrue);
  });

  testWidgets('모든 후보 행이 터치 타깃 48dp 이상이다', (tester) async {
    await tester.pumpWidget(_host(candidates: _margaux().candidates));

    for (final key in ['candidate_v18', 'candidate_v15', 'candidate_nv']) {
      final size = tester.getSize(find.byKey(Key(key)));
      expect(size.height, greaterThanOrEqualTo(48.0), reason: key);
    }
  });

  testWidgets('빈티지 미등록 제품은 표시하되 선택되지 않는다', (tester) async {
    final orphan = ScanResult.fromJson({
      'code': 'X',
      'products': [
        {'id': 'p9', 'producer': 'Orphan', 'model_name': 'Orphan', 'vintages': []},
      ],
    });
    var picked = false;
    await tester.pumpWidget(_host(
      candidates: orphan.candidates,
      onSelect: (_) => picked = true,
    ));

    expect(find.text('빈티지 미등록'), findsOneWidget);
    await tester.tap(find.byKey(const Key('candidate_product:p9')));
    await tester.pump();
    expect(picked, isFalse);
  });

  testWidgets('최소 폭 280dp에서 가로 오버플로가 없다', (tester) async {
    tester.view.physicalSize = const Size(280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(candidates: _margaux().candidates));
    expect(tester.takeException(), isNull);
  });
}
