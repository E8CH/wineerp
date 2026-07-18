import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wineerp_app/main.dart';

void main() {
  testWidgets('앱 셸이 4탭으로 뜨고 홈은 스캔', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: WineerpApp()));
    await tester.pumpAndSettle();

    // 하단 4탭 라벨 존재
    expect(find.text('내역'), findsOneWidget);
    expect(find.text('리포트'), findsOneWidget);
    expect(find.text('재고'), findsOneWidget);

    // 홈 = 스캔 화면 (스캔은 AppBar 제목 + 탭 라벨로 2회 등장)
    expect(find.text('스캔'), findsWidgets);
    expect(find.byIcon(Icons.qr_code_scanner), findsWidgets);
  });

  testWidgets('탭 전환: 재고로 이동', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: WineerpApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('재고'));
    await tester.pumpAndSettle();

    // 재고 화면의 안내 문구 표시
    expect(find.textContaining('재고가 여기에'), findsOneWidget);
  });
}
