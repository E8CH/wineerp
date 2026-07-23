import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_controller.dart';

/// 로그인 화면 (FR1) — 이메일·비밀번호. 성공 시 라우터가 스캔 홈으로 리다이렉트.
///
/// ⚠️ 데모 편의: debug/profile 빌드에서만 데모 계정(admin / pw1234)이 기본 입력돼
/// [로그인]만 누르면 바로 들어간다. **릴리스 빌드([kReleaseMode])에서는 자동으로
/// 빈 필드**라 운영에 하드코딩 자격증명이 실리지 않는다(fail-closed). 게이팅을 지우면
/// `flutter build apk --release`가 데모 계정을 그대로 노출하므로 지우지 말 것.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  /// 기본 입력값(데모 계정). 한 곳에서만 정의해 화면·테스트가 같은 값을 참조한다.
  static const defaultEmail = 'admin';
  static const defaultPassword = 'pw1234';

  /// 실제로 필드에 채워지는 값 — **릴리스에서는 빈 문자열**. debug/profile/test에서만
  /// 데모 계정을 채운다. 화면·테스트가 같은 규칙을 참조하도록 한 곳에 둔다.
  static String get prefillEmail => kReleaseMode ? '' : defaultEmail;
  static String get prefillPassword => kReleaseMode ? '' : defaultPassword;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController(text: LoginScreen.prefillEmail);
  final _password = TextEditingController(text: LoginScreen.prefillPassword);

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    await ref.read(authControllerProvider.notifier).login(
          _email.text.trim(),
          _password.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('로그인')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('wineerp', style: theme.textTheme.displaySmall),
                const SizedBox(height: 24),
                TextField(
                  key: const Key('email_field'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: '이메일'),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('password_field'),
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '비밀번호'),
                ),
                if (auth.error != null) ...[
                  const SizedBox(height: 12),
                  Text(auth.error!, style: TextStyle(color: theme.colorScheme.error)),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    key: const Key('login_button'),
                    onPressed: auth.loading ? null : _submit,
                    child: auth.loading
                        ? const CircularProgressIndicator()
                        : const Text('로그인'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
