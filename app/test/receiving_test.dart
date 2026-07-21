import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wineerp_app/core/theme.dart';
import 'package:wineerp_app/data/inventory_repository.dart';
import 'package:wineerp_app/data/receiving_repository.dart';
import 'package:wineerp_app/data/scan_models.dart';
import 'package:wineerp_app/features/receiving/receiving_controller.dart';
import 'package:wineerp_app/features/receiving/widgets/quantity_stepper.dart';
import 'package:wineerp_app/features/receiving/widgets/receiving_panel.dart';
import 'package:wineerp_app/features/scan/scan_controller.dart';

/// Story 2.6 — 수량 지정 & 입고 완료.
class _FakeReceivingRepo extends ReceivingRepository {
  _FakeReceivingRepo({
    this.fail = false,
    this.delay = Duration.zero,
    this.statusCode,
  }) : super(Dio());

  final bool fail;
  final int? statusCode;
  final Duration delay;
  int calls = 0;
  final List<String?> keysSeen = [];
  final List<String?> memosSeen = [];

  @override
  Future<String?> create({
    required String wineVintageId,
    required int quantity,
    String? memo,
    String? idempotencyKey,
  }) async {
    calls++;
    keysSeen.add(idempotencyKey);
    memosSeen.add(memo);
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (fail) {
      // 실제 실패는 DioException으로 온다. 일반 Exception을 던지면 컨트롤러가
      // 의도대로 되던지므로(프로그래밍 오류를 숨기지 않기 위해) fake도 현실을 따른다.
      final req = RequestOptions(path: '/receiving');
      throw DioException(
        requestOptions: req,
        type: statusCode == null
            ? DioExceptionType.connectionError
            : DioExceptionType.badResponse,
        response: statusCode == null
            ? null
            : Response<dynamic>(requestOptions: req, statusCode: statusCode),
      );
    }
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

    testWidgets('[완료] 연타로 중복 입고되지 않는다 (같은 프레임)', (tester) async {
      // ⚠️ 탭 사이에 pump()를 넣으면 안 된다. 리빌드가 일어나 두 번째 탭 시점엔
      // 이미 버튼이 비활성이므로, UI 비활성만 검증하고 컨트롤러 가드는 한 번도
      // 실행되지 않는다. 실제 연타는 리빌드 전 같은 프레임에 도달한다.
      final repo = _FakeReceivingRepo(delay: const Duration(milliseconds: 300));
      await tester.pumpWidget(_host(_container(repo)));

      final btn = find.byKey(const Key('receiving_complete'));
      await tester.tap(btn);
      await tester.tap(btn, warnIfMissed: false);
      await tester.tap(btn, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 3));

      expect(repo.calls, 1, reason: '중복 입고는 재고를 조용히 부풀린다');
    });

    testWidgets('컨트롤러 재진입 가드 단독 검증', (tester) async {
      // UI 비활성을 우회해 가드만 격리 검증한다. 위젯을 거치지 않으므로
      // 버튼 비활성을 지워도 이 테스트는 계속 결함을 잡는다.
      final repo = _FakeReceivingRepo(delay: const Duration(milliseconds: 200));
      final c = _container(repo);
      final ctrl = c.read(receivingControllerProvider.notifier);

      final futures = [ctrl.submit('v1'), ctrl.submit('v1'), ctrl.submit('v1')];
      await tester.pump(const Duration(milliseconds: 300));
      await Future.wait(futures);

      expect(repo.calls, 1);
    });

    test('스캔 대상이 바뀌면 이전 수량이 따라가지 않는다', () async {
      // 확인 패널이 떠 있는 동안 카메라는 계속 살아 있다. 와인 A에 12를 찍어둔 채
      // 와인 B가 프레임에 들어오면, 리셋하지 않을 경우 B가 12병으로 기록된다.
      final c = _container(_FakeReceivingRepo());
      final ctrl = c.read(receivingControllerProvider.notifier);
      ctrl.setQuantity(12);
      expect(c.read(receivingControllerProvider).quantity, 12);

      c.invalidate(receivingControllerProvider); // ScanScreen._match이 하는 일
      await Future<void>.delayed(Duration.zero);
      expect(c.read(receivingControllerProvider).quantity, 1,
          reason: '다른 와인에 이전 수량이 새면 조용한 오기록이 된다');
    });

    testWidgets('재시도는 같은 멱등 키를 재사용한다', (tester) async {
      // 재시도마다 키가 바뀌면 서버가 중복을 구분하지 못해 멱등성이 통째로 무력해진다.
      final repo = _FakeReceivingRepo(fail: true);
      final c = _container(repo);
      final ctrl = c.read(receivingControllerProvider.notifier);

      await ctrl.submit('v1');
      await ctrl.submit('v1');

      expect(repo.keysSeen.length, 2);
      expect(repo.keysSeen[0], isNotNull);
      expect(repo.keysSeen[0], repo.keysSeen[1], reason: '실패 후 재시도는 같은 병이다');
    });

    testWidgets('입고 성공 후에는 새 멱등 키가 발급된다', (tester) async {
      // 다음 병까지 같은 키를 쓰면 서버가 두 번째 입고를 '재생'으로 보고 삼킨다.
      final repo = _FakeReceivingRepo();
      final c = _container(repo);
      final ctrl = c.read(receivingControllerProvider.notifier);

      await ctrl.submit('v1');
      await ctrl.submit('v1');

      expect(repo.keysSeen.length, 2);
      expect(repo.keysSeen[0], isNot(repo.keysSeen[1]));
    });

    testWidgets('입고 성공 시 재고 리비전을 올린다(재고 탭 갱신)', (tester) async {
      // 이 배선이 stale 재고를 막는 전부다. bumpInventory(ref)를 지우면 이 단언만
      // 깨지고 나머지는 전부 초록으로 남는다(입고 후 재고 탭이 조용히 옛 수량을 보임).
      final c = _container(_FakeReceivingRepo());
      expect(c.read(inventoryRevisionProvider), 0);

      final ok = await c.read(receivingControllerProvider.notifier).submit('v1');

      expect(ok, isTrue);
      expect(c.read(inventoryRevisionProvider), 1);
    });

    testWidgets('입고 실패 시에는 재고 리비전을 올리지 않는다', (tester) async {
      // 성공 경로에만 붙어야 한다 — 실패에도 올리면 재고 탭이 헛되이 다시 조회한다.
      final c = _container(_FakeReceivingRepo(fail: true, statusCode: 400));
      await c.read(receivingControllerProvider.notifier).submit('v1');
      expect(c.read(inventoryRevisionProvider), 0);
    });

    testWidgets('401은 재시도가 아니라 재로그인을 안내한다', (tester) async {
      // "다시 시도하세요"를 무조건 띄우면 만료 토큰으로 영원히 재시도하게 된다.
      await tester.pumpWidget(
        _host(_container(_FakeReceivingRepo(fail: true, statusCode: 401))),
      );
      await tester.tap(find.byKey(const Key('receiving_complete')));
      await tester.pump();
      await tester.pump();
      expect(find.text('로그인이 만료되었습니다 · 다시 로그인하세요'), findsOneWidget);
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

      expect(find.text('입고 저장 실패 · 네트워크 확인 후 다시 시도하세요'),
          findsOneWidget);
      expect(c.read(receivingControllerProvider).quantity, 3, reason: '다시 세게 하지 않는다');
      expect(c.read(selectedCandidateProvider), 'v1', reason: '선택 유지');
    });

    testWidgets('메모는 기본으로 접혀 있다 (3탭 리듬 보호)', (tester) async {
      // 상시 노출하면 100병 처리 시 100번 지나쳐야 한다(NFR3).
      await tester.pumpWidget(_host(_container(_FakeReceivingRepo())));
      expect(find.byKey(const Key('memo_toggle')), findsOneWidget);
      expect(find.byKey(const Key('memo_field')), findsNothing);
    });

    testWidgets('메모를 펼쳐 입력하면 함께 전송된다', (tester) async {
      final repo = _FakeReceivingRepo();
      await tester.pumpWidget(_host(_container(repo)));

      await tester.tap(find.byKey(const Key('memo_toggle')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('memo_field')), '코르크 손상');
      await tester.pump();
      await tester.tap(find.byKey(const Key('receiving_complete')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));

      expect(repo.memosSeen.single, '코르크 손상');
    });

    testWidgets('메모를 안 쓰면 null로 전송된다', (tester) async {
      final repo = _FakeReceivingRepo();
      await tester.pumpWidget(_host(_container(repo)));
      await tester.tap(find.byKey(const Key('receiving_complete')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(repo.memosSeen.single, isNull);
    });
  });
}
