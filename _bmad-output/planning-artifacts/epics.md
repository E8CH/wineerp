---
stepsCompleted: [1, 2, 3, 4]
lastStep: 4
status: 'complete'
completedAt: '2026-07-18'
inputDocuments:
  - _bmad-output/planning-artifacts/prds/prd-wineerp-2026-07-15/prd.md
  - _bmad-output/planning-artifacts/prds/prd-wineerp-2026-07-15/addendum.md
  - _bmad-output/planning-artifacts/architecture.md
  - _bmad-output/planning-artifacts/ux-design-specification.md
  - _bmad-output/planning-artifacts/research/domain-와인-바코드와-빈티지-식별-wineerp-oq-2-검증-research-2026-07-17.md
project_name: 'wineerp'
user_name: 'HEMICOLON'
date: '2026-07-18'
---

# wineerp - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for wineerp, decomposing the requirements from the PRD, UX Design, and Architecture into implementable stories.

## Requirements Inventory

### Functional Requirements

- **FR1**: 직원은 이메일+비밀번호로 가입·로그인할 수 있다. 미인증 시 스캔·입고 화면 접근이 로그인으로 유도되고, 동일 이메일 중복 가입은 거부된다.
- **FR2**: 관리자는 이메일+비밀번호로 가입·로그인하며 조회·리포트에 접근한다. 역할은 계정에 귀속(staff/manager)되어 로그인 시 해당 역할 화면이 노출되고, 직원은 관리자 전용 리포트 관리에 접근할 수 없다.
- **FR3**: 직원은 카메라로 병의 바코드를 스캔할 수 있다. 스캔 값으로 와인 마스터 매칭을 시도하고, 인식 실패 시 재시도 또는 라벨 사진 흐름으로 넘어간다.
- **FR4**: 직원은 라벨 사진을 촬영할 수 있고, 사진은 서버 저장 후 매칭 결과·입고 기록·와인 마스터에 첨부·표시된다.
- **FR5**: 시스템은 스캔/촬영 입력을 와인 마스터와 매칭해 모델명·빈티지·대표사진을 표시한다. 동일 바코드에 빈티지 복수면 후보 목록을 제시하고 직원이 라벨 기준으로 선택하며, 매칭 실패 시 FR6로 유도한다.
- **FR6**: 매칭 실패 시 직원은 새 와인 마스터를 등록할 수 있으며, 시스템은 LLM이 라벨 사진에서 추론한 모델명을 기본값으로 채운다. 직원이 모델명·빈티지를 수정·확정하며, 저신뢰/실패 시 수동 입력 폴백을 제공한다.
- **FR7**: 직원은 확정된 와인 마스터에 수량을 지정하고 입고를 완료할 수 있다. 완료 시 `와인 마스터 + 수량 + 입고일시 + 담당 직원`으로 입고 기록이 생성되고 입고일시가 자동 기록된다.
- **FR8**: 직원은 등록된 입고 기록의 수량을 수정할 수 있고, 수정은 재고 집계에 반영되며 수정 이력이 남는다.
- **FR9**: 사용자는 입고 기록을 일간/주간/월간 단위로 목록 조회할 수 있다. 기간 선택 시 입고 품목·수량·일시가 사진과 함께 표시된다.
- **FR10**: 관리자는 기간별 입고량·품목 분포를 그래프로 시각화하는 종합 리포트를 볼 수 있다.
- **FR11**: 관리자는 조회·리포트 데이터를 엑셀로 내려받을 수 있다(기간 내 품목·수량·일시·담당자 포함).
- **FR12**: 직원은 입고 기록에 자유 텍스트 메모(비고)를 선택적으로 남기고 수정할 수 있다(빈 값 허용). 저장된 메모는 조회 목록에서 확인된다.
- **FR13**: 작업자는 입고 흐름과 별개로 초기 세팅 모드에서 보유 와인의 바코드와 라벨 사진을 연속 촬영해 와인 마스터를 사전 등록할 수 있다. 등록된 마스터는 이후 입고 시 바코드로 즉시 매칭되며, FR6와 동일하게 LLM 추론/직접입력을 사용한다.

### NonFunctional Requirements

- **NFR1** (성능/규모): 하루 최대 ~100건 입고, 와인 마스터 ~1,000종 검색·매칭에서 스캔→결과 표시가 2초 이내로 동작.
- **NFR2** (신뢰성): 데이터는 서버 중심 저장(단순 로컬 앱 금지). 입고 기록은 유실되지 않는다.
- **NFR3** (사용성): 현장 한 손 조작·연속 스캔 최적화, 최소 탭으로 입고 1건 완료.
- **NFR4** (보안): 이메일+비밀번호 인증, 비밀번호 안전 저장.
- **NFR5** (LLM 응답성/비용): 신규 등록 시 라벨→모델명 추론이 현장 흐름을 끊지 않도록 3~5초 목표, 라벨 사진 외부 전송 시 데이터 정책 준수.

### Additional Requirements

_아키텍처(architecture.md, status: complete) 도출. 리서치(2026-07-17) 근거._

- **AR1** (스타터): 백엔드 = `full-stack-fastapi-template`(FastAPI+SQLModel+PostgreSQL+Alembic+JWT+Docker+CI, React 프론트 제거). 프론트 = `flutter create`(Material 3). → **Epic 1 Story 1**.
- **AR2** (2계층 데이터 모델): `WineProduct`("같은 와인": producer·model_name·region·country·grape·lwin7 nullable) 1:N `WineVintage`(가격결정·재고 단위: vintage **nullable**=NV 1급·lwin11·대표이미지 key). 리서치의 로트≠빈티지 통찰 구조화.
- **AR3** (바코드 N:M): `Barcode` N:M `WineProduct`(조인 테이블). 바코드=producer+wine+size까지만 특정, 빈티지 미인코딩. 스캔→WineProduct 후보→사용자가 라벨로 WineVintage 확정.
- **AR4** (Ports & Adapters): `LabelInferencePort`(GeminiAdapter/OpenAIAdapter, **유료 티어**), `WineCatalogPort`(LwinLocalAdapter 1차 + api4ai 슬롯), StoragePort(R2, EXIF 제거). 라우트·서비스는 Port에만 의존, 벤더 교체는 `adapters/`만.
- **AR5** (역할): User에 `role` enum(staff|manager), `is_superuser` 대체.
- **AR6** (보존): `ReceivingRecord` soft-delete(`deleted_at`)만, 하드삭제 금지, 5년 보존(국세기본법 §85조의3).
- **AR7** (계약): FastAPI 자동 OpenAPI → Flutter Dart 클라이언트 생성. 와이어 JSON snake_case ↔ Dart camelCase 경계 매핑.
- **AR8** (LWIN 시드): `backend/data/lwin/` CSV를 내부 표준키로 로딩.
- **AR9** (배포·시크릿): Railway(backend Docker + PostgreSQL), 이미지 R2. LLM 키는 Billing 활성화(유료), `.gitignore`. LLM 페이로드에 라벨 이미지 외 데이터(PII·매입가) 금지.

### UX Design Requirements

_UX 사양(ux-design-specification.md, status: complete) 도출. 각 항목은 스토리화 가능._

- **UX-DR1** (디자인 토큰): Material 3 + `ColorScheme.fromSeed(딥 네이비 #123E7C)` 테마. 컬러 시스템(Primary/Container/상태색 Success·Warning·Error), 카테고리 컬러 바(네이비·마룬·골드), 화이트/쿨그레이 배경.
- **UX-DR2** (타이포): Pretendard(1순위)/Noto Sans KR, 시인성 우선 큰 스케일(모델명 22, 수량 34 등). OS 텍스트 스케일 대응(textScaler 클램프).
- **UX-DR3** (내비게이션): 하단 4탭(스캔·내역·리포트·재고), 홈=스캔, 완료 후 스캔 자동 복귀.
- **UX-DR4** (ScannerOverlay): 풀블리드 카메라 + 조준 프레임(골드 코너). 상태: 조준/인식성공(햅틱)/실패.
- **UX-DR5** (ReceivingConfirmCard): 병 사진·모델명(22)·빈티지·현재고 배지. 상태: 매칭1건/로딩/취소·재선택.
- **UX-DR6** (QuantityStepper): [−]/숫자(34)/[+] + 키패드 직접입력, 최소 1(− 비활성).
- **UX-DR7** (CandidateList): 빈티지 후보 썸네일 세로 카드, 한 탭 선택(네이비 하이라이트).
- **UX-DR8** (AiInferenceField): 모델명 필드 + "AI 추론" 파란 태그 + 인라인 수정. 상태: 추론중/완료/저신뢰(경고)/수동. 맹신 방지(SM-C2).
- **UX-DR9** (CategoryBar): 정보 그룹 좌측 컬러 바(네이비·마룬·골드).
- **UX-DR10** (SetupModeBanner): 초기 세팅 모드 표시(골드) + 등록 카운터, 명확한 나가기.
- **UX-DR11** (ReportBarChart): 기간별 입고 막대(피크 골드), 빈 상태 대응.
- **UX-DR12** (HistoryRow): 사진·모델명·시간·담당·메모·수량·수정 진입. 상태: 기본/메모있음/수정중.
- **UX-DR13** (피드백 패턴): 성공 SnackBar(그린)+체크+햅틱, 대기 인라인 진행+폴백 상시(차단 모달 금지), 경고 골드 배지, 오류 인라인+복구 액션. 색만 전달 금지→아이콘·라벨 병기.
- **UX-DR14** (반응형/폴드): Compact(≤600dp, 최소 280dp)/Medium/Expanded 분기, 단일 컬럼, 가로스크롤 금지. 갤럭시 폴드 커버(378×927dp)·메인(794×924dp) 대응, resizeableActivity=true + 폴드 전환 시 입고·스캔 상태 보존.
- **UX-DR15** (접근성): WCAG 2.1 AA(본문 4.5:1+), 터치 타깃 48dp+, TalkBack semantic 라벨(스캔·스테퍼·완료·AI 필드), reduce motion 존중.

### FR Coverage Map

- FR1: Epic 1 — 직원 가입/로그인
- FR2: Epic 1 — 관리자 가입/로그인·역할(staff/manager) 구분
- FR3: Epic 2 — 바코드 스캔
- FR4: Epic 2 — 라벨 사진 촬영·저장
- FR5: Epic 2 — 와인 마스터 매칭·표시(빈티지 후보 선택)
- FR6: Epic 3 — 신규 와인 등록(LLM 라벨 추론·수동 폴백)
- FR7: Epic 2 — 수량 지정·입고 완료
- FR8: Epic 4 — 입고 후 수량 수정
- FR9: Epic 4 — 일/주/월 입고 조회(게시판형)
- FR10: Epic 5 — 종합 리포트(그래프)
- FR11: Epic 5 — 엑셀 다운로드
- FR12: Epic 4 — 입고 기록 메모(비고)
- FR13: Epic 3 — 초기 재고 일괄 등록(초기 세팅)

## Epic List

### Epic 1: 기반 구축 & 계정·역할
스타터 부트스트랩·2계층 데이터 모델·M3 네이비 앱 셸 위에서, 직원과 관리자가 이메일+비밀번호로 가입·로그인하고 역할(staff/manager)에 맞는 화면에 진입한다. 이후 모든 에픽의 기반(인증·데이터·내비·테마·배포)을 제공한다.
**FRs covered:** FR1, FR2
**추가:** AR1(스타터), AR2·AR3(2계층 모델+바코드 N:M 스키마), AR5(role enum), AR6(soft-delete 기반), AR7(OpenAPI→Dart), AR9(Railway 배포·시크릿) / UX-DR1·2·3·15(테마·타이포·4탭 내비·접근성 기반)

### Epic 2: 아는 와인 입고 (Scan-to-Receive)
직원이 바코드를 스캔하면 사전 등록된 와인 마스터와 매칭해 확인 카드(사진·모델명·빈티지·현재고)를 띄우고, 빈티지 복수 시 라벨 기준으로 후보를 골라, 수량만 넣고 완료하면 입고가 확정된다. 제품의 정의적 경험(Scan-to-Card). 시연용 마스터 시드로 독립 검증 가능.
**FRs covered:** FR3, FR4, FR5, FR7
**추가:** AR3(바코드 매칭), AR4(StoragePort·이미지 EXIF), AR8(LWIN 시드) / UX-DR4·5·6·7·9·13(스캐너·확인카드·스테퍼·후보목록·카테고리바·피드백)

### Epic 3: 신규 와인 등록 & 초기 세팅
매칭 실패 시 직원이 라벨을 촬영해 LLM 추론 모델명(수정 가능)으로 새 와인 마스터를 즉석 등록하고, 별도 초기 세팅 모드에서 보유 재고를 연속으로 사전 등록한다. 두 흐름은 동일 등록 컴포넌트(AiInferenceField)·LabelInferencePort를 공유하므로 하나의 에픽으로 통합. Epic 2의 매칭 자산을 채운다.
**FRs covered:** FR6, FR13
**추가:** AR4(LabelInferencePort: Gemini/OpenAI 유료·폴백), AR9(페이로드 위생) / UX-DR8·10(AI추론 필드·초기세팅 배너)

### Epic 4: 입고 내역 & 수정
직원·관리자가 입고 기록을 일/주/월 게시판형으로 조회하고, 잘못 넣은 수량을 수정하며(이력 보존), 특이사항 메모를 남기고 관리한다. Epic 2·3이 만든 입고 기록을 다룬다.
**FRs covered:** FR8, FR9, FR12
**추가:** AR6(soft-delete·수정이력) / UX-DR12(HistoryRow)

### Epic 5: 리포트 & 보고
관리자가 기간별 입고량·품목 분포를 그래프로 분석하는 종합 리포트를 보고, 엑셀로 내려받아 회장/오너 보고에 사용한다. POC 데모의 임팩트 산출물.
**FRs covered:** FR10, FR11
**추가:** — / UX-DR11(ReportBarChart)

---

## Epic 1: 기반 구축 & 계정·역할

스타터 부트스트랩·데이터 기반·M3 네이비 앱 셸 위에서, 직원과 관리자가 이메일+비밀번호로 가입·로그인하고 역할(staff/manager)에 맞는 화면에 진입한다. 이후 모든 에픽의 기반을 제공한다.

### Story 1.1: 프로젝트 부트스트랩 & 배포 파이프라인

As a 개발팀,
I want 백엔드·프론트 스타터를 초기화하고 Railway 배포·클라이언트 생성 파이프라인을 세우기를,
So that 이후 모든 기능을 일관된 기반 위에서 구현하고 즉시 배포할 수 있다.

**Acceptance Criteria:**

**Given** 빈 저장소에서
**When** `full-stack-fastapi-template`의 backend를 도입(React 프론트 제거)하고 `flutter create`로 app을 생성하면
**Then** `backend/`(FastAPI+SQLModel+Alembic+Docker)와 `app/`(Flutter M3) 모노레포 구조가 만들어지고 로컬 `docker-compose`로 backend+PostgreSQL이 기동된다.
**And** `/api/v1/health`가 200을 반환하고, Railway에 backend+PostgreSQL이 배포된다.
**And** FastAPI OpenAPI 스키마로부터 Flutter용 Dart 클라이언트가 생성되는 스크립트가 동작한다.
**And** LLM/스토리지 시크릿은 `.env`(유료 티어 전제)로 주입되고 `.gitignore`에 포함되어 커밋되지 않는다.

### Story 1.2: 사용자 데이터 기반 (User + role)

As a 개발팀,
I want User 엔티티와 역할(staff/manager) 스키마·마이그레이션을,
So that 인증과 역할 분기의 데이터 토대가 마련된다.

**Acceptance Criteria:**

**Given** 부트스트랩된 backend에서
**When** User 모델(email·hashed_password·role enum(staff|manager)·created_at)에 대한 Alembic 마이그레이션을 적용하면
**Then** `users` 테이블이 생성되고 `role` 컬럼이 staff|manager만 허용한다.
**And** 템플릿의 `is_superuser` 기반 판정 대신 `role`이 권한의 단일 기준이 된다.
**And** 이메일은 유니크 제약을 가진다.

### Story 1.3: 직원 가입/로그인 (FR1)

As a 현장 검수 직원,
I want 이메일+비밀번호로 가입하고 로그인하기를,
So that 스캔·입고 기능에 접근할 수 있다.

**Acceptance Criteria:**

**Given** 미가입 상태에서
**When** 유효한 이메일+비밀번호로 가입하면
**Then** role=staff 계정이 생성되고 비밀번호는 해시로 저장된다(NFR4).
**And** 동일 이메일로 다시 가입하면 거부된다.
**When** 로그인하면 JWT가 발급되고 이후 요청에 베어러로 사용된다.
**Given** 미인증 상태에서 스캔·입고 화면 접근을 시도하면
**Then** 로그인 화면으로 유도된다.

### Story 1.4: 관리자 가입/로그인 & 역할 분기 (FR2)

As a 관리자,
I want 관리자로 로그인해 조회·리포트에 접근하기를,
So that 현장에서 입고 현황을 파악하고 보고할 수 있다.

**Acceptance Criteria:**

**Given** role=manager 계정으로
**When** 로그인하면
**Then** 관리자 화면(리포트 탭 포함)이 노출된다.
**Given** role=staff 계정으로
**When** 관리자 전용 리포트 관리 API/화면에 접근하면
**Then** 403으로 차단된다.
**And** 역할은 계정에 귀속되어 로그인 시 해당 역할의 내비게이션이 표시된다.

### Story 1.5: M3 네이비 앱 셸 & 접근성 기반 (UX-DR1·2·3·14·15)

As a 사용자,
I want 일관된 테마·내비게이션·접근성 기반의 앱 셸을,
So that 모든 화면이 시인성 높고 한 손으로 조작 가능하다.

**Acceptance Criteria:**

**Given** Flutter 앱에서
**When** `ColorScheme.fromSeed(딥 네이비 #123E7C)` 테마와 Pretendard/Noto Sans KR 큰 타이포 스케일을 적용하면
**Then** 딥 네이비 헤더 + 화이트/쿨그레이 배경 + 하단 4탭(스캔·내역·리포트·재고, 홈=스캔)이 렌더된다.
**And** 모든 인터랙티브 요소는 최소 48dp, 본문 대비 4.5:1+, 색+아이콘 병기, TalkBack semantic 라벨을 만족한다(WCAG 2.1 AA).
**And** Compact(≤600dp, 최소 280dp)/Medium/Expanded 분기와 갤럭시 폴드 커버·메인 레이아웃이 단일 컬럼·가로스크롤 없이 유지되고, `resizeableActivity=true`로 폴드 전환 시 화면 상태가 보존된다.
**And** OS 텍스트 스케일과 reduce-motion 설정을 존중한다.

---

## Epic 2: 아는 와인 입고 (Scan-to-Receive)

직원이 바코드를 스캔하면 사전 등록된 와인 마스터와 매칭해 확인 카드를 띄우고, 빈티지 복수 시 라벨 기준으로 후보를 골라, 수량만 넣고 완료하면 입고가 확정된다.

### Story 2.1: 와인 마스터 스키마 & 시드 (AR2·AR3·AR8)

As a 개발팀,
I want 2계층 와인 식별 스키마와 LWIN·시연용 시드를,
So that 스캔 매칭이 실제 데이터 위에서 동작한다.

**Acceptance Criteria:**

**Given** backend에서
**When** `wine_products`(producer·model_name·region·country·grape·lwin7 nullable), `wine_vintages`(wine_product_id FK·vintage **nullable**·lwin11·representative_image_key), `barcodes`, `barcode_wine_product_link`(N:M) 마이그레이션을 적용하면
**Then** 4개 테이블이 생성되고 vintage는 NULL을 허용하며, 하나의 바코드가 여러 WineProduct에, 하나의 WineProduct가 여러 바코드에 연결될 수 있다.
**And** `backend/data/lwin/` CSV가 내부 표준키로 로딩되고, 시연용 와인 마스터 10종(바코드 포함)이 시드된다.
**And** 바코드 문자열에는 빈티지가 인코딩되지 않는다(연도 파싱 로직 부재).

### Story 2.2: 바코드 스캔 (FR3, UX-DR4)

As a 직원,
I want 카메라로 병 바코드를 조준만 하면 자동 인식되기를,
So that 셔터 없이 빠르게 연속 스캔할 수 있다.

**Acceptance Criteria:**

**Given** 홈=스캔 화면에서
**When** mobile_scanner 기반 ScannerOverlay(풀블리드 카메라+조준 프레임)에 바코드를 대면
**Then** 셔터 없이 자동 인식되고 햅틱 피드백이 발생하며, 인식 값으로 매칭을 시도한다.
**Given** 인식이 실패하면
**Then** 명확한 실패 표시와 함께 재시도 또는 라벨 사진 흐름으로 전환할 수 있다.

### Story 2.3: 라벨 사진 촬영·저장 (FR4, AR4)

As a 직원,
I want 병 라벨 사진을 촬영·저장하기를,
So that 기록·매칭 보정·LLM 추론의 공용 소스로 쓸 수 있다.

**Acceptance Criteria:**

**Given** 스캔/입고 흐름에서
**When** 라벨 사진을 촬영하면
**Then** 이미지가 압축되고 EXIF가 제거된 뒤 StoragePort(R2)에 업로드되며, DB에는 key/URL만 저장된다.
**And** 저장된 사진은 매칭 결과 카드 및 이후 조회에서 표시된다.

### Story 2.4: 매칭 & 확인 카드 (FR5-매칭, UX-DR5·9)

As a 직원,
I want 스캔 즉시 모델명·빈티지·현재고 카드를 보기를,
So that 어떤 품목인지 곧바로 확신하고 수량 입력으로 넘어간다.

**Acceptance Criteria:**

**Given** 시드된 마스터가 있는 상태에서
**When** 등록된 바코드를 스캔하면
**Then** 스캔값→WineProduct→WineVintage 조회 후 ReceivingConfirmCard(병 사진·모델명 22pt·빈티지·현재고 배지·좌측 CategoryBar)가 2초 이내에 표시된다(NFR1).
**Given** 매칭이 없으면
**Then** Epic 3의 신규 등록 흐름으로 유도한다.

### Story 2.5: 빈티지 후보 선택 (FR5-후보, UX-DR7)

As a 직원,
I want 같은 바코드에 빈티지가 여러 개일 때 라벨 기준으로 고르기를,
So that 바코드가 빈티지를 못 나눠도 정확히 확정할 수 있다.

**Acceptance Criteria:**

**Given** 하나의 WineProduct에 복수 WineVintage가 연결된 바코드를 스캔하면
**When** CandidateList(빈티지 후보 썸네일 세로 카드)가 표시되면
**Then** 직원이 라벨 사진 기준으로 한 탭 선택하고(네이비 하이라이트) 선택된 WineVintage로 확인 카드가 이어진다.

### Story 2.6: 수량 지정 & 입고 완료 (FR7, UX-DR6·13)

As a 직원,
I want 수량만 넣고 완료하면 입고가 확정되기를,
So that 한 병을 최소 탭으로 끝내고 다음 병으로 넘어간다.

**Acceptance Criteria:**

**Given** 확정된 WineVintage 확인 카드에서
**When** QuantityStepper([−]/숫자/[+], 최소 1)로 수량을 지정하고 하단 고정 [완료]를 누르면
**Then** `receiving_records`(wine_vintage_id·quantity·received_at·staff_id·memo nullable) 레코드가 생성되고 입고일시가 자동 기록된다.
**And** 성공 SnackBar(그린)+체크+햅틱 후 카메라(스캔)로 자동 복귀한다.
**And** 재고(현재고)에 수량이 반영된다.

---

## Epic 3: 신규 와인 등록 & 초기 세팅

매칭 실패 시 라벨을 촬영해 LLM 추론으로 새 마스터를 즉석 등록하고, 초기 세팅 모드에서 보유 재고를 연속 사전 등록한다.

### Story 3.1: LabelInferencePort & 벤더 어댑터 (AR4·AR9)

As a 개발팀,
I want 라벨→모델명 추론을 벤더 교체 가능한 Port로 격리하기를,
So that Gemini/OpenAI를 스위치하고 외부 API 리스크를 흡수한다.

**Acceptance Criteria:**

**Given** backend에서
**When** `LabelInferencePort`와 GeminiAdapter·OpenAIAdapter를 구현하고 env로 선택하면
**Then** 라벨 이미지 key를 받아 모델명 초안+신뢰도를 반환하는 엔드포인트가 동작하고, 라우트·서비스는 어댑터 구현에 직접 의존하지 않는다.
**And** 호출은 timeout을 가지며 실패/저신뢰는 도메인 결과로 반환되어 수동 입력 폴백이 가능하다.
**And** LLM 페이로드에는 라벨 이미지만 포함되고 거래처 PII·매입가는 포함되지 않으며, 유료 티어 키만 사용한다.

### Story 3.2: 신규 와인 등록 (FR6, UX-DR8)

As a 직원,
I want 미매칭 와인을 라벨 한 장으로 즉석 등록하기를,
So that 긴 와인명을 타이핑하지 않고 새 마스터를 만든다.

**Acceptance Criteria:**

**Given** 매칭 실패 후 "새로 추가?"에서
**When** 라벨을 촬영(필수)하고 [모델검색]을 누르면
**Then** LabelInferencePort가 AiInferenceField(파란 "AI 추론" 태그)에 모델명 초안을 채우고, 대기 중 진행 표시와 [직접입력] 폴백이 상시 노출된다.
**And** 직원이 모델명·빈티지를 수정·확정하면 WineProduct/WineVintage(및 바코드 있으면 링크)가 생성된다.
**And** 저신뢰/실패/[직접입력] 시 수동 입력으로 즉시 폴백되며, 자동 채운 값은 항상 수정 가능하게 표시된다(SM-C2).
**And** 등록 직후 동일 흐름으로 수량 입력·입고 완료로 이어진다.

### Story 3.3: 초기 재고 세팅 모드 (FR13, UX-DR10)

As a 작업자,
I want 보유 재고를 연속으로 사전 등록하는 별도 모드를,
So that 초기 와인 마스터 DB를 구축해 이후 입고를 빠르게 만든다.

**Acceptance Criteria:**

**Given** 초기 세팅 모드에 진입하면
**When** SetupModeBanner(골드)+등록 카운터가 표시되고 바코드 스캔+라벨 촬영을 연속 수행하면
**Then** 각 병에 대해 LLM 추론/직접입력으로 와인 마스터가 등록되고 "등록하고 다음 병"으로 리듬이 이어진다.
**And** 초기 세팅은 마스터 등록 중심으로, 입고 이벤트(receiving_record)와 시각·데이터로 구분되며 선택적으로 보유 수량(재고 기준선)을 입력할 수 있다.
**And** 등록된 마스터는 이후 입고 시 바코드로 즉시 매칭된다.

---

## Epic 4: 입고 내역 & 수정

직원·관리자가 입고 기록을 일/주/월로 조회하고, 수량을 수정하며(이력 보존), 메모를 관리한다.

### Story 4.1: 입고 내역 조회 (FR9, UX-DR12)

As a 직원/관리자,
I want 입고 기록을 일/주/월로 조회하기를,
So that 특정 기간에 무엇이 얼마나 들어왔는지 확인한다.

**Acceptance Criteria:**

**Given** 내역 탭에서
**When** 일간/주간/월간 세그먼트를 선택하면
**Then** 해당 기간 입고 기록이 HistoryRow(사진·모델명·시간·담당·메모·수량)로 목록 표시된다.
**And** 리스트는 스켈레톤 로딩·빈 상태 안내를 가지며 soft-delete된 기록은 제외된다.

### Story 4.2: 입고 수량 수정 (FR8, AR6)

As a 직원,
I want 잘못 넣은 입고 수량을 내역에서 수정하기를,
So that 실수를 되돌려 재고를 정확히 유지한다.

**Acceptance Criteria:**

**Given** 내역의 특정 입고 기록에서
**When** 수량을 수정·저장하면
**Then** 재고 집계에 반영되고 수정 이력이 보존된다.
**And** 입고 기록은 하드삭제되지 않고 soft-delete(`deleted_at`)만 허용된다(5년 보존).

### Story 4.3: 입고 메모 (FR12)

As a 직원,
I want 입고 기록에 선택적 메모를 남기고 수정하기를,
So that 파손·명세서 불일치 등 특이사항을 기록한다.

**Acceptance Criteria:**

**Given** 입고 등록 또는 수정 시
**When** 자유 텍스트 메모를 입력(빈 값 허용)하면
**Then** 메모가 저장되고 내역(FR9) 목록의 해당 기록에서 확인된다.
**And** 저장된 메모는 이후 수정할 수 있다.

---

## Epic 5: 리포트 & 보고

관리자가 기간별 입고를 그래프로 분석하고 엑셀로 내려받아 보고에 사용한다.

### Story 5.1: 종합 리포트 그래프 (FR10, UX-DR11)

As a 관리자,
I want 기간별 입고량·품목 분포를 그래프로 보기를,
So that 회장/오너 보고에 한눈에 보이는 그림을 쓴다.

**Acceptance Criteria:**

**Given** 리포트 탭(관리자 전용)에서
**When** 기간을 선택하면
**Then** ReportBarChart로 기간별 입고 수량·상위 품목 분포가 시각화되고 KPI가 함께 표시된다.
**And** 데이터가 없으면 빈 상태를 표시하며, staff 계정은 이 화면에 접근할 수 없다(403).

### Story 5.2: 엑셀 다운로드 (FR11)

As a 관리자,
I want 조회·리포트 데이터를 엑셀로 내려받기를,
So that 보고 문서에 첨부한다.

**Acceptance Criteria:**

**Given** 리포트/조회 화면에서
**When** [엑셀 다운로드]를 누르면
**Then** 기간 내 입고 품목·수량·일시·담당자가 표로 포함된 엑셀 파일이 생성·다운로드된다.
**And** 파일은 선택된 기간 필터를 그대로 반영한다.
