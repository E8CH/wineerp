# Story 2.0 (enabler): Flutter 인증 & ApiClient

Status: review

> 구현 중 발견된 enabler(에픽 미명시). 백엔드 인증(1.3/1.4)·스캔(2.4)은 완성됐으나 앱에 로그인·인증 클라이언트가 없어 end-to-end 호출 불가 → 이 조각이 Epic 2 완결의 선행 조건.

## Story

As a 직원,
I want 앱에서 로그인하고 인증된 상태로 API를 호출하기를,
so that 스캔·업로드 등 백엔드 기능을 실제로 사용할 수 있다.

## Acceptance Criteria

1. **Dio 클라이언트**: baseUrl(Env) + 요청 인터셉터가 현재 토큰을 `Authorization: Bearer`로 자동 첨부. Riverpod provider.
2. **인증 상태**: `AuthController`(Riverpod) — 로그인/로그아웃, 상태 = {token, email, role}. 로그인 시 `POST /auth/login`, 실패 시 오류 노출.
3. **로그인 화면**: 이메일·비밀번호 폼 → 로그인 → 성공 시 스캔 홈으로. 미인증 시 라우터가 로그인으로 리다이렉트.
4. **스캔 실연결**: 스캔 화면에서 인식 코드 → `ScanRepository.scan(code, token)` 호출 → 매칭 시 `ReceivingConfirmCard` 표시(2.4 위젯 활용).
5. **검증**: AuthController(가짜 repo) 로그인 성공/실패, 로그인 화면·리다이렉트 위젯 테스트, analyze clean.

## Tasks / Subtasks

- [x] **T1. Dio provider + 인터셉터** — `data/api_client.dart` dioProvider(baseUrl=/api/v1, 토큰 자동 첨부)
- [x] **T2. AuthRepository** — `data/auth_repository.dart` login(form-urlencoded)/me
- [x] **T3. AuthController** — `features/auth/auth_controller.dart` AuthState + login/logout(메모리 토큰)
- [x] **T4. 로그인 화면** — `features/auth/login_screen.dart`(이메일·비번·오류·로딩)
- [x] **T5. 라우터 리다이렉트** — `core/router.dart` routerProvider + refreshListenable(미인증→/login)
- [x] **T6. 스캔 실연결** — scan_screen: onNewCode → scanRepository.scan → ReceivingConfirmCard/미매칭/로딩/오류
- [x] **T7. 테스트** — AuthController 성공/실패 + 로그인 화면 + 셸(인증 override) 12 통과, analyze clean

## Dev Notes

- **재사용**: 백엔드 `/auth/login`·`/auth/me`(1.3), `/scan`(2.4), Dart `ScanRepository`·`ReceivingConfirmCard`(2.4). 재구현 금지.
- **토큰 저장**: 우선 **메모리 보관**(POC — 재시작 시 재로그인). 보안 영속화(flutter_secure_storage)는 후속. 이 한계 명시.
- **테스트 용이성**: AuthController는 AuthRepository를 주입받아 가짜로 대체 가능. Dio 실호출은 위젯 테스트에서 제외(provider override).
- **라우터**: go_router `redirect`로 인증 상태 반영. 로그인 라우트는 셸 밖(풀스크린).
- **에러**: 로그인 실패 401 → "이메일/비번 확인" 인라인.

### References
- [Source: architecture.md#Authentication & Security / Frontend Architecture]
- [Source: epics.md#Story 1.3/2.4]

## Dev Agent Record

### Agent Model Used
claude-opus-4-8 (dev-story)

### Debug Log References

- `flutter analyze` → No issues / `flutter test` → 12 passed

### Completion Notes List

- AC1~5 충족. 스캔→매칭→확인카드가 앱 내에서 실연결됨(2.4 위젯·백엔드 재사용). 라우터가 미인증 시 로그인으로 리다이렉트.
- **한계**: 토큰 **메모리 보관**(재시작 시 재로그인) — flutter_secure_storage 영속화는 후속. 실서버 호출 검증은 backend 배포(Railway) + 기기 필요.
- scan_repository/api_client는 dio 인터셉터로 토큰 자동 첨부 → repo 메서드에서 토큰 인자 제거(2.4 대비 정리).

### File List

**(NEW)** `app/lib/data/api_client.dart`, `app/lib/data/auth_repository.dart`, `app/lib/features/auth/auth_controller.dart`, `app/lib/features/auth/login_screen.dart`, `app/test/auth_test.dart`
**(MOD)** `app/lib/core/router.dart`(routerProvider+리다이렉트), `app/lib/main.dart`(routerProvider), `app/lib/features/scan/scan_screen.dart`(매칭 실연결), `app/lib/features/scan/scan_controller.dart`(matchProvider), `app/lib/data/scan_repository.dart`(dio provider·토큰인자 제거), `app/test/widget_test.dart`(인증 override)
