import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wineerp_app/data/auth_repository.dart';
import 'package:wineerp_app/features/auth/auth_controller.dart';
import 'package:wineerp_app/features/receiving/receiving_controller.dart';
import 'package:wineerp_app/features/scan/scan_controller.dart';
import 'package:wineerp_app/features/auth/login_screen.dart';

class _FakeAuthRepo extends AuthRepository {
  _FakeAuthRepo({this.fail = false}) : super(Dio());

  final bool fail;

  @override
  Future<String> login(String email, String password) async {
    if (fail) throw Exception('invalid');
    return 'fake-token';
  }

  @override
  Future<Map<String, dynamic>> me() async => {'role': 'staff'};
}

void main() {
  test('로그인 성공 → 토큰·역할 설정', () async {
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(_FakeAuthRepo())],
    );
    addTearDown(container.dispose);

    final ok = await container
        .read(authControllerProvider.notifier)
        .login('a@wineerp.co', 'pw123456');

    expect(ok, isTrue);
    final state = container.read(authControllerProvider);
    expect(state.isAuthenticated, isTrue);
    expect(state.token, 'fake-token');
    expect(state.role, 'staff');
  });

  test('로그인 실패 → 오류 설정, 미인증', () async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(_FakeAuthRepo(fail: true)),
      ],
    );
    addTearDown(container.dispose);

    final ok = await container
        .read(authControllerProvider.notifier)
        .login('a@wineerp.co', 'wrong');

    expect(ok, isFalse);
    final state = container.read(authControllerProvider);
    expect(state.isAuthenticated, isFalse);
    expect(state.error, isNotNull);
  });

  testWidgets('로그인 화면: 제출 시 인증됨', (tester) async {
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(_FakeAuthRepo())],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    await tester.enterText(find.byKey(const Key('email_field')), 'a@wineerp.co');
    await tester.enterText(find.byKey(const Key('password_field')), 'pw123456');
    await tester.tap(find.byKey(const Key('login_button')));
    await tester.pumpAndSettle();

    expect(container.read(authControllerProvider).isAuthenticated, isTrue);
  });

  test('로그아웃은 이전 사용자의 데이터 프로바이더를 비운다', () async {
    // 비우지 않으면 다른 계정으로 로그인했을 때 내역 탭이 이전 사용자의
    // 입고 기록(이메일까지)을 그대로 보여준다 — 내역에는 역할 가드도 없다.
    final c = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(_FakeAuthRepo()),
    ]);
    addTearDown(c.dispose);

    c.read(matchProvider.notifier).state = const AsyncData(null);
    c.read(selectedCandidateProvider.notifier).state = 'v-old';
    c.read(registeringProvider.notifier).state = true;
    c.read(receivingControllerProvider.notifier).setQuantity(9);

    c.read(authControllerProvider.notifier).logout();
    await Future<void>.delayed(Duration.zero);

    expect(c.read(selectedCandidateProvider), isNull);
    expect(c.read(registeringProvider), isFalse);
    expect(c.read(receivingControllerProvider).quantity, 1);
    expect(c.read(authControllerProvider).isAuthenticated, isFalse);
  });
}
