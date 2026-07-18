/// 비민감 런타임 설정. 시크릿(LLM 키 등)은 앱에 두지 않고 백엔드에서만 다룬다.
///
/// API base URL은 빌드 시 `--dart-define=API_BASE_URL=...`로 주입.
/// 미주입 시 로컬 백엔드(http://10.0.2.2:8000 = 안드로이드 에뮬레이터의 호스트 localhost).
class Env {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  static const String apiV1Prefix = '/api/v1';

  static String get apiV1 => '$apiBaseUrl$apiV1Prefix';
}
