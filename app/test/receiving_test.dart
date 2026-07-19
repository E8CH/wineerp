import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wineerp_app/core/theme.dart';
import 'package:wineerp_app/data/receiving_repository.dart';
import 'package:wineerp_app/data/scan_models.dart';
import 'package:wineerp_app/features/receiving/receiving_controller.dart';
import 'package:wineerp_app/features/receiving/widgets/quantity_stepper.dart';
import 'package:wineerp_app/features/receiving/widgets/receiving_panel.dart';
import 'package:wineerp_app/features/scan/scan_controller.dart';

/// Story 2.6 — 수량 지정 & 입고 완료.
class _FakeReceivingRepo extends ReceivingRepository {
  _FakeReceivingRepo({this.fail = false, this.delay = Duration.zero})
      : super(Dio());

  final bool fail;
  final Duration delay;
  int calls = 0;

  @override
  Future<String> create({
    required String wineVintageId,
    required int quantity,
    String? memo,
  }) async {
    calls++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (fail) throw Exception('network');
    return 'rec-1';
  }
}

VintageCandidate _candidate() => ScanResult.fromJson({
      'code': 'C',
      'products': [
        {
          'id': 'p1',
          'producer': 'Penfolds',
          'model_name': 'Grange',
          'vintages': [
            {'id': 'v1', 'vintage': 2016, 'stock': 4},
          ],
        },
      ],
    }).candidates.single;

Widget _host(ProviderContainer container) => UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: ReceivingPanel(candidate: _candidate())),
      ),
    );

ProviderContainer _container(_FakeReceivingRepo repo) {
  final c = ProviderContainer(
    overrides: [receivingRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('QuantityStepper', () {
    testWidgets('1에서는 감소가 비활성이고 증가는 동작한다', (tester) async {
      var value = 1;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (ctx, setState) => QuantityStepper(
              quantity: value,
              onChanged: (v) => setState(() => value = v),
            ),
          ),
        ),
      ));

      final dec = tester.widget<IconButton>(
        find.descendant(
          of: find.byKey(const Key('quantity_decrease')),
          matching: find.byType(IconButton),
        ),
      );
      expect(dec.onPressed, isNull, reason: '0병 입고는 입고가 아니다');

      await tester.tap(find.byKey(const Key('quantity_increase')));
      await tester.pump();
      expect(value, 2);
    });
  });

  group('입고 완료', () {
    testWidgets('현재고 배지를 확인 카드에 표시한다', (tester) async {
      await tester.pumpWidget(_host(_container(_FakeReceivingRepo())));
      expect(find.text('현재고 4'), findsOneWidget);
    });

    testWidgets('완료 → 저장 1회 + 스캔 루프 3종 리셋', (tester) async {
      final repo = _FakeReceivingRepo();
      final c = _container(repo);
      // 스캔이 진행된 상태를 흉내낸다.
      c.read(selectedCandidateProvider.notifier).state = 'v1';
      c.read(scanControllerProvider.notifier).onDetected('BARCODE-1');

      await tester.pumpWidget(_host(c));
      await tester.tap(find.byKey(const Key('receiving_complete')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3)); // SnackBar 자동 해제까지

      expect(repo.calls, 1);
      expect(c.read(selectedCandidateProvider), isNull);
      expect(c.read(matchProvider).value, isNull);
    });

    testWidgets('완료 후 같은 바코드를 다시 스캔할 수 있다 (회귀)', (tester) async {
      // reset()을 빠뜨리면 디바운스가 같은 코드를 무시해 두 번째 병을 못 넣는다.
      final c = _container(_FakeReceivingRepo());
      final scan = c.read(scanControllerProvider.notifier);
      expect(scan.onDetected('SAME-CODE'), isTrue);
      expect(scan.onDetected('SAME-CODE'), isFalse, reason: '스캔 중 디바운스');

      await tester.pumpWidget(_host(c));
      await tester.tap(find.byKey(const Key('receiving_complete')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));

      expect(scan.onDetected('SAME-CODE'), isTrue,
          reason: '같은 와인 여러 병 입고는 가장 흔한 경우다');
    });

    testWidgets('[완료] 연타로 중복 입고되지 않는다', (tester) async {
      final repo = _FakeReceivingRepo(delay: const Duration(milliseconds: 300));
      await tester.pumpWidget(_host(_container(repo)));

      await tester.tap(find.byKey(const Key('receiving_complete')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('receiving_complete')));
      await tester.tap(find.byKey(const Key('receiving_complete')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 3));

      expect(repo.calls, 1, reason: '중복 입고는 재고를 조용히 부풀린다');
    });

    testWidgets('실패 시 스캔으로 돌아가지 않고 수량을 유지한다', (tester) async {
      final c = _container(_FakeReceivingRepo(fail: true));
      c.read(selectedCandidateProvider.notifier).state = 'v1';

      await tester.pumpWidget(_host(c));
      await tester.tap(find.byKey(const Key('quantity_increase')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('quantity_increase')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('receiving_complete')));
      await tester.pump();
      await tester.pump();

      expect(find.text('입고 저장 실패 · 다시 시도하세요'), findsOneWidget);
      expect(c.read(receivingControllerProvider).quantity, 3, reason: '다시 세게 하지 않는다');
      expect(c.read(selectedCandidateProvider), 'v1', reason: '선택 유지');
    });
  });
}
