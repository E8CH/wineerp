import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wineerp_app/features/scan/scan_controller.dart';
import 'package:wineerp_app/features/scan/stability_gate.dart';
import 'package:wineerp_app/features/scan/widgets/scanner_frame.dart';

void main() {
  group('ScanController 디바운스', () {
    test('새 코드는 수용, 같은 코드 연속은 무시', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ctrl = container.read(scanControllerProvider.notifier);

      expect(ctrl.onDetected('8801234567890'), isTrue);
      expect(container.read(scanControllerProvider).lastCode, '8801234567890');
      expect(ctrl.onDetected('8801234567890'), isFalse); // 연속 중복
      expect(ctrl.onDetected(''), isFalse); // 빈 값
      expect(ctrl.onDetected('3760000000015'), isTrue); // 다른 코드
    });

    test('reset 후 같은 코드 재수용', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ctrl = container.read(scanControllerProvider.notifier);
      ctrl.onDetected('X');
      ctrl.reset();
      expect(container.read(scanControllerProvider).lastCode, isNull);
      expect(ctrl.onDetected('X'), isTrue);
    });
  });

  group('StabilityGate 안정 인식', () {
    test('임계 2: 첫 관측은 미확정, 연속 두 번째에 확정', () {
      final g = StabilityGate(threshold: 2);
      expect(g.observe('A'), isFalse);
      expect(g.observe('A'), isTrue);
    });

    test('확정 후에는 같은 코드가 계속 와도 재확정하지 않는다', () {
      // 없으면 홀드된 뒤에도 매 프레임 확정이 재발화해 재매칭이 폭주한다.
      final g = StabilityGate(threshold: 2);
      g.observe('A');
      expect(g.observe('A'), isTrue);
      expect(g.observe('A'), isFalse);
      expect(g.observe('A'), isFalse);
    });

    test('중간에 다른 코드가 끼면 카운트가 처음부터다', () {
      // 옆 병 바코드가 한 프레임 스쳐도 안정으로 오인해선 안 된다.
      final g = StabilityGate(threshold: 2);
      expect(g.observe('A'), isFalse); // A:1
      expect(g.observe('B'), isFalse); // B:1 — A 카운트 버림
      expect(g.observe('A'), isFalse); // A:1 다시 처음
      expect(g.observe('A'), isTrue); // A:2 확정
    });

    test('빈 코드는 카운트되지 않는다', () {
      final g = StabilityGate(threshold: 2);
      expect(g.observe(''), isFalse);
      expect(g.observe('A'), isFalse);
      expect(g.observe('A'), isTrue);
    });

    test('reset 후 재무장 — 같은 코드 재확정 가능(다음 병)', () {
      final g = StabilityGate(threshold: 2);
      g.observe('A');
      g.observe('A'); // 확정
      g.reset();
      expect(g.observe('A'), isFalse);
      expect(g.observe('A'), isTrue);
    });

    test('임계 1은 첫 관측에 즉시 확정', () {
      final g = StabilityGate(threshold: 1);
      expect(g.observe('A'), isTrue);
      expect(g.observe('A'), isFalse); // 재확정 없음
    });
  });

  testWidgets('ScannerFrame 렌더', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ScannerFrame())),
    );
    expect(find.byType(ScannerFrame), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
