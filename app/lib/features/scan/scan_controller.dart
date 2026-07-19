import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/scan_models.dart';

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

/// 스캔 매칭 결과(비동기). 인식 코드로 /scan 호출 결과를 보관.
final matchProvider =
    StateProvider<AsyncValue<ScanResult?>>((ref) => const AsyncData(null));

/// 선택된 빈티지 후보의 id (Story 2.5). null = 아직 고르지 않음.
///
/// ⚠️ 위젯 로컬 state가 아니라 프로바이더에 두는 이유: 폴드 접기/펴기는 Activity 구성
/// 변경으로 위젯 트리를 재빌드하므로, 로컬 state면 진행 중이던 선택이 사라진다(UX-DR14).
/// `WineVintageRead`에 `==`가 없어 객체가 아닌 id 문자열로 비교한다.
final selectedCandidateProvider = StateProvider<String?>((ref) => null);

/// 신규 등록 패널이 열려 있는지 (Story 3.2). 위젯 로컬 state가 아닌 이유는
/// 후보 선택과 같다 — 폴드 접기/펴기가 진행 중이던 등록을 날리면 안 된다.
final registeringProvider = StateProvider<bool>((ref) => false);

/// 방금 등록해 곧바로 입고로 이어갈 후보. 완료·재스캔 시 함께 비운다.
///
/// id가 아니라 후보 객체를 담는 이유: 확인 카드는 모델명·생산자·빈티지를 보여줘야 하는데,
/// 방금 만든 마스터를 다시 스캔·조회해서 가져오면 왕복이 하나 더 늘고 그동안 화면이 빈다.
final registeredCandidateProvider = StateProvider<VintageCandidate?>((ref) => null);

