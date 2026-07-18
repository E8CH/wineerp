import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wineerp_app/features/scan/scan_controller.dart';
import 'package:wineerp_app/main.dart';

/// 앱-셸 테스트는 카메라(플랫폼 채널)를 우회하도록 cameraEnabled=false로 override.
Widget _app() => ProviderScope(
      overrides: [cameraEnabledProvider.overrideWithValue(false)],
      child: const WineerpApp(),
    );

void main() {
  testWidgets('앱 셸이 4탭으로 뜨고 홈은 스캔', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('내역'), findsOneWidget);
    expect(find.text('리포트'), findsOneWidget);
    expect(find.text('재고'), findsOneWidget);
    expect(find.text('스캔'), findsWidgets); // AppBar + 탭 라벨
    expect(find.byIcon(Icons.qr_code_scanner), findsWidgets);
  });

  testWidgets('탭 전환: 재고로 이동', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('재고'));
    await tester.pumpAndSettle();

    expect(find.textContaining('재고가 여기에'), findsOneWidget);
  });
}
