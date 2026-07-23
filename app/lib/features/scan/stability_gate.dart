/// 바코드 안정 인식 게이트 — 같은 코드가 연속 [threshold]번 관측돼야 "안정"으로 확정한다.
///
/// mobile_scanner는 바코드가 프레임에 있는 동안 **매 프레임** 인식 이벤트를 낸다.
/// 첫 프레임에 곧바로 확정하면, 옆 병의 바코드가 순간 스쳐 지나가거나 흔들려 부분 인식된
/// 코드에도 잠겨버린다 — 그 순간 카메라를 홀드하고 프레임을 정지시키므로, 잘못 잠그면
/// 직원이 엉뚱한 병으로 확정 화면에 들어간다. 연속 관측을 요구해 "손이 멈춘 순간"만 잡는다.
///
/// 카메라 위젯(테스트 대상 아님)에서 떼어내 **순수 로직으로 단위 검증**한다.
class StabilityGate {
  StabilityGate({this.threshold = 2}) : assert(threshold >= 1);

  /// 확정에 필요한 연속 동일 인식 횟수.
  final int threshold;

  String? _pending;
  int _hits = 0;
  bool _locked = false;

  /// 관측된 코드 하나를 넣는다.
  ///
  /// 같은 코드가 연속 [threshold]번 관측된 **그 순간 한 번만** true를 반환한다(안정 확정).
  /// 확정 후에는 [reset] 전까지 계속 false다 — 한 번 홀드하면 그걸로 끝이고, 같은 코드가
  /// 계속 들어와도 다시 확정되지 않는다. 중간에 다른 코드가 끼면 카운트가 처음부터다.
  bool observe(String code) {
    if (_locked || code.isEmpty) return false;
    if (code != _pending) {
      _pending = code;
      _hits = 1;
    } else {
      _hits++;
    }
    if (_hits >= threshold) {
      _locked = true;
      return true;
    }
    return false;
  }

  /// 다음 병을 위해 재무장. 홀드를 풀 때 함께 부른다.
  void reset() {
    _pending = null;
    _hits = 0;
    _locked = false;
  }
}
