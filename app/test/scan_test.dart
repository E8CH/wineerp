import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wineerp_app/features/scan/scan_controller.dart';
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

  testWidgets('ScannerFrame 렌더', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ScannerFrame())),
    );
    expect(find.byType(ScannerFrame), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
