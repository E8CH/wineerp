import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/uuid.dart';
import '../../data/receiving_repository.dart';
import '../scan/scan_controller.dart';

/// 입고 제출 상태. `submitting` 중에는 [완료]를 눌러도 아무 일이 없어야 한다 —
/// 연타가 입고 레코드를 2건 만들면 재고가 조용히 부풀고 직원은 알 방법이 없다.
enum ReceivingPhase { idle, submitting, error }

class ReceivingState {
  const ReceivingState({
    required this.idempotencyKey,
    this.quantity = 1,
    this.phase = ReceivingPhase.idle,
    this.error,
  });

  final int quantity;
  final ReceivingPhase phase;
  final String? error;

  /// 이 '병'의 멱등 키. 재시도는 같은 키를 재사용해야 서버가 중복을 구분한다.
  /// 입고가 성공하면 새 키가 발급된다 — 다음 병은 별개 입고다.
  final String idempotencyKey;

  bool get isSubmitting => phase == ReceivingPhase.submitting;

  ReceivingState copyWith({
    int? quantity,
    ReceivingPhase? phase,
    String? error,
    bool clearError = false,
  }) =>
      ReceivingState(
        idempotencyKey: idempotencyKey, // 재시도 간 절대 바뀌지 않는다
        quantity: quantity ?? this.quantity,
        phase: phase ?? this.phase,
        error: clearError ? null : (error ?? this.error),
      );
}

class ReceivingController extends Notifier<ReceivingState> {
  @override
  ReceivingState build() => ReceivingState(idempotencyKey: uuidV4());

  void setQuantity(int q) {
    if (state.isSubmitting) return;
    state = state.copyWith(quantity: q < 1 ? 1 : q, clearError: true);
  }

  /// 입고 확정. 성공하면 true.
  ///
  /// 실패 시 수량과 선택을 **유지한 채** 오류만 표시한다 — 스캔으로 되돌리면
  /// 직원이 방금 센 병 수를 다시 세야 하고, 입고 기록은 유실되면 안 된다(NFR2).
  Future<bool> submit(String wineVintageId) async {
    if (state.isSubmitting) return false; // 중복 제출 차단
    state = state.copyWith(phase: ReceivingPhase.submitting, clearError: true);
    try {
      await ref.read(receivingRepositoryProvider).create(
            wineVintageId: wineVintageId,
            quantity: state.quantity,
            // ⚠️ state의 키를 그대로 보낸다. 여기서 새로 만들면 재시도마다 키가 달라져
            // 서버가 중복을 구분하지 못하고 멱등성이 통째로 무력해진다.
            idempotencyKey: state.idempotencyKey,
          );
      // ⚠️ 저장 성공 이후에는 무엇도 실패로 되돌릴 수 없다. 햅틱은 장식이므로
      // 임계 경로 밖에서 처리한다 — 진동이 안 되는 기기에서 리셋이 통째로
      // 건너뛰어지면 입고는 됐는데 다음 병을 못 찍는 상태가 된다.
      unawaited(HapticFeedback.mediumImpact().catchError((_) {}));
      _resetScanLoop();
      state = ReceivingState(idempotencyKey: uuidV4()); // 다음 병은 새 키
      return true;
    } on DioException catch (e) {
      state = state.copyWith(phase: ReceivingPhase.error, error: _message(e));
      return false;
    }
    // ⚠️ DioException 외의 예외는 삼키지 않는다. 파싱 오류·타입 오류를 "저장 실패"로
    // 표시하면 직원이 재시도해 입고가 2건이 되고, 진짜 버그는 현장에서 영영 드러나지 않는다.
  }

  /// 재시도가 의미 있는 실패와 그렇지 않은 실패를 구분한다.
  /// "다시 시도하세요"를 무조건 띄우면 만료된 토큰으로 영원히 재시도하게 된다.
  static String _message(DioException e) {
    final status = e.response?.statusCode;
    if (status == 401) return '로그인이 만료되었습니다 · 다시 로그인하세요';
    if (status == 404) return '해당 와인을 찾을 수 없습니다 · 다시 스캔하세요';
    if (status != null && status >= 400 && status < 500) {
      return '입고 정보가 올바르지 않습니다';
    }
    return '입고 저장 실패 · 네트워크 확인 후 다시 시도하세요';
  }

  /// 다음 병을 받을 수 있도록 스캔 루프를 초기화한다.
  ///
  /// ⚠️ `scanController.reset()`이 핵심이다. `ScanController`는 같은 코드 연속 인식을
  /// 디바운스로 무시하므로, 리셋하지 않으면 **같은 와인의 두 번째 병을 스캔할 수 없다** —
  /// 그런데 같은 와인 여러 병 입고는 예외가 아니라 가장 흔한 경우다.
  void _resetScanLoop() {
    ref.read(matchProvider.notifier).state = const AsyncData(null);
    ref.read(selectedCandidateProvider.notifier).state = null;
    ref.read(registeredCandidateProvider.notifier).state = null;
    ref.read(scanControllerProvider.notifier).reset();
  }
}

final receivingControllerProvider =
    NotifierProvider<ReceivingController, ReceivingState>(
  ReceivingController.new,
);
