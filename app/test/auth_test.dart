import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wineerp_app/data/auth_repository.dart';
import 'package:wineerp_app/features/auth/auth_controller.dart';
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
}
