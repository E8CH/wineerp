import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 초기 재고 세팅 모드 (FR13, UX-DR10).
///
/// 입고와 **다른 모드**다. 세팅 중에는 입고 기록을 만들지 않으며(등록만),
/// 보유 수량을 넣으면 `source='initial_setup'` 기준 재고로 기록된다.
class SetupModeState {
  const SetupModeState({this.active = false, this.registeredCount = 0});

  final bool active;

  /// 이번 세팅 세션에서 등록한 종 수. 배너 카운터로 진척을 보여준다 —
  /// 창고를 한 바퀴 도는 작업이라 "얼마나 했는지"가 보여야 계속할 수 있다.
  final int registeredCount;

  SetupModeState copyWith({bool? active, int? registeredCount}) => SetupModeState(
        active: active ?? this.active,
        registeredCount: registeredCount ?? this.registeredCount,
      );
}

class SetupModeController extends Notifier<SetupModeState> {
  @override
  SetupModeState build() => const SetupModeState();

  void enter() => state = const SetupModeState(active: true);

  /// 나가면 카운터도 함께 비운다 — 다음 세션은 0부터다.
  void exit() => state = const SetupModeState();

  void countRegistration() =>
      state = state.copyWith(registeredCount: state.registeredCount + 1);
}

final setupModeProvider =
    NotifierProvider<SetupModeController, SetupModeState>(SetupModeController.new);
