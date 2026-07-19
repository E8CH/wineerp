import 'package:flutter/foundation.dart';

/// 비민감 런타임 설정. 시크릿(LLM 키 등)은 앱에 두지 않고 백엔드에서만 다룬다.
///
/// API base URL은 빌드 시 `--dart-define=API_BASE_URL=...`로 주입.
/// 미주입 시 로컬 백엔드(http://10.0.2.2:8000 = 안드로이드 에뮬레이터의 호스트 localhost).
class Env {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _localDefault,
  );

  static const String _localDefault = 'http://10.0.2.2:8000';

  static const String apiV1Prefix = '/api/v1';

  static String get apiV1 => '$apiBaseUrl$apiV1Prefix';

  /// ⚠️ 릴리스 빌드에서 `--dart-define=API_BASE_URL`을 빠뜨리면 앱이 에뮬레이터
  /// 전용 주소를 가리킨 채로 만들어지고, **설치해서 열어봐야** 아무것도 안 되는 것을 안다.
  /// 시연 자리에서 발견하기 딱 좋은 실패라 빌드 산출물이 아니라 시작 시점에 못 박는다.
  ///
  /// `main()`에서 호출한다. 디버그·테스트에서는 기본값이 정상이므로 통과시킨다.
  static void assertConfigured() {
    if (kReleaseMode && apiBaseUrl == _localDefault) {
      throw StateError(
        '릴리스 빌드에 API_BASE_URL이 주입되지 않았습니다. '
        '이 앱은 에뮬레이터 전용 주소($_localDefault)를 가리키고 있어 서버에 닿지 못합니다.\n'
        'flutter build apk --release --dart-define=API_BASE_URL=https://... 로 다시 빌드하세요.',
      );
    }
  }
}
