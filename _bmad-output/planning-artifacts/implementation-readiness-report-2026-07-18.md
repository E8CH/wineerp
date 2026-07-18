---
stepsCompleted: [1, 2, 3, 4, 5, 6]
lastStep: 6
status: 'complete'
project_name: 'wineerp'
date: '2026-07-18'
inputDocuments:
  - _bmad-output/planning-artifacts/prds/prd-wineerp-2026-07-15/prd.md
  - _bmad-output/planning-artifacts/architecture.md
  - _bmad-output/planning-artifacts/epics.md
  - _bmad-output/planning-artifacts/ux-design-specification.md
  - _bmad-output/planning-artifacts/research/domain-와인-바코드와-빈티지-식별-wineerp-oq-2-검증-research-2026-07-17.md
---

# Implementation Readiness Assessment Report

**Date:** 2026-07-18
**Project:** wineerp

## Step 1 — Document Inventory

| 문서 | 경로 | 형태 | 상태 |
|---|---|---|---|
| PRD | `prds/prd-wineerp-2026-07-15/prd.md` | whole | final |
| Architecture | `architecture.md` | whole | complete |
| Epics & Stories | `epics.md` | whole | complete (5 epics / 17 stories) |
| UX Design | `ux-design-specification.md` | whole | complete |
| (참조) Domain Research | `research/domain-…-2026-07-17.md` | whole | 근거 |

- **중복(whole+sharded): 없음.** 모든 문서가 단일 whole 파일.
- **누락: 없음.** PRD·Architecture·Epics·UX 모두 존재.

## PRD Analysis

### Functional Requirements (13)
- FR1 직원 가입/로그인 · FR2 관리자 가입/로그인·역할 구분 · FR3 바코드 스캔 · FR4 라벨 촬영 · FR5 매칭·표시(빈티지 후보) · FR6 신규등록(LLM 추론) · FR7 수량·입고완료 · FR8 입고 후 수량수정 · FR9 일/주/월 조회 · FR10 종합 리포트(그래프) · FR11 엑셀 다운로드 · FR12 입고 메모 · FR13 초기 재고 일괄 등록. **Total FRs: 13.**

### Non-Functional Requirements (5)
- NFR1 성능(스캔→결과 2초, 마스터 ~1000종) · NFR2 신뢰성(서버중심·무유실) · NFR3 사용성(한손 연속·최소탭) · NFR4 보안(이메일+비번·해시) · NFR5 LLM 응답성/비용(3~5초·전송정책). **Total NFRs: 5.**

### Additional Requirements
- 플랫폼: 모바일 우선(안드로이드 우선, 크로스플랫폼 지향), 관리자 웹(Next.js)은 본 제품 단계 보류.
- 성공지표: SM-1 검수시간 50% 단축, SM-2 POC 시퀀스 완주, SM-3 바코드↔빈티지 판정. 카운터: SM-C1 등록정확도, SM-C2 LLM 맹신 방지.
- Non-Goals: 판매/유통 상태, 품질검수, 회계/세무, 소비자 대면, 출고차감.
- Open Questions: OQ-1 범위·비용, OQ-2(리서치로 강등), OQ-3 매칭 기준 데이터, OQ-4 권한경계, OQ-5 LLM 정확도, OQ-6 LLM 운영·데이터.

### PRD Completeness Assessment
- PRD는 final 상태로 FR·NFR·성공지표·Non-Goal·리스크·가정 색인까지 완비. **단, 2026-07-17 리서치가 뒤집은 2개 전제(빈티지=비즈니스 요건, 로트≠빈티지)가 PRD 본문에는 미반영** — 아키텍처/에픽이 이를 흡수했으나 PRD-아키텍처 간 표현 불일치가 존재(§Step 5에서 상술).

## Epic Coverage Validation

### Coverage Matrix

| FR | PRD 요구사항 | 에픽/스토리 | 상태 |
|---|---|---|---|
| FR1 | 직원 가입/로그인 | Epic 1 / Story 1.3 | ✓ |
| FR2 | 관리자·역할 구분 | Epic 1 / Story 1.4 | ✓ |
| FR3 | 바코드 스캔 | Epic 2 / Story 2.2 | ✓ |
| FR4 | 라벨 촬영 | Epic 2 / Story 2.3 | ✓ |
| FR5 | 매칭·표시(빈티지 후보) | Epic 2 / Story 2.4 + 2.5 | ✓ |
| FR6 | 신규등록(LLM 추론) | Epic 3 / Story 3.2 | ✓ |
| FR7 | 수량·입고완료 | Epic 2 / Story 2.6 | ✓ |
| FR8 | 입고 후 수량수정 | Epic 4 / Story 4.2 | ✓ |
| FR9 | 일/주/월 조회 | Epic 4 / Story 4.1 | ✓ |
| FR10 | 종합 리포트(그래프) | Epic 5 / Story 5.1 | ✓ |
| FR11 | 엑셀 다운로드 | Epic 5 / Story 5.2 | ✓ |
| FR12 | 입고 메모 | Epic 4 / Story 4.3 | ✓ |
| FR13 | 초기 재고 일괄 등록 | Epic 3 / Story 3.3 | ✓ |

### Missing Requirements
- **없음.** 13개 FR 전부 최소 1개 스토리에 매핑되고 AC가 해당 FR을 충족.
- 에픽에는 있으나 PRD에 없는 FR: 없음(에픽은 PRD FR 집합의 부분집합·재구성).

### Coverage Statistics
- Total PRD FRs: 13 · FRs covered in epics: 13 · **Coverage: 100%**

## UX Alignment Assessment

### UX Document Status
**Found** — `ux-design-specification.md` (status: complete, step 1~14).

### UX ↔ PRD Alignment
- 여정 A(아는 와인 입고)=UJ-1/FR3-5,7 · 여정 B(신규 등록)=UJ-2/FR6 · 여정 C(초기 세팅)=FR13 · 여정 D(관리자 리포트)=UJ-3/FR9-11. **모든 UX 여정이 PRD FR과 대응.** UX에만 있고 PRD에 없는 요구: 없음.

### UX ↔ Architecture Alignment
- Material 3 + 네이비 시드 = 아키텍처 프론트 결정과 일치. 커스텀 컴포넌트 9종이 스토리(2.2·2.4·2.5·2.6·3.2·3.3·4.1·5.1)로 전개됨.
- 성능(스캔→카드 2초, LLM 3~5초 대기 UX) = NFR1/NFR5 및 아키텍처 매칭·Ports 설계와 정합.
- 폴드·반응형·접근성(WCAG AA) = Story 1.5로 흡수.

### Alignment Issues (경미)
1. **UX 내부 잔재:** Visual 섹션 일부에 v1 "마젠타 톤 그래프" 문구가 남음(§Design Implications). 확정 톤앤매너는 v2 네이비 → 리포트 그래프도 네이비/블루(#1766B0) 기준. **구현 시 v2 우선**(문구상 사소한 불일치, 기능 영향 없음).
2. **용어 추상화 차이:** UX는 "와인 마스터" 단일 개념, 아키텍처는 2계층(WineProduct/WineVintage). UX는 사용자 관점이라 충돌 아님 — 화면상 "모델명+빈티지"가 곧 WineVintage. 스토리 AC가 이를 명시해 해소됨.

### Warnings
- 없음(치명적 UX 갭 없음). UI가 제품의 핵심이며 UX 문서가 1급으로 존재.

## Epic Quality Review

### Best Practices Compliance (에픽별)

| Epic | 사용자가치 | 독립성 | 스토리 사이징 | 순방향의존 | DB 적시생성 | AC 명확 | FR 추적 |
|---|---|---|---|---|---|---|---|
| E1 기반·인증 | ✓(로그인) | ✓ | ✓ | ✓ | ✓(users@1.2) | ✓ | FR1,2 |
| E2 아는와인입고 | ✓ | ✓* | ✓ | ✓ | ✓(wine@2.1, receiving@2.6) | ✓ | FR3,4,5,7 |
| E3 신규등록·초기세팅 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | FR6,13 |
| E4 내역·수정 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | FR8,9,12 |
| E5 리포트·보고 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | FR10,11 |

### 🔴 Critical Violations
- **없음.** 기술 계층형 에픽 없음(모두 사용자 가치 축), 에픽 간 순환·역방향 의존 없음, 에픽 크기 스토리 없음.

### 🟠 Major Issues
- **없음.**

### 🟡 Minor Concerns
1. **(E2\*) Story 2.4 AC가 Epic 3를 순방향 참조** — "매칭 없으면 Epic 3 신규등록으로 유도". Epic 2는 시드 마스터로 독립 동작하므로 **요구 의존이 아닌 우아한 훅**. **권고:** Epic 2 단독 빌드 시 미매칭은 "미등록 와인" 안내로 degrade하도록 AC에 폴백 명시(구현 시 반영).
2. **Story 1.1(부트스트랩)·1.2(User 스키마)는 기술 인에이블러 스토리** — 그 자체로 사용자 대면 가치는 없음. 단 그린필드 스타터 스토리로서 **표준 예외**(아키텍처가 스타터 지정 → Epic 1 Story 1 규칙 충족). 별도 기술 에픽으로 분리하지 않아 anti-pattern 아님.
3. **일부 AC가 복수 When/Then 묶음**(예: Story 1.3 가입+로그인+접근유도). 가독성엔 무방하나, 원자적 테스트 위해 dev-story 단계에서 분할 가능. 경미.

### 원자적 검증(그린필드)
- 스타터 셋업 스토리 존재(1.1), CI/CD·배포 조기 배치(1.1), 개발환경(docker-compose) 포함 → 그린필드 베스트프랙티스 충족.

### Remediation
- 위 🟡 3건은 **구현 차단이 아님**. dev-story/스프린트 단계에서 흡수 가능. 별도 에픽 재작성 불필요.

## Summary and Recommendations

### Overall Readiness Status
**READY** — 구현 착수 가능. FR 커버리지 100%, 치명·주요 결함 0건, 경미 3건(비차단).

### Critical Issues Requiring Immediate Action
- **없음.** 계획 산출물(PRD·UX·Architecture·Epics) 정합, 추적성 완비.

### 유의할 비차단 사항 (구현과 병행)
1. **PRD ↔ Architecture 표현 불일치** — PRD 본문은 "바코드 1차 매칭" 전제(리서치 미반영), 아키텍처·에픽은 "빈티지 독립축·2계층·벤더추상화" 전제. 에픽이 아키텍처 기준으로 작성됨. **선택:** 깔끔히 하려면 `bmad-edit-prd`로 PRD 정정, 아니면 아키텍처/에픽을 진실源으로 진행(현재 상태로도 구현 가능).
2. **카탈로그 한국 커버리지 미검증**(리서치가 "진짜 임계경로"로 지목) — 아키텍처가 어댑터로 흡수하나, **bake-off 실측**이 제품 리스크로 남음. Story 2.1(LWIN 시드)·3.1(LabelInferencePort) 구현 전 실측 권장.
3. **제공자 확정(Gemini vs OpenAI, OQ-6)** — 어댑터가 양쪽 지원, POC 비교로 결정.
4. **상업 미결(OQ-1 범위·비용)** — 회장 보고 전 협의(아키텍처/구현 밖).

### Recommended Next Steps
1. **`bmad-sprint-planning`(SP)** — 17개 스토리를 스프린트 순서로 배열해 구현 개시.
2. (선택) **`bmad-edit-prd`** — PRD를 리서치 결론으로 정정해 문서 정합성 확보.
3. (병행·비개발) Gemini 유료 티어 전환, 이카운트 로트원가 문의, 고객사 실물 bake-off.

### Final Note
본 평가는 6개 단계에서 **치명 0 · 주요 0 · 경미 3** 이슈를 식별했다. 경미 이슈는 구현을 차단하지 않으며, 계획 산출물은 구현 착수 준비가 되었다. **Overall: READY.**

**Assessed by:** IR workflow (product-readiness) · **Date:** 2026-07-18
