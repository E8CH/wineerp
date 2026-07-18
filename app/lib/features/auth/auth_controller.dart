import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_repository.dart';

/// 인증 상태. 토큰은 메모리 보관(POC — 재시작 시 재로그인). 영속화는 후속.
class AuthState {
  const AuthState({
    this.token,
    this.email,
    this.role,
    this.loading = false,
    this.error,
  });

  final String? token;
  final String? email;
  final String? role;
  final bool loading;
  final String? error;

  bool get isAuthenticated => token != null;

  AuthState copyWith({
    String? token,
    String? email,
    String? role,
    bool? loading,
    String? error,
  }) {
    return AuthState(
      token: token ?? this.token,
      email: email ?? this.email,
      role: role ?? this.role,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  Future<bool> login(String email, String password) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final repo = ref.read(authRepositoryProvider);
      final token = await repo.login(email, password);
      // 토큰을 먼저 반영해야 이후 요청(me)에 인터셉터가 첨부한다.
      state = AuthState(token: token, email: email, loading: true);
      final me = await repo.me();
      state = AuthState(token: token, email: email, role: me['role'] as String?);
      return true;
    } catch (_) {
      state = const AuthState(error: '이메일 또는 비밀번호가 올바르지 않습니다.');
      return false;
    }
  }

  void logout() => state = const AuthState();
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
