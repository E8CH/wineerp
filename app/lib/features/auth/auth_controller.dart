import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_repository.dart';
import '../../data/history_repository.dart';
import '../../data/report_repository.dart';
import '../receiving/receiving_controller.dart';
import '../registration/registration_controller.dart';
import '../registration/setup_mode_controller.dart';
import '../scan/scan_controller.dart';

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

  /// ⚠️ 상태만 비우면 안 된다. 데이터 프로바이더는 autoDispose가 아니고 탭은
  /// IndexedStack으로 살아 있어, 다른 계정으로 로그인하면 내역 탭이 **이전 사용자의
  /// 입고 기록**(그 사람 이메일까지)을 그대로 보여준다. 리포트는 역할 가드가 있지만
  /// 내역에는 없다.
  void logout() {
    ref.invalidate(historyProvider);
    ref.invalidate(reportProvider);
    ref.invalidate(matchProvider);
    ref.invalidate(selectedCandidateProvider);
    ref.invalidate(registeredCandidateProvider);
    ref.invalidate(registeringProvider);
    ref.invalidate(receivingControllerProvider);
    ref.invalidate(registrationControllerProvider);
    ref.invalidate(setupModeProvider);
    state = const AuthState();
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
