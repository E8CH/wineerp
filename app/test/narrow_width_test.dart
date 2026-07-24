import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wineerp_app/features/receiving/widgets/receiving_confirm_card.dart';
import 'package:wineerp_app/features/registration/widgets/setup_mode_banner.dart';

/// 좁은 폭(갤럭시 폴드 커버 ≈280dp) 오버플로우 회귀 방지.
///
/// 세팅 배너는 아이콘·라벨·카운터·나가기를 한 줄에 담는데, 라벨을 Flexible로
/// 감싸지 않으면 좁은 폭에서 RenderFlex 가로 오버플로우가 난다. 여기서 검증한다.
///
/// 변이 검증: setup_mode_banner.dart의 라벨에서 Flexible을 제거하면
/// (고정 폭 Text로 되돌리면) 이 테스트는 오버플로우 예외로 실패한다.
void main() {
  testWidgets('세팅 배너는 폴드 커버 폭(280dp)에서 오버플로우 없이 그려진다',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 280,
              // 세 자릿수 카운터로 최악 폭을 만든다.
              child: SetupModeBanner(registeredCount: 999, onExit: () {}),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull, reason: '가로 오버플로우가 없어야 한다');
    // 라벨은 줄어들되(…) 카운터·나가기는 계속 보여야 한다.
    expect(find.byKey(const Key('setup_counter')), findsOneWidget);
    expect(find.byKey(const Key('setup_exit')), findsOneWidget);
  });

  testWidgets('입고 확인 카드는 긴 이름을 줄 제한으로 묶어 카드가 늘어지지 않는다',
      (tester) async {
    const producer = '아주 긴 생산자 이름이 계속 이어지는 경우의 도멘 드 라 로마네 콩티';
    const modelName = '아주 긴 모델명이 계속 이어지는 경우의 그랑 크뤼 빈티지 셀렉션 리저브';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 280,
              child: ReceivingConfirmCard(
                modelName: modelName,
                producer: producer,
                vintage: 2018,
                stock: 12,
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    // 이름은 ellipsis로 묶여 무한정 줄바꿈되지 않는다(candidate_list와 동일한 가드).
    // 변이 검증: maxLines를 지우면 이 기대가 깨진다.
    expect(tester.widget<Text>(find.text(producer)).maxLines, 1);
    expect(tester.widget<Text>(find.text(modelName)).maxLines, 2);
  });
}
