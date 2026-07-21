import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wineerp_app/data/inventory_repository.dart';
import 'package:wineerp_app/features/auth/auth_controller.dart';
import 'package:wineerp_app/features/scan/scan_controller.dart';
import 'package:wineerp_app/main.dart';

/// 인증된 상태로 시작(리다이렉트 회피) + 카메라 우회.
class _AuthedController extends AuthController {
  @override
  AuthState build() =>
      const AuthState(token: 'test-token', email: 'a@wineerp.co', role: 'staff');
}

Widget _app() => ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(_AuthedController.new),
        cameraEnabledProvider.overrideWithValue(false),
        // 재고 탭이 실제 네트워크를 치지 않도록 빈 목록으로 대체.
        inventoryProvider.overrideWith((ref) async => const <InventoryItem>[]),
      ],
      child: const WineerpApp(),
    );

void main() {
  testWidgets('인증 시 앱 셸이 4탭으로 뜨고 홈은 스캔', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('내역'), findsOneWidget);
    expect(find.text('리포트'), findsOneWidget);
    expect(find.text('재고'), findsOneWidget);
    expect(find.text('스캔'), findsWidgets);
  });

  testWidgets('탭 전환: 재고로 이동', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('재고'));
    await tester.pumpAndSettle();

    // 재고 화면으로 전환됐는지 — 빈 상태 안내와 새로고침 버튼은 이 화면에만 있다.
    expect(find.byKey(const Key('inventory_empty')), findsOneWidget);
    expect(find.byKey(const Key('inventory_refresh')), findsOneWidget);
  });
}
