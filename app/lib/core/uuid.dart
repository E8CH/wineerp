import 'dart:math';

final _rng = Random.secure();

/// UUID v4 생성기. 새 패키지 의존성을 늘리지 않기 위해 직접 구현한다.
///
/// 멱등 키 용도이므로 충돌하지 않는 것이 요구사항의 전부다(암호학적 용도 아님).
/// 그래도 `Random.secure()`를 쓴다 — 기본 `Random()`은 시드가 예측 가능해 같은 순간
/// 시작한 두 단말이 같은 키를 낼 수 있고, 그러면 서로의 입고를 삼킨다.
String uuidV4() {
  final b = List<int>.generate(16, (_) => _rng.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40; // version 4
  b[8] = (b[8] & 0x3f) | 0x80; // variant 10
  final hex = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
