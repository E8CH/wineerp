---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8]
lastStep: 8
status: 'complete'
completedAt: '2026-07-18'
inputDocuments:
  - _bmad-output/planning-artifacts/prds/prd-wineerp-2026-07-15/prd.md
  - _bmad-output/planning-artifacts/prds/prd-wineerp-2026-07-15/addendum.md
  - _bmad-output/planning-artifacts/briefs/brief-wineerp-2026-07-15/brief.md
  - _bmad-output/planning-artifacts/briefs/brief-wineerp-2026-07-15/addendum.md
  - _bmad-output/planning-artifacts/ux-design-specification.md
  - _bmad-output/planning-artifacts/research/domain-와인-바코드와-빈티지-식별-wineerp-oq-2-검증-research-2026-07-17.md
  - docs/idea.md
  - docs/chat_history.md
workflowType: 'architecture'
project_name: 'wineerp'
user_name: 'HEMICOLON'
date: '2026-07-16'
---

# Architecture Decision Document

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

## Project Context Analysis

### Requirements Overview

**Functional Requirements (13 FR, 5 groups):**
- 인증·역할(FR-1,2), 입고 스캔·식별(FR-3~6), 입고 처리(FR-7,8,12), 조회·리포트(FR-9,10,11), 초기 세팅(FR-13)
- 아키텍처적으로 무거운 지점: FR-5(마스터 매칭), FR-6/FR-13(LLM 라벨 추론)

**Non-Functional Requirements:**
- 서버 중심 영속화, 입고 기록 무유실 (단순 로컬 앱 금지)
- 매칭 표시 ≤2초, LLM 추론 3~5초 (현장 흐름 비차단)
- 모바일 우선(안드로이드 우선, 크로스플랫폼 지향), 한 손 연속 스캔
- WCAG 2.1 AA, 갤럭시 폴드 대응(378×927 / 794×924dp, 상태보존)
- 원장 역할 시 5년 보존(국세기본법 §85조의3)

**Scale & Complexity:**
- 데이터 규모: 소 (하루 ≤100건, 마스터 ~1,000종)
- 복잡도: medium — 무게중심이 CRUD가 아닌 (a)식별 도메인모델 (b)외부 LLM·와인DB 통합
- Primary domain: mobile(Flutter) + backend + external AI/data integration

### Technical Constraints & Dependencies (리서치 근거, 2026-07-17)

- **빈티지는 독립 식별축**: `vintage` nullable, NV=1급 상태. 바코드=producer+wine+size, 바코드↔와인 N:M
- **외부 와인 API 단일 의존 금지**(Wine.com·GWS·LCBO·Snooth 4개 조용히 소멸 실증) → LWIN(CC BY, 빈티지 내장 LWIN-11) 내부 표준키, 라벨인식 벤더(api4ai 등) 교체 가능 추상화
- **LLM 유료 티어 필수**(무료 Gemini=콘텐츠 학습·사람 검토, "sensitive/confidential 제출 금지"), 벤더 추상화(Gemini/OpenAI), 리전 통제 필요 시 Vertex/OpenAI 검토
- **라벨=사물→개인정보 아님**(개인정보보호법 §2①, 개인정보위 공식 해석): 불필요한 동의/국외이전 고지 UI 금지. 단 사람 우발 촬영·거래처 담당자 PII는 설계로 소거(라벨 중심 촬영 UI, 페이로드 위생)
- **바코드 빈티지 인식 정확도를 KPI로 삼지 말 것** — 독립·재현가능 공개 벤치마크 부재. PRD SM-3는 "판정 도출"로 재해석

### Cross-Cutting Concerns Identified

- 와인 식별(바코드+라벨+LLM) — 다수 FR을 관통하는 핵심 축
- 외부 통합 계층(와인DB·라벨인식·LLM)의 장애·교체 대응(회복탄력성)
- 인증·역할 경계(직원/관리자)
- 데이터 영속성·보존(무유실, 5년)
- 개인정보 최소화(페이로드 위생: 라벨 이미지 한정, EXIF 제거 선택)

## Starter Template Evaluation

### Primary Technology Domain
모바일(Flutter) 프론트 + FastAPI/PostgreSQL 백엔드 2계층. 관리자 웹(Next.js)은 모바일 우선 결정으로 보류(본 제품 단계 재검토).

### Starter Options Considered
- 프론트: flutter create(공식) vs Very Good CLI → POC 속도·제어 우선으로 flutter create
- 백엔드: full-stack-fastapi-template(공식/MIT) vs 수제 FastAPI → 인증·DB·마이그레이션 head start로 템플릿 채택(React 프론트는 미사용)

### Selected Starter

**프론트엔드: Flutter (`flutter create`)**
- 버전: Flutter 3.44 stable(Material 3 기본값, 3.16+). 안드로이드 우선, iOS 포함은 OQ 확인
- 초기화: `flutter create wineerp_app --org co.wineerp --platforms android,ios`
- 제공 결정: Material 3 테마 시스템(UX 네이비 시드 적용), 위젯 구조, 핫리로드, 통합 테스트 스캐폴드
- 패키지(스캔·카메라·상태관리·HTTP·이미지)는 Step 4~5에서 확정

**백엔드: full-stack-fastapi-template (fastapi/full-stack-fastapi-template, MIT)**
- 초기화: 템플릿 clone/copier 후 `/frontend`(React) 제거, `/backend`만 사용
- 제공 결정:
  - FastAPI + SQLModel(ORM) + Pydantic(검증)
  - PostgreSQL + Alembic 마이그레이션 → 스키마 진화·5년 보존 설계 기반
  - JWT 이메일+비밀번호 인증 + 사용자 모델(superuser 플래그) → FR-1/FR-2 역할 구분 기반
  - Docker + GitHub Actions CI + pytest(90%+ 커버리지 관행), ruff/mypy
- 배포: Railway(백엔드 + PostgreSQL). Docker 이미지 호환
- 보너스: 자동 OpenAPI 스키마 → Flutter용 Dart 클라이언트 생성으로 프론트-백 계약 동기화

### Rationale
POC 기간(1주) 안에 인증·DB·마이그레이션·배포 파이프라인을 처음부터 만들 여유가 없다. 공식 템플릿이 FR-1/FR-2와 서버중심·무유실 NFR을 즉시 충족하며, MIT·활발한 유지보수로 클라이언트 딜리버리 리스크가 낮다. Flutter는 UX 확정 테마를 그대로 얹을 수 있어 바닐라 create가 가장 빠르다.

**Note:** 두 초기화(flutter create / 템플릿 백엔드 부트스트랩)는 구현 첫 스토리로 둔다.

## Core Architectural Decisions

### Decision Priority Analysis

**Critical Decisions (Block Implementation):**
- 2계층 와인 식별 모델(WineProduct → WineVintage), 바코드 N:M, LWIN 표준키 (Data)
- 외부 벤더 Ports & Adapters 격리(LLM·카탈로그) (API/Integration)

**Important Decisions (Shape Architecture):**
- 역할 enum(staff/manager), LLM 페이로드 위생, Riverpod 3.x, mobile_scanner 7.0.0, 이미지 오브젝트 스토리지, soft-delete+5년 보존

**Deferred Decisions (Post-MVP):**
- 오프라인 입고(온라인 필수), 관리자 웹(Next.js), 원가/마진 필드 실사용, 다중 창고, api4ai/InVintory 실연동(어댑터 슬롯만 확보)

### Data Architecture

**2계층 와인 식별 모델 (PRD 글로서리 정련, 리서치 2026-07-17 근거)**
```
WineProduct  (= "같은 와인" 상위 개념)
   producer, model_name, region, country, grape(opt), lwin7(opt, nullable)
   │ 1:N
WineVintage  (= PRD "와인 마스터", 가격결정·재고 단위)
   vintage(nullable int ← NV=1급 상태), lwin11(opt),
   representative_image_key, (cost/margin = 본 제품 확장 슬롯)
```
- 근거: 이카운트 Lot이 못 하는 빈티지별 원가·마진을 구조로 가능케 하면서 "같은 와인" 묶음 유지 — **프로젝트 존재 이유의 구조적 표현**.
- `vintage` nullable — NV(샴페인 85~95%, 셰리 ~98%)는 인식 실패 아닌 유효 상태.

**바코드 엔티티, WineProduct와 N:M**
- `Barcode` N:M `WineProduct`(조인 테이블). 바코드=producer+wine+size까지만 특정, 빈티지 미포함.
- 스캔 흐름: 바코드→WineProduct 후보→사용자가 라벨로 WineVintage 확정(InVintory 항상-피커 + CellarTracker 매핑학습 = 업계 표준 해법).

**LWIN 내부 표준키**: lwin7/lwin11(nullable) 각 계층 보관 → 카탈로그 벤더 교체 시 안정 매핑키.

**입고 기록**: `ReceivingRecord` = WineVintage + qty + timestamp + staff + memo(nullable). **하드삭제 금지, soft-delete + 수정이력**(FR-8, 국세기본법 §85조의3 5년).

**이미지 저장**: Postgres 밖 오브젝트 스토리지(권장 Cloudflare R2, S3 호환·egress 무료 / 대안 Railway 볼륨), DB엔 key/URL만. **업로드 시 EXIF 제거**.

_검증/마이그레이션: Pydantic + Alembic(스타터 제공)._

### Authentication & Security

- **역할 모델**: 템플릿 `is_superuser`(boolean) → **User.role enum(staff | manager)** 추가. manager ⊇ staff + 리포트/엑셀(FR-2, OQ-4).
- **LLM 페이로드 위생**: 라벨 이미지만 전송, 거래처/담당자 PII·매입가 미포함, 사람 감지 시 재촬영 유도(개인정보 소거). 라벨=사물→개인정보 아님 → 불필요한 동의 UI 금지.
- 인증·JWT·비밀번호 해싱은 스타터(full-stack-fastapi-template) 제공.

### API & Communication Patterns

**Ports & Adapters로 외부 벤더 격리** (리서치: 외부 와인 API는 조용히 죽는다):
- `LabelInferencePort` → GeminiAdapter / OpenAIAdapter (env 스위치, **유료 티어 필수**)
- `WineCatalogPort` → LwinLocalAdapter(1차) + Api4aiAdapter/InVintoryAdapter(선택 슬롯)
- 호출별 timeout + 폴백(LLM 실패→수동 입력, FR-6). OQ-6 제공자 비교를 어댑터 교체로 흡수.

**REST + OpenAPI**: FastAPI 자동 스키마 → Dart 클라이언트 생성(프론트-백 계약 동기화). 일관 에러 엔벌로프.

### Frontend Architecture

- **상태관리: Riverpod 3.x** (async-first·저보일러플레이트·POC 속도. Bloc 감사추적 이점은 서버측 이력으로 대체).
- **바코드: mobile_scanner 7.0.0** (ML Kit/CameraX, AVFoundation).
- **라우팅 go_router**, 촬영 후 이미지 압축→업로드/LLM.
- 오프라인은 POC 범위 밖(온라인 필수), 네트워크 실패 우아 처리.
- Material 3 네이비 시드 테마(UX 사양 적용).

### Infrastructure & Deployment

- **Railway**: 백엔드(Docker) + PostgreSQL 매니지드. 이미지=R2(또는 Railway 볼륨).
- **시크릿**: LLM 키는 Billing 활성화(유료 티어) 계정, `.gitignore`, 12-factor env.
- CI=GitHub Actions(스타터). 로깅=구조화 로그 + Railway 로그(POC 최소).

### Decision Impact Analysis

**Implementation Sequence:**
1. 백엔드/프론트 스타터 부트스트랩 → 2. 데이터 모델·마이그레이션(WineProduct/WineVintage/Barcode/ReceivingRecord) → 3. 인증·역할 → 4. 스캔·매칭 → 5. LabelInferencePort(LLM 신규등록) → 6. 입고 처리 → 7. 조회·리포트·엑셀 → 8. 초기 세팅(FR-13)

**Cross-Component Dependencies:**
- 2계층 모델이 매칭·신규등록·초기세팅 에픽 전체를 규정(CE 단계 반영).
- Ports 추상화로 "LLM 추론"·"카탈로그 조달"이 독립 에픽/스토리로 분리.

## Implementation Patterns & Consistency Rules

### Naming Patterns

**DB (SQLModel/PostgreSQL):**
- 테이블 `snake_case` 복수: `wine_products`, `wine_vintages`, `barcodes`, `barcode_wine_product_links`, `receiving_records`, `users`
- 컬럼 `snake_case`, FK `{entity}_id`, PK **UUID** `id`, 인덱스 `ix_{table}_{column}`, 타임스탬프 `created_at`/`updated_at`/`deleted_at`

**API (FastAPI REST):**
- 경로 `/api/v1/{복수명사}`, path param `{id}`, 쿼리 `snake_case`
- **와이어 JSON = snake_case**(Pydantic 기본), 버전 프리픽스 `/api/v1` 고정

**Python:** 함수·변수 snake_case, 클래스 PascalCase, 모듈 snake_case (ruff/mypy 강제)
**Dart:** 멤버 lowerCamelCase, 타입 PascalCase, 파일 snake_case (`flutter_lints`). JSON 매핑은 `json_serializable @JsonKey` 또는 OpenAPI 생성 클라이언트가 snake↔camel 흡수

### Structure Patterns

- 백엔드: `app/models`, `app/api/routes/{feature}.py`, `app/crud`, `app/services`(Ports), `app/adapters`(Gemini/OpenAI/LWIN), `app/core`, `app/tests/`
- 프론트(feature-first): `lib/features/{scan,receiving,report,initial_setup,auth}/`, `lib/core/`, `lib/data/`(client·models), 위젯 테스트 co-located `_test.dart`

### Format Patterns

- 날짜/시간: **ISO 8601 UTC 문자열**, 표시 변환은 클라이언트
- 에러: FastAPI 기본 `{"detail": ...}` + 검증 422, 도메인 에러 `{"detail": {"code","message"}}`
- 성공: 리소스 직접 반환, 리스트 `{data, count}`
- 수량 `int`, `vintage` nullable int, (향후) 금액 = 정수 KRW, boolean `true/false`
- 상태코드: 생성 201 / 조회 200 / 삭제 204 / 검증 422 / 인증 401 / 권한 403

### Communication & State Patterns

- Riverpod: 불변 상태 + `AsyncValue<T>`(data/loading/error) 통일, `xxxProvider`/`XxxNotifier`, 직접 mutation 금지
- 로딩/에러 UI: `AsyncValue.when()` 단일 패턴
- 외부 호출: 어댑터 내부 timeout+재시도, 실패는 도메인 결과로 반환 → UI가 수동 입력 폴백(FR-6)으로 분기

### Enforcement Guidelines — All AI Agents MUST

- 와이어 snake_case ↔ Dart camelCase 경계 매핑 생략 금지
- 입고 기록 하드삭제 금지(soft-delete만)
- 빈티지는 WineVintage에만, 바코드에 인코딩 금지. `vintage` nullable, NV를 에러 취급 금지
- LLM 페이로드에 라벨 이미지 외 데이터(PII·매입가) 포함 금지
- 외부 벤더 직접 호출 금지 — `LabelInferencePort`/`WineCatalogPort` 경유
- 시크릿(LLM 키)은 코드·로그에 남기지 말 것(env만)

**Anti-patterns:** 바코드 연도 파싱 / `is_superuser` 역할 판정(→ `role` enum) / 이미지 base64 DB 저장 / 카멜케이스 컬럼 / LLM 결과 무확인 자동 저장(SM-C2 위반)

## Project Structure & Boundaries

### Complete Project Directory Structure (모노레포)

```
wineerp/
├── docker-compose.yml            # 로컬: db + backend
├── .github/workflows/ci.yml
├── backend/                      # full-stack-fastapi-template의 backend만 사용
│   ├── pyproject.toml / Dockerfile / alembic.ini / .env.example
│   ├── app/
│   │   ├── main.py               # FastAPI, /api/v1
│   │   ├── core/                 # config(프로바이더 스위치)·security(JWT)·db
│   │   ├── models/               # user(+role), wine_product, wine_vintage,
│   │   │                         #   barcode(+link), receiving_record
│   │   ├── api/routes/           # auth, scan, wines, receiving, reports
│   │   ├── crud/                 # DB 접근 계층
│   │   ├── services/             # ★Ports: label_inference, wine_catalog, reporting
│   │   ├── adapters/             # ★벤더: gemini, openai, lwin_local, api4ai(슬롯), storage_r2
│   │   └── tests/
│   ├── alembic/versions/
│   └── data/lwin/                # LWIN CSV 시드(내부 표준키)
└── app/                          # Flutter (flutter create)
    ├── pubspec.yaml              # riverpod 3.x, mobile_scanner 7, go_router, dio, json_serializable, image
    ├── analysis_options.yaml
    └── lib/
        ├── main.dart
        ├── core/                 # theme(M3 네이비), router(go_router), env
        ├── data/                 # api_client(OpenAPI 생성/dio), models(camelCase @JsonKey)
        └── features/
            ├── auth/             # → FR-1,2
            ├── scan/             # → FR-3,4,5
            ├── receiving/        # → FR-7,8,12
            ├── registration/     # → FR-6 (LLM 추론·수동폴백)
            ├── initial_setup/    # → FR-13
            └── report/           # → FR-9,10,11
```

### Architectural Boundaries
- **API:** Flutter는 `/api/v1/*` REST만(JWT 베어러). `app/data/api_client.dart` 단일 통로 — 화면 HTTP 직접호출 금지
- **Ports/Adapters:** 라우트·서비스는 Port 인터페이스에만 의존, 벤더 교체는 `adapters/`만 수정(env 스위치)
- **Data:** DB 접근은 `crud/`만. 이미지는 DB 밖(R2), DB엔 key. 입고 기록 soft-delete만
- **State:** Riverpod 프로바이더가 feature별 상태 소유, `AsyncValue`로 로딩/에러 통일

### Requirements → Structure Mapping
- 인증/역할(FR-1,2)=auth · 스캔·매칭(FR-3,4,5)=scan · 신규등록 LLM(FR-6)=registration+services/label_inference · 입고(FR-7,8,12)=receiving · 조회·리포트·엑셀(FR-9,10,11)=report+services/reporting · 초기세팅(FR-13)=initial_setup

### Data Flow (입고 핵심)
```
스캔 → /api/v1/scan → Barcode N:M WineProduct 조회
   ├─ 매칭: 후보 카드 → 사용자 빈티지 확정(WineVintage) → /receiving → 재고
   └─ 미매칭: 라벨 촬영 → /wines → LabelInferencePort(어댑터) → 모델명 초안
              → 사용자 확인·수정 → WineProduct/WineVintage 생성 → /receiving
```

### Integration Points
- 내부: REST(JSON snake_case) + OpenAPI→Dart 클라이언트 자동 계약
- 외부: LLM(Gemini/OpenAI 유료), 카탈로그(LWIN 로컬 1차 + api4ai 슬롯), 스토리지(R2) — 전부 어댑터 뒤
- 배포: Railway(backend Docker + PostgreSQL), Flutter는 APK/스토어 별도

## Architecture Validation Results

### Coherence Validation ✅
- **기술 호환성:** Flutter 3.44 + Riverpod 3.x + mobile_scanner 7 / FastAPI + SQLModel + PostgreSQL + Alembic — 현행 안정 버전, 충돌 없음. Railway가 Docker 백엔드+PG 호스팅.
- **패턴 정합성:** snake_case 와이어 ↔ camelCase Dart 경계가 OpenAPI 생성 클라이언트와 일치. Ports/Adapters가 결정 3-A·`adapters/` 구조에 일관 반영.
- **구조 정합성:** 2계층 모델·N:M 바코드·soft-delete가 `models/`·`crud/` 경계에 매핑.

### Requirements Coverage Validation ✅
- FR-1~13 전부 아키텍처 지원(매핑표: §Project Structure 참조). FR-10 차트·FR-11 엑셀 라이브러리만 구현단계 확정(경미).
- NFR: 매칭 ≤2초(로컬 DB) · LLM 3~5초 비동기+폴백 · 서버중심·무유실(PG+soft-delete) · 모바일 우선 · WCAG AA·폴드(UX+M3) · 5년 보존 · 페이로드 위생·JWT — 모두 지원.

### Implementation Readiness Validation ✅
- 결정에 버전 명시, 패턴·경계·구조가 에이전트 구현에 충분히 구체적. Ports 추상화가 벤더 불확실성(OQ-6·카탈로그)을 흡수.

### Gap Analysis Results
- **Critical(구현 차단): 없음.**
- **Important(비차단, 추적):** ① LWIN·api4ai 한국 커버리지 미검증 — 리서치가 "진짜 임계경로"로 지목, bake-off 실측 필요(제품 리스크). ② 제공자 확정(Gemini vs OpenAI, OQ-6) — POC 비교, 어댑터가 양쪽 지원.
- **Nice-to-have:** FR-10 차트·FR-11 엑셀 라이브러리 확정 / 제품·상업 미결(OQ-1 범위·비용, OQ-3 고객 매칭 데이터, 이카운트 로트원가 문의) — 아키텍처 밖.

### Architecture Completeness Checklist

**Requirements Analysis**
- [x] Project context thoroughly analyzed
- [x] Scale and complexity assessed
- [x] Technical constraints identified
- [x] Cross-cutting concerns mapped

**Architectural Decisions**
- [x] Critical decisions documented with versions
- [x] Technology stack fully specified
- [x] Integration patterns defined
- [x] Performance considerations addressed

**Implementation Patterns**
- [x] Naming conventions established
- [x] Structure patterns defined
- [x] Communication patterns specified
- [x] Process patterns documented

**Project Structure**
- [x] Complete directory structure defined
- [x] Component boundaries established
- [x] Integration points mapped
- [x] Requirements to structure mapping complete

### Architecture Readiness Assessment
- **Overall Status: READY WITH MINOR GAPS** — 16/16 충족·Critical 갭 없음이나, 카탈로그 한국 커버리지 미검증(Important)이 실측 대기라 정직하게 이 상태로 표기.
- **Confidence Level: High.**
- **Key Strengths:** 리서치 근거의 2계층 식별 모델(제품 존재 이유 구조화) · 벤더 격리로 API 소멸 리스크 차단 · 공식 스타터 head start.
- **Areas for Future Enhancement:** 관리자 웹(Next.js), 원가/마진 실사용, 오프라인, 다중창고, api4ai/InVintory 실연동.

### Implementation Handoff
- **AI 에이전트 지침:** 본 문서 결정·패턴·경계 준수. 외부 벤더는 Port 경유. 입고 기록 hard-delete 금지. LLM 결과 무확인 저장 금지.
- **First Implementation Priority:** `backend` 부트스트랩(템플릿 backend + Alembic 초기 마이그레이션: user/wine_product/wine_vintage/barcode/receiving_record) → `flutter create app`(M3 네이비 테마).
