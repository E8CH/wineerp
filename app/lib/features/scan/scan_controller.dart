import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 스캔 상태 — 마지막 인식 바코드. Story 2.4 매칭이 `lastCode`를 소비.
class ScanState {
  const ScanState({this.lastCode});

  final String? lastCode;
}

class ScanController extends Notifier<ScanState> {
  String? _lastAccepted;

  @override
  ScanState build() => const ScanState();

  /// 인식 코드 수용. 같은 코드 연속 인식은 무시(디바운스).
  /// 반환값 true = 새 코드(햅틱·매칭 트리거 대상).
  bool onDetected(String code) {
    if (code.isEmpty || code == _lastAccepted) return false;
    _lastAccepted = code;
    state = ScanState(lastCode: code);
    return true;
  }

  void reset() {
    _lastAccepted = null;
    state = const ScanState();
  }
}

final scanControllerProvider =
    NotifierProvider<ScanController, ScanState>(ScanController.new);

/// 카메라 사용 여부. 위젯 테스트에서 false로 override해 플랫폼 카메라를 우회한다.
final cameraEnabledProvider = Provider<bool>((ref) => true);

