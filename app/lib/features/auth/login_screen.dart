import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_controller.dart';

/// 로그인 화면 (FR1) — 이메일·비밀번호. 성공 시 라우터가 스캔 홈으로 리다이렉트.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

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
