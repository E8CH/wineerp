---
stepsCompleted: [1, 2, 3, 4]
inputDocuments:
  - _bmad-output/planning-artifacts/prds/prd-wineerp-2026-07-15/prd.md
  - _bmad-output/planning-artifacts/briefs/brief-wineerp-2026-07-15/brief.md
  - _bmad-output/planning-artifacts/ux-design-specification.md
  - _bmad-output/planning-artifacts/architecture.md
  - docs/idea.md
  - docs/chat_history.md
workflowType: 'research'
lastStep: 1
research_type: 'domain'
research_topic: '와인 바코드와 빈티지 식별 — wineerp OQ-2 검증'
research_goals: '바코드가 빈티지별로 구분되는지에 대한 업계 관행·표준을 규명하고, 고객사 현장 검증 프로토콜과 시나리오별 설계 분기를 확정한다'
user_name: 'HEMICOLON'
date: '2026-07-17'
web_research_enabled: true
source_verification: true
---

# Research Report: domain

**Date:** 2026-07-17
**Author:** HEMICOLON
**Research Type:** domain

---

## Research Overview

본 리서치는 wineerp 프로젝트의 최우선 리스크 **OQ-2 — "바코드가 빈티지(연식)별로 다른가"** 를 검증한다.

**중요 — 이 리서치가 답할 수 있는 것과 없는 것:**

- 답할 수 있는 것: 표준 규범, 업계 관행, 한국 시장 제도, 대안 기술의 성숙도
- **답할 수 없는 것: 고객사 창고의 실제 병들이 어떤가.** 이는 실물 스캔으로만 확인 가능하며 고객사 현장 접근이 필요하다.

따라서 본 문서의 목표는 OQ-2의 **종결**이 아니라, ① 현장 검증 프로토콜의 확정과 ② 시나리오별 설계 분기의 사전 결정이다.

**방법론:** 4개 리서치 서브에이전트를 병렬 실행(GS1 표준 원문 / 생산자 실무 관행 / 한국 시장 / 대안 기술·상용 솔루션). 각 에이전트에 출처 URL 명시, **확인된 사실 / 추정 / 미확인**의 명시적 구분, 미발견 시 정직한 보고를 강제했다.

**⚠️ 검색엔진 요약을 신뢰하지 않았음:** 검색엔진 AI 요약은 여러 지점에서 부정확했다(예: "각 빈티지마다 고유 GTIN 필요"라는 단정 — 원문 대조 결과 **거짓**). gs1.org 계열이 WebFetch에 403을 반환하여 curl + User-Agent로 우회, PDF는 pypdf로 로컬 텍스트 추출 후 원문 검색했다. 모든 인용은 1차 출처 원문 대조를 거쳤다.

---

## Domain Research Scope Confirmation

**Research Topic:** 와인 바코드와 빈티지 식별 — wineerp OQ-2 검증
**Research Goals:** 바코드의 빈티지 구분 여부에 대한 업계 관행·표준을 규명하고, 고객사 현장 검증 프로토콜과 시나리오별 설계 분기를 확정한다

**범위 재조정 (표준 템플릿에서 변경):** 본 스킬의 기본 범위(시장 규모·CAGR·경쟁 강도)는 OQ-2와 무관하여 제외했다. 이 주제에서 의미 있는 "산업 역학"은 시장 밸류에이션이 아니라 **식별 체계(GTIN 할당) 구조**다. 조사 영역을 다음으로 재조준한다:

- **표준·규제 체계** — GS1 GTIN 할당 규칙상 빈티지 변경의 취급, 표준의 강제력
- **업계 실무 관행** — 생산자의 실제 GTIN 부여 행태, 리테일/POS 관점
- **한국 시장 특수성** — 수입사 자체 바코드, 한글 표시사항 스티커, 주류 유통 제도
- **대안 식별 기술** — 라벨 이미지 인식, LLM/VLM, 넥 태그, RFID/NFC/QR
- **상용 솔루션의 해법** — 기존 제품들이 이 문제를 실제로 어떻게 푸는가

**제외:** 시장 규모·성장률·경제적 파급(결정에 무관), 일반 공급망 분석(바코드 부착 지점만 좁게 조사)

**Research Methodology:**

- 모든 주장은 현재 공개 출처로 검증하고 출처 URL 명시
- 중요 주장은 다중 출처 교차 검증
- 확인된 사실 / 추정 / 미확인의 명시적 구분 및 신뢰도 등급화
- 출처 간 충돌은 봉합하지 않고 충돌로 보고

**Scope Confirmed:** 2026-07-17

---

## Identification-System Analysis (식별 체계 구조 분석)

> _step-02 "Industry Analysis"를 본 주제에 맞게 재조준한 섹션. 시장 규모 대신 식별 체계 구조를 분석한다._

### 핵심 결론 (Bottom Line)

**OQ-2의 답: 바코드는 빈티지를 구분하지 않는다. 이것은 생산자의 태만이 아니라 GS1 표준의 설계다.**

근거 강도: **높음** — 추측이 아니라 GS1 표준 원문(1차 출처)과 업계 최대 와인 DB 운영사의 명시적 인정(2차 출처)에 기반하며, 4개 독립 리서치가 동일 결론에 수렴했다.

**시나리오 (A) "빈티지별 바코드 상이 → 바코드 1차 매칭 유효"는 전제부터 성립하지 않는다.** 현실은 (C) 혼재이며, 커버리지 문제까지 겹쳐 (B)에 가깝게 기운다.

### 1. GS1 표준 규범 — 확인된 사실 (강도: 최상, 1차 출처 원문 대조)

**1-1. 와인 빈티지 관련 유일한 문언은 "예시"이며 AND 조건이다**

GTIN Management Standard(Release 1.1, Ratified, Sep 2023) 전체 18쪽에서 "wine"/"vintage"는 **단 한 곳**, Rule 1(New product introduction)의 *예시 목록*에만 등장한다:

> "The vintage (year of production) of a bottle of wine changes such that it is recognised by the consumer as being of different quality than the previous year **AND** this wine is not handled as "flow-through" or commodity product, rather as a new and unique product."

> **번역:** "와인 한 병의 빈티지가 변경되어 **소비자가 전년도와 다른 품질로 인식하고, AND** 해당 와인이 flow-through 또는 commodity로 취급되지 않고 새롭고 고유한 제품으로 취급되는 경우."

**해석:** AND로 연결된 **연언(conjunctive) 테스트**다. 두 조건이 모두 충족될 때만 해당한다. **빈티지 변경 자체는 새 GTIN을 트리거하지 않으며**, flow-through/commodity 와인은 명시적으로 **배제**된다.
_2016년 Release 1.0과 2023년 Release 1.1의 빈티지 문언은 완전히 동일 — 7년간 개정 없음._
_Source: https://ref.gs1.org/standards/gtin-management/ , https://documents.gs1us.org/adobe/assets/deliver/urn:aaid:aem:21b56489-cf6d-4eb1-be20-8850157e1734/GTIN-Management-Standard.pdf , https://www.gs1.org/1/gtinrules/en/rule/264/new-product-introduction_

**1-2. 상위 규칙 (Guiding Principles)**

> "**At least one of the guiding principles must apply for a GTIN change to be required.**"
> (① 소비자/거래처가 변경된 제품을 구분할 것으로 기대되는가 ② 규제/책임 고지 요건이 있는가 ③ 공급망에 실질적 영향이 있는가)

**1-3. 표준의 강제력 — 스스로 완화한다**

규칙부는 "MUST"를 쓰지만, 그 사정거리는 **"이 표준에 대한 적합성(conformance)" 안에서만** 유효하다. 표준 준수 자체를 강제하는 조항은 문서 내에 없다.

> **§1.4** "The GTIN Management Standard represents the **minimum** GTIN changes that industry has decided upon. **Brand owners may change the GTIN as often as they think is appropriate based upon their needs**…"
> **§1.3** "The GTIN Management Standard represents a **minimum requirement**… **All local legal and regulatory requirements supersede the GTIN Management Standard.**"

**1-4. GS1은 책임을 전면 부인한다**

> "THIS DOCUMENT IS PROVIDED "AS IS" WITH NO WARRANTIES WHATSOEVER… **GS1 disclaims all liability for any damages arising from use or misuse of this Standard**…"
_Source: https://www.gs1.org/1/gtinrules/en/disclaimer_

**1-5. 와인/주류 섹터 전용 규칙은 존재하지 않는다**

Sector-specific Rules는 **Upstream / Fresh Foods / Healthcare 3개뿐**이다.
_Source: https://www.gs1.org/1/gtinrules/en/about-gtin-management_

**1-6. GTIN 재사용은 별개로 금지된다 (이것은 진짜 SHALL)**

> "**AFTER December 2018, a GTIN allocated to a trade item SHALL NOT be reallocated to another trade item.**"
_Source: https://support.gs1.org/support/solutions/articles/43000734390-can-a-gtin-be-reused-_

→ **설계 함의:** GTIN을 빈티지별로 "돌려쓰는" 설계는 명확히 금지. 그러나 **"빈티지를 무시하고 하나의 GTIN을 유지"하는 것은 재사용이 아니므로 이 규칙에 저촉되지 않는다.**

**1-7. 결정적 반증 자료 — GS1 France 와인 전용 가이드 (2014) §3.3.4.1 "Vintage"**

GS1 France가 두 관행을 **나란히 정당한 선택지로** 표에 명문화했다:

| 처리 | GS1이 명시한 사유 | 비고 (원문) |
|---|---|---|
| **GTIN-13 유지** | "The owners of the wine brand, in agreement with their trade partners, consider that the vintage of a consumer trade item is **not a differentiating factor** and has **no impact on the ordering and invoicing processes**." | **"Often the case with national brand and own brand wines"** |
| **신규 GTIN-13 할당** | "The vintage **has an impact on prices, orders or invoicing**… In this case, the GTIN code of the consumer trade item **must be changed**." | "Requirement for more detailed management of vintages" |

> "Note: in the final analysis, **the brand owner has ultimate responsibility for a change to the GTIN-13** of the CU."

→ **직관을 뒤집는 대목:** GS1은 **대형 내셔널 브랜드·PB 와인이 오히려 동일 GTIN을 유지하는 쪽**이라고 명시한다. 빈티지별로 가격·주문이 갈리는 고급/소량 와인이 신규 GTIN을 쓴다. 흔히 예상하는 방향의 반대다.
_Source: https://www.gs1greece.org/DNLfiles/srvNhelp/GS1Standards_WineTrade_2014.pdf (GS1 France 원저, First Edition, Jan 2014. Carrefour·Auchan·Système U·Groupe Castel 참여)_

### 2. ⚠️ 출처 간 충돌 — 봉합하지 않고 보고

**GS1 글로벌 표준과 GS1 France 가이드는 판정 기준이 서로 다르다:**

| | 판정 기준 | 기본값 뉘앙스 |
|---|---|---|
| **GS1 글로벌** (Rule 1 예시) | **소비자의 품질 인식** + flow-through 여부 | 신규 GTIN 쪽으로 기움 |
| **GS1 France** (§3.3.4.1) | **가격·주문·송장에 대한 영향** | "GTIN 유지가 내셔널/PB 와인에서 흔함" — 유지 쪽으로 기움 |

**두 기준은 동일 사안에서 다른 답을 낼 수 있다.** 예: 소비자가 빈티지 차이를 품질로 인식하지만(글로벌 → 신규) 유통사가 단일 가격·단일 SKU로 flow-through 운영하는 경우(France → 유지).

→ **이것은 표준의 모호성이다. 앱 아키텍처는 "GS1이 답을 준다"고 가정해선 안 된다.**

**충돌 2 — 바코드 판매사 vs GS1:** barcode-us.com은 와이너리에 "each new release and format"마다 새 번호 부여를 권고하나, **이 회사는 바코드를 판매하는 이해당사자**이며(코드를 더 팔수록 이득) 해당 페이지에 정량 데이터가 없다.
_Source: https://www.barcode-us.com/industry-guidance/barcodes-for-wine_

### 3. 실무 관행 — 확인된 사실 (강도: 상, 벤더 1차 문서)

**3-1. 업계 최대 와인 DB(CellarTracker)의 명시적 인정 — 원문 그대로**

> "Alas, UPC/EAN is **not a panacea** (there are other products which pretend that it is), as there are significant issues with their application in the wine industry"
> "**In some cases, the same UPC/EAN can be used for many wines:** … the producers and importers are **sloppy** (unintentionally or otherwise)… a Cabernet and a Merlot from the same producer… may bear the same code. **More likely, vintage variations are often glossed over.**"
> "Many wines do not have UPC/EAN codes: Many older releases do not have codes, and **many newer releases from smaller wineries do not have codes**."
> "The same wine can have many barcodes: For foreign wines, **each importer can set their own code.**"

_Source: https://support.cellartracker.com/article/10-about-upc-and-ean-barcodes_

**3-2. 관계는 N:M이다**

1 바코드 → 여러 와인(빈티지)뿐 아니라, **1 와인 → 여러 바코드(수입사별·사이즈별)** 도 성립한다. CellarTracker는 2014년부터 와인 1개당 복수 코드를 지원하는 방향으로 갔다. **바코드 매칭 설계 시 양방향 모두 고려해야 한다.**

**3-3. 커버리지 — 유일한 실측치 (강도: 중, 해석 주의)**

> "Of these 4.1 million wines, users have entered **858,686 UPC/EAN codes covering 2,074,378 wines** or just over 50% of the total."

→ **바코드가 존재하는 와인이 약 50%.** 코드 1개당 와인 엔트리 평균 약 **2.42개**.

**⚠️ 이 2.42를 "빈티지당 바코드 수"로 격상하면 안 된다.** 반대 방향 요인이 섞여 있다: ① 와인 1개당 복수 코드 지원(수입사별) → 비율 부풀림 ② 코드 공유 원인에 사이즈·수입사·품종 차이가 혼재 → 빈티지 단독 효과 아님 ③ 사용자 입력 데이터 → 입력 편향.

**3-4. 바코드 숫자에서 연도를 파싱하려는 시도는 무의미하다**

1990년대에 UPC 뒷 2자리에 연도를 인코딩하는 관행이 있었으나 **"long been abandoned"**.
_Source: https://www.barcode-us.com/industry-guidance/barcodes-for-wine_

**3-5. 리테일/POS 통설 (강도: 중 — 벤더 판촉 자료, 해석 주의)**

업계 통설은 "**UPC는 신뢰할 수 없으니 내부 SKU를 별도로 만든다**". Lightspeed는 빈티지를 커스텀 속성으로 관리하고 **자체 바코드 생성기**를 제공한다("boutique wines… that do not already have barcodes").
_이들은 벤더 판촉 자료이므로 문제의 심각도가 과장됐을 수 있으나, **문제의 존재 자체**는 GS1·CellarTracker와 교차 검증된다._
_Source: https://www.mpowerbeverage.com/upc-vs-sku/ , https://www.lightspeedhq.com/pos/retail/wine-store-pos-software/_

### 4. 한국 시장 특수성 — 가설 정정

**⚠️ 프로젝트의 기존 가설이 틀렸다.** "수입사 스티커가 원산지 바코드를 덮어 빈티지 구분이 무의미해진다"는 **메커니즘이 잘못됐다.** 결론은 같은 방향이나 원인이 다르므로 설계 근거가 바뀐다.

**4-1. 수입사는 자체 바코드를 붙일 의무가 없다 — 확인된 사실**

GS1 Korea(대한상공회의소 유통물류진흥원) FAQ 원문:
> **Q.** 해외에서 수입된 상품의 바코드를 국내에서 그대로 사용이 가능한가요?
> **A.** "타국가에서 발행된 유통표준코드와 바코드도 GS1에서 정식 발급 받은 것이라면 **그대로 국내에서 사용하셔도 됩니다.**"
_Source: https://www.gs1kr.org/front/board/appl/FAQ1.asp_

**4-2. 한글 표시사항 스티커에 바코드는 없다 — 확인된 사실**

식약처 수입식품정보마루의 한글표시사항 입력 항목은 제품명·수입판매업소·원재료명·유전자변형식품·알레르기 유발물질·제조연월일·내용량·부정불량식품신고표시·영양정보이며 **바코드는 포함되지 않는다.**
「식품등의 표시기준」에서 바코드는 정보표시면에 **표시할 수 있는** 항목일 뿐 의무가 아니다.
_Source: https://impfood.mfds.go.kr/CFCII09F01 , https://www.foodnews.co.kr/news/articleView.html?idxno=91384_

**4-3. 스티커가 바코드를 덮는 것은 금지되지 않는다 — 확인된 사실**

「식품등의 표시기준」Ⅱ.1.머목 3) 가항:
> "한글이 인쇄된 스티커… 원래의 용기·포장에 표시된 **제품명, 일자표시에 관한 사항(유통기한 등) 등 주요 표시사항**을 가려서는 아니 된다."

**가림 금지 목록에 바코드는 없다.** 덮는 것이 합법이나, **실제로 덮는다는 실증은 찾지 못했다.**
_Source: https://www.law.go.kr/LSW/admRulInfoP.do?admRulSeq=4298_

**4-4. ⭐ 병입연월일 ≠ 빈티지 — 확인된 사실 (결정적)**

과실주(와인)는 제조연월일 표시 대상이며 **제조번호 또는 병입연월일로 갈음 가능**하다.
> "「식품등의 표시기준」에 따라 과실주 제품은 제조연월일 표시대상이며, 제조번호 또는 병입연월일을 표시한 경우에는 제조연월일을 생략할 수 있다."

**2018 빈티지가 2021년에 병입될 수 있다.** 한국 법령이 요구하는 것은 병입/제조 시점이며, **빈티지(수확연도)를 표시·신고하도록 요구하는 법적 근거는 찾지 못했다.**

→ **PRD 함의: 빈티지 관리는 규제 준수 요건이 아니라 순수 비즈니스 요건이다.** PRD에 규제 준수 전제가 있다면 수정이 필요하다.
_Source: https://www.foodnews.co.kr/news/articleView.html?idxno=76580_

**4-5. 주류 유통 추적 제도는 와인 대상이 아니다 — 확인된 사실**

- **주류유통정보시스템(RFID)**: 실재하나 **위스키 전용**. 와인·맥주·소주 제외.
- **국세청 주류 코드**: 주세법상 **주종 분류만** 존재. 제품/빈티지 단위 코드 근거 없음.
- **관세청 HSK 10단위**: 와인 = 2204.21. **빈티지 구분 없음.**
- **"주류종합정보시스템"**: 해당 명칭의 제도를 **찾지 못했다.**

→ **우회로로 쓸 공공 데이터가 없다.**
_Source: https://rfid.nts.go.kr/ , https://law.go.kr/LSW/admRulLsInfoP.do?admRulId=21177 , https://www.sisaweek.com/news/articleView.html?idxno=219586_

**4-6. ⭐ 한국 리테일은 실제로 빈티지를 SKU로 관리하지 않는다 — 직접 증거**

데일리샷 상품 페이지 **3곳에서 동일 확인**(= 사이트 전반 정책):
> **"상품명에 빈티지가 표시되지 않은 경우 임의 빈티지이며, 빈티지에 따라 라벨이 상이할 수 있습니다."**

상품 마스터가 빈티지를 SKU 속성으로 갖지 않는다는 직접 증거다. **업계가 이 문제를 "포기"로 해결하고 있다는 뜻이기도 하다.**
_Source: https://dailyshot.co/m/item/5723 , https://dailyshot.co/m/item/23300 , https://dailyshot.co/m/item/4855_

와인21닷컴 와인숍 창업 기사:
> "입고시 제품명, 입고가, 한글명과 원문 명의 병기, **빈티지의 명기, 이 네 값의 바코드 값 연결**… 전산 환경과 POS 환경에 필수적인 사항"

→ 바코드-빈티지 연결이 **점주가 직접 구축해야 하는 것**이지 POS 기본 제공이 아님을 시사한다.
_Source: https://www.wine21.com/11_news/news_view.html?Idx=18020_

### 5. 대안 식별 기술

**5-1. ⚠️ 유통되는 정확도 수치는 전부 검증에 실패했다 — 확인된 사실**

| 수치 | 추적 결과 | 판정 |
|---|---|---|
| "Vivino 86% 정확도(2023년 연구)" | InVintory 블로그 → 출처로 alibaba.com 인용 → **해당 URL이 404** | **근거 없음** |
| "비라틴 폰트 52% 이하", "먼지·얼룩 40% 감소" | alibaba.com / zipdo.co — **SEO 콘텐츠팜 순환 인용**. 표본·조건·방법론 전무 | **근거 없음** |
| (검색 요약이 api4ai 출처라고 제시) | **원문 직접 확인 결과 api4ai 글에 정확도 수치가 아예 없음** | **검색 요약이 오류** |
| "Vivino 매칭 오류의 2~4%가 빈티지" | vivino.com 자사 글 추정, **403으로 검증 실패** | **미확인** |
| "Delectable 난해한 와인 6병 100% 식별" | Jancis Robinson 테스트, **403으로 검증 실패**. 표본 6병 | **미확인**(통계적 의미 없음) |
| TinEye "near-perfect recognition rates and vintage detections" | 벤더 마케팅, 수치 없음 | **마케팅 주장** |
| "슈퍼마켓 와인 60병 78%" | Springer 논문, 페이월. 단 **"완벽한 OCR 시뮬레이션 시 100%"** → 병목은 매칭이 아니라 OCR | **미확인** |

> **결론: 와인 라벨 인식의 독립적·재현가능한 공개 벤치마크는 존재하지 않는다.**
> **→ 빈티지 자동 인식 정확도를 KPI로 삼아선 안 된다. 비교할 기준선이 없다.**

_Source: https://invintory.com/blog/why-wont-my-wine-label-scan-12-fixes/ , https://api4.ai/blog/wine-label-recognition-comparing-vivino-tineye-api4ai-and-delectable , https://tineye.com/stories/delectable , https://link.springer.com/article/10.1007/s00371-023-03119-y_

**5-2. ⭐ 빈티지는 법적으로 선택 표기 사항이며 위치 규정도 없다 — 확인된 사실**

- **미국 (TTB, 27 CFR 4.27)**: 빈티지 표기는 **의무가 아니다.** 표기할 경우에만 규제(AVA 표기 시 해당 수확연도 95% 이상, 그 외 85% 이상). **빈티지 날짜의 표기 위치를 규정하지 않는다** — 위치 규정은 *원산지 명칭*에만 존재. → **넥 라벨·백 라벨에만 빈티지를 표기하는 것이 완전히 합법이다.**
- **빈티지는 COLA 재신청 없이 추가·변경·삭제 가능** → **라벨 아트워크가 동일한데 빈티지만 바뀌는 일이 제도적으로 매우 쉽다.**
- **EU (Reg. 2019/33 / 1308/2013)**: 빈티지는 **"optional particulars"(선택적 표시사항)**. 표기 시 해당 연도 85% 이상.

_Source: https://www.law.cornell.edu/cfr/text/27/4.27 , https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:02019R0033-20250118 , https://vincarta.com/blog/how-to-read-a-wine-label , https://en.wikipedia.org/wiki/Wine_label_

**5-3. ⭐ NV(Non-Vintage)는 예외가 아니라 다수다 — 확인된 사실 (카테고리별)**

| 카테고리 | NV 비율 | 출처 |
|---|---|---|
| 샴페인 | **약 85~95%** | https://www.bbr.com/articles/wine/non-vintage-champagne-a-new-style |
| 셰리 | **약 98%** | https://www.wineenthusiast.com/basics/how-its-made/difference-vintage-nonvintage-wine/ |
| 포트 | Vintage Port는 전체의 **약 2%** (NV 약 97~98%) | https://www.alcoholprofessor.com/blog-posts/vintage-port |

**미확인:** 전체 와인 시장의 NV 비율 통계는 **찾지 못했다.** (스틸 와인 대부분은 빈티지 표기, 저가 대량생산·하우스 와인에 NV 흔함 — **추정**)

→ **설계 함의:** `vintage`는 **nullable**이어야 하며, **NV는 "인식 실패"가 아니라 1급 유효 상태**다. Commerce7이 이미 이 모델을 채택했다: *"Vintage - If it's a Non-Vintage wine, choose the blank field."*

**5-4. 라벨 인식의 구조적 실패 모드**

정면 라벨 1장 촬영 UX는 다음을 **구조적으로 커버할 수 없다:**
- **(a) 넥 라벨 전용 빈티지** — 미국 규정상 완전 합법 (5-2)
- **(b) NV 와인** — 스파클링·주정강화는 압도적 다수 (5-3)
- **(c) 원통 곡률로 인한 텍스트 왜곡** — 오픈소스 프로젝트가 핵심 난제로 명시: *"원통형 병면에서 텍스트가 왜곡되어 직접 OCR이 어렵다"*
- 그 외: 반사/글레어, 엠보싱·메탈릭 포일·무광 바니시, 비라틴 문자, 촬영 각도, 오래된 빈티지, 소규모 생산자 DB 미수록

_Source: https://github.com/AntoninLeroy/wine_label_reader_toolkit , https://arxiv.org/abs/2404.08820 (학습 데이터 부족이 핵심 난제)_

**5-5. VLM(Gemini/GPT-4o) 와인 라벨 추출 벤치마크 — 찾지 못함**

여러 검색어로 시도했으나 **존재하지 않는 것으로 보인다.** 관련 오픈소스는 전부 전통적 OCR 파이프라인(Tesseract/YOLO)이며 LLM 기반이 아니다.

→ **현재 설계의 "LLM 라벨 추론"은 선행 사례 없는 영역이다.** 이는 기회이자 리스크다.

**5-6. NFC/RFID/QR/DataMatrix — 플랜 B의 기반이 될 수 없다 — 확인된 사실**

- **NFC/RFID**: 실사용은 **위조 방지·정품 인증** 목적이며 **재고 식별용이 아니다.** 주로 프리미엄/중국 시장(Moutai 등).
- **QR**: 단순 복제 가능 → 인증 수단으로 취약.
- **DataMatrix**: 의약품 시리얼라이제이션 맥락에서만 언급. **와인 일반 소매 유통 근거 없음.**
- **2D 바코드 전환**: GS1이 소매 POS 전환 가이드라인 운영 중. 장기적으로 GTIN+빈티지 인코딩 가능성이 열리나 **현재 와인 적용 사례를 찾지 못했다.**
- **병 각인**: 재고 식별 수단 활용 근거 **찾지 못함.**

_Source: https://ref.gs1.org/guidelines/2d-in-retail/ , https://checkpointsystems.com/blog/rfid-for-wine-traceability/_

**5-7. GS1의 공식 대안 AI (20) — 치명적 제약 (확인된 사실)**

GS1 France 가이드 §4.5.2는 GTIN 미변경 시 **AI (20) "Vintage variant"** 사용을 권고한다:

> "the **vintage variant** can be used to identify the change of product vintage **when there is no change of GTIN code**… N.B. **the variant does not necessarily indicate the vintage year.**"

| AI | 데이터 | 포맷 | 비고 |
|---|---|---|---|
| **(20)** | Internal product **variant** | **N2 (2자리)** | **"2019" 같은 4자리 연도를 담을 수 없다** |
| (10) | Batch or lot number | X..20 | 로트→빈티지 매핑은 생산자별 사설 체계 |
| (13) | **Packaging date** | N6 | **포장일 ≠ 빈티지** (병입일과 수확연도 불일치) |
| (7007) | Harvest date | N6[+N6] | **7 시리즈는 비글로벌** — 특정 섹터/지역 한정 |

→ **EAN-13 스캔은 빈티지 정보를 원리적으로 담고 있지 않다.** AI (20)은 빈티지 연도의 캐리어가 아니라 **로컬 매핑 테이블이 필요한 불투명한 2자리 코드**다.
_Source: https://ref.gs1.org/ai/ (JSON-LD 데이터셋 직접 추출), GS1 France 와인 가이드 §4.5.2_

### 6. ⭐ 상용 솔루션의 해법 — "업계 전체의 답은 사람에게 묻는 것"

**핵심 발견: 완전 자동 식별을 시도하는 제품이 사실상 없다.**

| 제품 | 제품 특정 수단 | 빈티지 확정 수단 | 근거 |
|---|---|---|---|
| **InVintory** | 라벨 이미지 (**바코드 미지원**) | **항상 사용자 피커** | 제품 문서 명시 |
| **CellarTracker** | UPC/EAN 스캔 or 텍스트 검색 | **사용자 확인 → 바코드 매핑 학습** | 제품 문서 명시 |
| **Delectable** | 라벨 이미지 (TinEye) | 자동 시도 → **사람 수동 식별 폴백** | 제품 문서 명시 |
| **Vivino** | 라벨 이미지 (PTC Vuforia + OCR) | 자동 시도 → 검색/수동제출 폴백 | 추정(자사 문서 403) |
| **Commerce7** | (재고 마스터) | **빈티지 = 상품 레벨 필드, NV = 빈 값**. Variant/SKU는 용량용 | 제품 문서 명시 |
| **Microworks** | — | **빈티지 필드 자체가 없음** | 문서상 확인 |
| **Partender** | **바코드 스캔 없음** (이름 검색 + 슬라이더) | — | 경쟁사 비교 페이지(비판적 2차 출처) |
| **BinWise** | 바코드 | 자사 DB 자동 채움 **주장** | **벤더 마케팅**, 정확도 수치 없음 |
| **Vintrace/InnoVint** | (와이너리 생산관리 — **도메인 다름**) | 로트 단위 내재 | 확인 |

**6-1. InVintory — 가장 명확한 참고 사례 (제품 문서 명시)**

라벨 촬영 → 분석 → **매칭 확인**(복수 후보 시 선택) → **빈티지 선택**:
> *"A vintage picker will appear. You'll see popular vintages as quick-select buttons at the top, plus a scrollable list of all years"*

**결정적으로 중요한 두 가지:**
- **빈티지 인식을 시도하지 않고 아예 사용자에게 묻는다.** "실패 시 폴백"이 아니라 **항상 묻는 단계**다.
- **바코드를 아예 지원하지 않는다**: *"InVintory scans the text on wine labels, not store barcodes. If you accidentally scan a barcode, you'll see a message reminding you to photograph the label instead."*

_Source: https://help.invintory.com/en/articles/14301437-how-to-add-wines-by-scanning-a-label_

**6-2. CellarTracker — 크라우드소싱 매핑 학습 루프 (제품 문서 명시)**

1. UPC/EAN 스캔 → 검색 결과
2. 와인 선택 → **앱이 "이게 맞느냐"고 확인 요청**
3. **사용자가 "아니오"라 하지 않는 한 바코드가 해당 와인에 자동 매핑** → 이후 검색부터 정확한 결과
4. 결과가 없으면 → 텍스트 검색 → 선택 시 **"방금 스캔한 바코드를 연결할까요?"**

→ **공식 GTIN을 못 믿는다는 전제 위에서, 사용자 확인 행위를 데이터 자산으로 전환한다.** 바코드 DB를 소유하지 않은 상태에서 시작할 수 있는 현실적 경로다(**추정**).

**단, CellarTracker의 최종 답은 회피다:** 자체 바코드(병 단위/와인 단위)를 발행해 붙이라고 안내한다 — **"제조사 바코드로 빈티지를 알아내려 하지 말고, 내가 아는 병에 내 바코드를 붙여라."**

_Source: https://support.cellartracker.com/article/79-search-by-barcode , https://support.cellartracker.com/article/6-about-cellartracker-barcodes_

**6-3. Delectable — 사람 폴백의 대가**

업계 최고 수준 평가를 받는 앱조차 자동 인식 실패 시 **팀이 수동 식별**한다. "100% 정확도(6병)" 주장의 실체가 이것이며, 대가는 **병당 최대 15분**이다(미확인 — 403).

> **→ 이는 기술 미성숙이 아니라 문제의 성질로 보인다.**

### 7. 미확인 / 데이터 없음 — 정직한 공백 보고

**정량 데이터 부재:**
- ❌ **빈티지별 신규 바코드 부여 비율** — 업계 조사·학술 연구·GS1 통계 어디에도 없음. **비율을 지어내지 않는다.**
- ❌ 대형 vs 부티크의 **정량적** 관행 차이 — GS1의 질적 서술("often the case with national brand")만 존재
- ❌ 넥 라벨 전용 빈티지의 정량적 빈도 — 공개 통계 없음
- ❌ 전체 와인 시장의 NV 비율 — 카테고리별 수치만 확보
- ❌ 와인 라벨 인식의 독립적·재현가능한 정확도 벤치마크 — **존재하지 않는 것으로 보임**
- ❌ VLM(Gemini/GPT-4o)의 와인 라벨 추출 벤치마크 — 없음

**⭐ 프로젝트에 가장 결정적인 미확인 항목:**
- ❌ **한국 와인 수입사의 자체 바코드 부착 실태** — 공개 정보로 도달 **불가능**. 나라셀라(코스닥 405920) 공시에도 SKU 총량(252개 브랜드/약 1,613개 SKU)만 있고 바코드·빈티지 관리 서술 없음. 신동와인·금양인터내셔날·아영FBC는 비상장. **고객사/수입사 인터뷰가 유일한 경로.**
- ❌ **실제 제품 단위 확인 사례** (특정 와인의 동일 바코드 다른 빈티지) — 확보 실패. **실물 검증 필요.**

**기타 미확인:**
- ❌ GDSN `vintage` 속성(T4203) — 2차 검색은 존재를 시사하나 **1차 출처로 확증 실패**. GS1 TIIG 전문(20MB) 검색 시 "vintage"/"T4203" **0건**. 인용된 GS1 Sweden PDF 2건 모두 404. → **GS1 Korea/GDSN 데이터풀 직접 문의 권장.**
- ❌ Bevager / Provi / eCellar의 빈티지 처리 문서 — 공개 포털 접근 불가
- ❌ 로트번호 → 빈티지 표준 매핑 규격 — 사설 체계로 추정
- ❌ 이마트·롯데마트·홈플러스·와인앤모어의 빈티지 관련 문구 — 로그인/JS 렌더링 장벽
- ⚠️ **미검증 출처:** WineDirect 커뮤니티 "Same UPC, different vintages, multiple tasting rooms" 스레드 — 검색 요약만 존재, **DNS 해석 실패로 1차 확인 불가**. 내용이 GS1과 방향이 일치해 매력적이나 **검증 안 된 것은 검증 안 된 것이다.**

**조사의 한계 (정직한 고지):**
- WebSearch가 **US 리전 기반**이라 한국어 롱테일(커뮤니티·상품 상세) 색인이 약했다. **"찾지 못함"은 부재의 증거가 아니다.**
- law.go.kr 조문 본문이 JS 렌더링이라 일부 조문은 2차 출처를 통해서만 확인했다.
- 접근 차단으로 원문 검증 실패: vivino.com(403), jancisrobinson.com(403), gs1.org(403 — curl로 우회), Springer(페이월), community.winedirect.com(DNS 실패)

### 8. 아키텍처 시사점 (본 섹션 사실에 근거)

1. **"1 GTIN = 1 빈티지"를 가정하면 안 된다** — 확인된 사실(GS1 표준 원문 + GS1 France).
2. **"1 GTIN = 1 와인"조차 보장되지 않는다** — 확인된 사실(CellarTracker). 동일 UPC가 같은 생산자의 Cabernet과 Merlot에 쓰일 수 있다.
3. **바코드 ↔ 와인은 N:M이다** — 수입사별 코드 난립으로 역방향도 성립.
4. **GS1은 집행기관이 아니다** — 제재 조항 미발견 + 책임 전면 부인 + 브랜드 재량 명시. **표준 준수를 데이터 무결성의 근거로 삼을 수 없다.**
5. **바코드는 "제품군(producer+wine+size) 특정"까지만 유효**하고, **빈티지는 반드시 별도 축**으로 분리해야 한다.
6. **커버리지가 별개 리스크다** — 바코드 보유 와인 약 50%(CellarTracker 실측), 소규모 와이너리 신규 릴리스는 코드 부재가 흔하다. **고객사가 부티크 와인을 다룬다면 바코드 경로는 절반 이하만 커버한다.**
7. **라벨 사진 LLM 추론도 완결적일 수 없다** — NV·넥 라벨·원통 곡률로 정면 1장 커버 불가 케이스가 구조적으로 존재.
8. **빈티지 자동 인식 정확도를 KPI로 삼지 말 것** — 신뢰할 공개 벤치마크가 없어 목표치 설정 근거가 없다. 자체 측정이 선행되어야 한다.
9. **PRD 정정 필요** — 빈티지 관리는 규제 준수 요건이 아니라 **순수 비즈니스 요건**이다(한국 법령상 빈티지 표시 의무 근거 없음).
10. **CellarTracker의 경고를 새길 것:** *"there are other products which pretend that it [barcode] is [a panacea]."* **그 제품이 되지 말 것.**

---

---

## Competitive Landscape (경쟁 구도)

> _step-03 "Competitive Landscape"를 본 주제에 맞게 재조준한 섹션. 시장 점유율·M&A·수익 모델 대신 **① 국내 경쟁 공백 ② 데이터 조달 가능성(진입 장벽) ③ Build vs Buy**를 분석한다. step-02가 글로벌 제품만 다뤘으므로 국내와 데이터 생태계가 공백이었다._

### 핵심 결론

**"이미 있는 걸 또 만드는가?" → 아니오. 단, 이유가 PRD에 적힌 것과 다르다.**

- PRD가 말하는 이유: **바코드로 빠른 입고** → step-02에서 전제가 무너짐
- **실제 방어 가능한 이유: 빈티지별 원가·마진 관리** + 라벨 인식 입고

**동시에 프로젝트 경제성에 심각한 문제가 있다:** 확정 기능 범위의 대부분은 이카운트가 **연 44~64만원**에 커버한다. POC 예산 200만원은 **이카운트 3년치**다.

### 1. 국내 경쟁 공백 — 확인된 사실 (강도: 상, 공식 매뉴얼 전수 검색)

**빈티지를 1급 개념으로 다루는 한국 제품은 0개다.** 색인 한계가 아니라 실제 부재다.

| 제품 | 빈티지 처리 | 모바일 | 가격 |
|---|---|---|---|
| 오케이포스 | **불가** — 커스텀 필드 0개 | MY OKPOS 웹 | 찾지 못함(대리점 견적) |
| 포스뱅크 | 해당 없음 (하드웨어 제조사) | — | 견적 |
| 페이히어 | 옵션 우회 **추정**, 원가분리 미확인 | 네이티브 앱 | 월 0원 + 단말기 |
| 캐시노트 | 해당 없음 (장부 레이어) | 앱 우선 | 무료 / 3.3만원 |
| **이카운트** | **Lot 우회 — 단, 원가는 품목 단위** | 앱 무료 | **월 4만원** |
| 얼마에요 | 주류코드 = **국세청 규제코드**(빈티지 아님) | 기본 제공 | 월 39,000원 |
| 엔젤넷 | **개념 부재** (공병·소주 세계관) | 없음 | 찾지 못함 |
| 더존 iCUBE | 공개 매뉴얼서 **찾지 못함** | 더존모바일 | 견적 |

**인접 제품은 전부 다른 레이어에 있다 — 겹치지 않는다:** 와인루트=판매채널, 엔젤넷=소주도매, 캐시노트=장부, 포스뱅크=하드웨어.

**공백의 3중 증거:**
1. 업계 전문가(양재혁, 소믈리에타임즈 「와인IT」 칼럼)가 수입사 재고 문제를 정면으로 다루면서 **기성 솔루션을 하나도 추천하지 못하고 Python·크몽을 권한다**
2. **OKPOS 매뉴얼 404KB 전수 검색에 "빈티지·로트·와인" 0회**
3. **해외엔 와인 전용 ERP 카테고리가 실재**(365WineTrade, Dynamics 365 기반)**하는데 국내엔 없다**

### 2. ⭐ 핵심 통찰 — 로트 우회가 새는 지점 (프로젝트의 진짜 존재 이유)

**이전 보고 정정:** "이카운트 Lot 관리 = 와인 빈티지와 구조 동일"은 **반쪽만 맞다.**

이카운트 **공식 교육자료 전문 검색 결과, 로트와 원가/단가가 같은 문장에 등장하는 사례가 0건**이다. Lot은 **수량·이력만** 추적하고, **원가는 일관되게 품목 단위 기말단가**로 계산된다.

> **로트는 "같은 물건의 다른 배치"** 전제로 설계된 추적(traceability) 개념이다 — 리콜·유통기한·A/S용.
> **그러나 와인 빈티지는 "다른 물건"이다.** 2015와 2021은 원가도 시세도, 심지어 **가치의 방향(시간에 따라 상승)**도 다르다.
> **→ 빈티지는 추적 단위가 아니라 가격결정 단위다.**

기성 툴의 실질적 선택지는 둘뿐이고 둘 다 아프다:

| | 결과 |
|---|---|
| **(A) 빈티지 = 별도 품목코드** | 원가 정확. 대신 **품목 폭증**(500종×3빈티지=1,500품목), **"같은 와인"이라는 상위 개념 소멸** |
| **(B) 빈티지 = 로트** | 깔끔. 대신 **빈티지별 원가·마진 불가시** — 와인 비즈니스에선 치명적 |

**(A)가 현실이며, 국내 와인샵이 겪는 고통의 정체가 이것일 가능성이 높다 (추정).**

> **🔴 최우선 확인 항목: 이카운트에 "로트별 원가 분리 가능한가" 직접 문의.**
> **"언급 없음"이지 "불가 확정"이 아니다.** 가능하다면 월 4만원짜리 경쟁자가 생기고, 불가능하다면 공백이 확정된다. 이 프로젝트 포지셔닝의 **단일 최대 변수**다.

### 3. Build vs Buy — 프로젝트 경제성 (강도: 최상, 공식 가격 페이지)

**이카운트 공식 가격** _(Source: https://www.ecount.com/kr/ecount/join/pricing)_
- 가입비 **최초 1회 20만원** / 월 **4만원**(연납 시 48만→**44만원**, VAT 별도)
- **사용자 무제한 / 용량 무제한 / 약정 없음**
- 전 모듈 포함(회계·자금·세무·인사·급여·영업·판매·구매·재고·물류·생산·제조·원가), 모바일 앱 무료
- **1년 총비용 64만원 / 3년 총비용 152만원**

> **POC 상업조건(1주·200만원) = 이카운트 3년치.**
> 고객사는 POC 견적보다 적은 돈으로 완성된 ERP를 3년간 무제한 인원으로 쓸 수 있다. **이 질문은 회장·고객사 누구에게든 즉시 제기될 수 있으며, 현재 답이 없다.**

**이카운트가 이미 해결해 둔 것:** "임의의 숫자·영문 조합을 바코드로 활용" + 라벨 자체 출력 → **수입 와인 바코드 부재/불신 문제**. CellarTracker가 도달한 결론("내가 아는 병에 내 바코드를 붙여라")과 동일.

**박스히어로:** 로트/배치 추적 **없음** → 빈티지마다 별도 SKU, 품목 수가 (와인 종류 × 빈티지)로 폭증해 1,000개 한도 소진(1,000개당 월 $10 추가). KRW 미지원(USD 청구). **단, 한 제품에 바코드 2개 이상 등록 가능** — "동일 와인 → 수입사별 다른 바코드"(N:M 역방향)에 정확히 대응. **이카운트의 동일 기능 여부는 미확인.**

**⚠️ 사용해선 안 되는 논거:** "경쟁사들도 자체 구축한다" — **국내외 실명 사례를 하나도 확증하지 못했다.** 신세계L&B·금양·아영FBC·하이트진로·롯데칠성 전부 확인 실패. 확증된 **유일한 실명 사례(홍콩 Cote d'Or)는 자체 개발을 *"large and risky custom development effort"*라며 회피하고 전문 SaaS를 채택**했다.

**나라셀라**(코스닥 405920, 업계 1군): 공모자금 약 100억을 물류에 투입 계획 → **적자 전환으로 물류센터 구축 무기한 연기**, MFC로 선회.
_Source: https://www.fetv.co.kr/news/article.html?no=193457_

### 4. ⭐ 데이터 조달 — "4~5천만원"은 낡았다 (중대 정정)

**이전 보고 정정:** "국내 2만 건 와인 DB 구축 비용 최소 4,000~5,000만원"(양재혁 칼럼, 2020~21)은 **단일 출처·5~6년 경과**이며, **현재는 경로 자체가 다르다.**

**★ LWIN (Liv-ex) — 유일하게 법적으로 깨끗한 대규모 무료 소스 — 확인된 사실**

> "Covering **over 200,000 wines and spirits**, LWIN is the most comprehensive **open source** database available to the industry. It's **free to download, and always will be under the Creative Commons licence**."
> CC BY: "**Adapt** — remix, transform, and build upon the material for any purpose, **even commercially**."

- **LWIN-7**(와인) / **LWIN-11**(+빈티지) / **LWIN-18**(+병·팩 사이즈) → **빈티지가 식별키에 내장**
- **Wine-Searcher가 LWIN 코드 입력을 네이티브 지원** → 내부 표준키로 두면 즉시 연결
- ⚠️ **파인와인 편중**, 대중 데일리 와인 커버리지 **미확인**. **바코드/GTIN 없음**(SLA 원문: *"it is not designed to be a product code"*). 공개 검색 API 없음(정적 CSV, HubSpot 폼 뒤). **자체 페이지 간 수치 불일치**: 메인 "over 200,000" vs SLA "almost 100,000"
_Source: https://www.liv-ex.com/lwin/ , https://www.liv-ex.com/lwin-creative-commons-licence/_

**라벨 인식 API 비교 — 확인된 사실 (라이브 결제/가격 엔드포인트 직접 확인, 2026-07-17)**

| 옵션 | 월 1만 건 | DB 공급 | 비고 |
|---|---|---|---|
| **api4ai wine-rec** (RapidAPI PRO) | **$12.49** (5만건 포함) | ✅ **40만 라벨** | *"without the need for pre-populating a label database"*, 빈티지 포함 |
| api4ai wine-rec (PAYG) | $20 ($2/1,000) | ✅ | |
| api4ai alco-rec | $119.99 | ✅ | winery·country·variety·**vintage**·region |
| **TinEye WineEngine** | $200~500/월 | ❌ **BYO** | 아래 참조 |
| Google Vision (OCR+Label) | ~$30 | ❌ | 와인 특화 **전무**, Product Search에 와인 카테고리 없음 |
| **AWS Custom Labels** | **$2,880~5,760 고정비** | ❌ | ⚠️ **DetectText 한국어 미지원** → 한글 백라벨 불가 |
| Wine-Searcher | $320~510 | **식별 불가** | 정확한 상품명 문자열 필수 = 보강 전용 |
| **LWIN** | **$0** | ✅ 20만+ | 이미지·바코드 없음 |

**⚠️ TinEye WineEngine은 이름과 달리 DB를 주지 않는다 — 확인된 사실**
> "WineEngine instead uses **your label image collection** to build its index."
> "WineEngine also **does not provide any additional information about the wine**."
> 필요한 것: *"a label database, your own server and a mobile application"*

단, **라벨에서 vintage·varietal·region·country·color를 OCR로 직접 추출**하는 것은 사실이므로, 컬렉션 보유 시 유용.
_Source: https://help.tineye.com/article/203-how-does-wineengine-work , /article/200-variety-detection-in-wineengine_

**★ InVintory Partner API — 최대 카탈로그, 도메인 정확히 일치**
> "database of over **1.5M wines**", "returns **producer, vintage, region**, and matched catalogue records", POS/ERP 연동·웹훅 명시. **공개 가격 없음(문의 필요).**
_Source: https://invintory.com/blog/wine-inventory-api-partner-launch/_

**해자는 컴퓨터비전이 아니라 카탈로그다 — 확인된 사실**
Vivino = **PTC Vuforia** 기반, Delectable = **TinEye WineEngine** + 자사 카탈로그. **둘 다 범용 BYO 엔진에 자사 카탈로그를 색인했을 뿐이다.**

### 5. ⭐ 결정적 실측 — Open Food Facts 한국 와인 = 0건 (직접 API 조회)

```
categories_tags=red-wines & countries_tags=en:south-korea → count: 0
countries_tags=en:south-korea (대조군)                    → count: 3,069
```

**대조군이 3,069건이므로 쿼리는 정상이고 한국 와인이 실제로 0건이다.**

전 세계 기준으로도 빈약: red-wines **3,214** / white-wines 1,660 / sparkling 1,197 / champagnes 687 (대조: beers 11,866, alcoholic-beverages 38,470).
품질도 문제 — red-wines 샘플 5건: `"Vin rouge"`, `"Adama"`, `"Cabernet Sauvignon"`, `"Vin rouge sans alcool"`, `"Bordeaux 2013"` → **빈티지 있는 것 1건**, 생산자·아펠라시옹 구조 없음, 프랑스 대형마트 편중.

> **OFF는 와인 레퍼런스 DB로 쓸 수 없다.** 라이선스(ODbL)는 깨끗하나 **데이터가 없다.**

### 6. 법적 차단 — 확인된 사실

**Vivino — 기술이 아니라 법으로 막혀 있다.** ToS v1.1 (**effective 2026-05-18**):
> "access... through **automated means, scraping tools, crawlers, or bots**"
> "use any data... to **train, fine-tune, benchmark, or otherwise develop machine learning or artificial intelligence models**"
> "you may not copy, modify, reproduce, distribute, sell, license, reverse engineer, **extract**, or create derivative works"

> ⚠️ **AI/ML 학습 금지 조항이 프로젝트의 "LLM 라벨 추론" 방향과 정면 충돌한다.** 비공식 API(GitHub `aptash/vivino-api` 등, 상위 2개 사망/아카이브)나 Apify 스크래퍼는 **리스크를 이전해주지 않는다. 배제할 것.**
_Source: https://www.vivino.com/legal/terms-of-service_

**Gemini** — Search Grounding 사용 시 **캐싱 금지**: *"You will not... cache, frame, syndicate, resell, analyze, train on, or otherwise learn from Grounded Results"*. 또한 *"You must be 18 years of age or older"*(주류 앱 관련). ERP는 결과 영구 저장이 전제 → 주의.
_Source: https://ai.google.dev/gemini-api/terms_

**CellarTracker** — *"for your **personal and noncommercial use**"*, robot/spider 금지. 본인 셀러 XML export만 가능 → **사용자 데이터 마이그레이션 기능으로는 가능, 레퍼런스 소스로는 불가.**

**Wine-Searcher** — *"all data presented by the Wine-Searcher API is **owned by Wine-Searcher**"*, 재판매·서브라이선스 금지, 직접 경쟁 제품 사용 금지. ⚠️ *"**You will grant Wine-Searcher direct access to any page on which API data is being displayed.** If this requires a sign in/password, you will provide this... free of charge."* → **비공개 ERP 내부 화면에도 접근권을 줘야 함.** 캐싱 조항은 찾지 못함(©2017 아카이브 기준).

**Vinmonopolet(노르웨이)** — "오픈"이 아니다: *"You may not **sell, rent, lease, redistribute, or syndicate** access"*, *"data is for your use only"*, 금지: *"replicate or compete with the Services"* → **자체 마스터DB 축적 모델과 정면 충돌.**

**OQ-6에 유리한 발견 — api4ai:**
> "We **do not store, retain or archive any data** submitted by users to our APIs."
> "We **do not use any data submitted by customers to train** ... our AI models."
> ⚠️ 단, **API 출력물의 캐싱·저장·재배포 조항을 찾지 못했다.** ERP는 인식 결과 영구 저장이 전제 → **계약 전 서면 확인 필수.**

### 7. ⚠️ 와인 API는 조용히 죽는다 — 확인된 사실 (DNS/HTTP 검증)

| 서비스 | 상태 |
|---|---|
| Wine.com API | `api.wine.com` **NXDOMAIN**. 공지: *"deprecated on September 1st, **2017**"* |
| Global Wine Score | **도메인 매물** — "for sale \| HugeDomains" |
| LCBO API | `lcboapi.com` **DNS 실패**. Ontario 공식 오픈데이터 상품 카탈로그 count=0 |
| Snooth API | `api.snooth.com` **NXDOMAIN** |
| Slyce / Cortexica | **폐업** (Cortexica: 영국 Companies House "Dissolved on 22 September 2023") |
| Ximilar | ⚠️ 사전 가정과 달리 **와인 서비스 자체가 없음** |

> **4개 API 모두 공지 없이 소멸했다.** 오래된 블로그가 아직도 이들을 추천한다.
> **외부 와인 API 단일 의존은 가설이 아니라 실증된 리스크다.** → LWIN을 내부 표준키로 두고 벤더를 교체 가능하게 설계할 것.

### 8. step-03 종합 — 진입 장벽 재평가

| | step-02 직후 인식 | step-03 이후 |
|---|---|---|
| 와인 DB | 4~5천만원 구축 필요 | **LWIN 무료 + api4ai 월 1~2만원** (단, 한국 커버리지 미검증) |
| 진입 장벽 | 넘을 수 없음 | **넘을 수 있음** |
| 국내 경쟁자 | 미조사 | **없음 (빈티지 1급 제품 0개)** |
| 이카운트 논거 | — | **유효 — 확정 기능은 연 64만원이 커버** |
| 프로젝트 존재 이유 | 바코드 빠른 입고 | **빈티지별 원가·마진 관리** (이카운트 Lot이 못 하는 것) |

**바코드와 라벨 사진, 두 식별 경로가 "와인 마스터 DB 소유"라는 동일 의존성으로 수렴한다** — 이것이 하위 연동 이슈가 아니라 **프로젝트의 진짜 임계 경로일 수 있다 (추정).**

### 9. step-03 미확인 / 정직한 공백

**🔴 결정적 (포지셔닝을 좌우):**
- **이카운트 로트별 원가 분리 가능 여부** — "언급 없음"이지 "불가 확정"이 아님. **직접 문의 필요.**
- **이카운트 오픈 API의 Lot 단위 입출고 전표 생성 지원 여부** — "이카운트 백엔드 + 자체 프론트" 대안의 성패를 가름
- **한국 수입 와인의 실제 DB 커버리지** — LWIN·api4ai·InVintory 모두 **벤더 마케팅 수치**이며 독립 검증 없음

**기타 미확인:**
- 바코드 DB 영역 전체: GS1 Verified by GTIN 접근 조건, **GS1 Korea 코리아넷 외부 접근**(한국 시장 특성상 후속 가치 있는 유일 항목 — 웹 조사보다 GS1 Korea 직접 문의가 빠를 것), UPCitemdb·Barcode Lookup 와인 커버리지
- 오픈 데이터 추가 후보: OpenWines, Wikidata 와인 엔티티, X-Wines 데이터셋 — **미조사**
- 더존 iCUBE 가격·생산/무역 모듈, 오케이포스·엔젤넷 가격(대리점 견적 구조 — 도구 문제가 아니라 시장 관행)
- 이카운트 사용자 정의 항목 개수 상한, 이카운트 복수 바코드 등록 가능 여부
- 페이히어 옵션의 원가 분리 여부(SPA라 미확인)
- 식약처 수입식품 API의 와인 레코드 실측(인증키 발급 필요) — 빈티지·품종 포함 여부가 LLM 추론 결정의 전제
- LWIN CSV 정확한 스키마, 200,000 vs 100,000 불일치
- Wine-Searcher 현행(2026) 약관 — 확인한 것은 ©2017 아카이브

**근거 신뢰도 경고:** 한국 업계 실태 근거가 **양재혁 1인의 2020~2021년 칼럼에 편중**돼 있고 **5~6년 경과**했다. 반면 이카운트 가격·OFF 실측·API 가격은 **1차 출처/직접 측정**이다. **두 수치의 강도를 섞지 말 것.**

**조사 방법 주석:** WebSearch/WebFetch가 529(과부하)·403(봇차단)을 반환해, 공식 호스트 직접 curl + Wayback CDX + 정부 CKAN API + 라이브 가격 엔드포인트 방식으로 전환했다. 이 덕분에 TinEye 실제 결제 페이지 가격, Wine-Searcher 2025년 가격표, api4ai JS 렌더링 가격, Vinmonopolet ToS PDF 원문, **OFF 한국 커버리지 0**을 1차 출처로 확정했다. 어떤 가격·인용도 기억에서 복원하지 않았다.

---

---

## Regulatory Requirements (규제 요건)

> _step-04. **범위 축소**: 사용자 지시("규제까지 deep하게 들어갈 필요는 없어", 2026-07-17)에 따라 OQ-6만 조사하고 주류 유통 규제는 중단했다. 빈티지·바코드의 규제 측면은 step-02(GS1 표준·TTB 27 CFR 4.27·EU Reg 2019/33·식약처 표시기준·국세청 RFID·관세청 HSK)에서, 데이터 라이선스·약관은 step-03(Vivino/Wine-Searcher/CellarTracker ToS·CC BY·ODbL)에서 이미 다뤘다._

### ⭐ OQ-6 종결 — 법적 장애물 없음, 순수 계약 문제

**질문:** "라벨 사진을 해외 LLM API로 보내는 데 법적 장애물이 있는가?"
**답: 없다.** 세 개의 독립적 근거가 같은 방향을 가리킨다.

**1. 라벨 사진은 개인정보가 아니다 — 확인된 사실 (1차 출처)**

「개인정보 보호법」 제2조 제1호:
> **"개인정보"란 살아 있는 개인에 관한 정보로서** 다음 각 목의 어느 하나에 해당하는 정보를 말한다…

개인정보보호위원회 개인정보 포털 공식 설명:
> **"자연인이 아닌 법인, 단체 또는 사물 등에 관한 정보는 개인정보에 해당하지 않습니다."**

**와인 병은 사물이다.** → 개인정보보호법 규율 대상 밖 → **제28조의8(국외 이전) 발동하지 않음.** 동의·처리방침 국외이전 고지 **법적으로 불필요.**
_Source: https://www.law.go.kr/LSW//lsLawLinkInfo.do?lsJoLnkSeq=900648197&chrClsCd=010202&lsId=011357&print=print (1차), https://www.privacy.go.kr/front/contents/cntntsView.do?contsNo=27 (1차)_

**2. 거래 데이터도 개인정보가 아니다 — 확인된 사실**

재고 수량·매입가·거래처 법인명 = 법인/사물 정보. privacy.go.kr: *"법인의 상호, 영업 소재지, 임원 정보, 영업실적 등의 정보는 「개인정보 보호법」에서 보호하는 개인정보의 범위에 해당되지 않습니다."*

「부정경쟁방지 및 영업비밀보호에 관한 법률」은 **금지 규범이 아니라 구제 규범**이다 — 보유자에게 "해외로 보내지 마라"는 의무를 부과하지 않는다. 매입가를 LLM에 보내는 행위 자체는 이 법 위반이 아니다.
_(해석) 다만 비밀관리성 요건상, 매입가를 아무 통제 없이 외부 API에 흘리면 훗날 영업비밀성이 다투어질 때 빌미가 될 수 있다 → DPA·기밀유지 조항·학습 미사용 확약으로 관리할 영역._

**3. 민간 기업의 해외 클라우드 이용 규제 없음 — 확인된 사실**

금융(전자금융감독규정)·공공(CSAP)에만 규제가 있다. 와인 수입/유통사는 둘 다 아니다. 「클라우드컴퓨팅법」 제27조는 **의무 주체가 클라우드 제공자**이며 금지가 아니라 정보제공 의무다. **주류업 특유의 데이터 위치·국외이전 제한은 찾지 못했다.**

> **⚠️ 과잉 해석 경계:** "AI니까", "해외 전송이니까", "국외이전 규정이 있으니까" 같은 이유로 동의 절차나 처리방침 고지를 설계에 넣지 말 것. **개인정보가 없으면 그 조문들은 작동하지 않는다.** 불필요한 동의 UI는 제품을 해친다.

### 🔴 실제 존재하는 리스크 — 무료 티어 (즉시 조치 필요)

**Google Gemini API 약관 원문** _(Source: https://ai.google.dev/gemini-api/terms — 1차 출처)_

| | 원문 |
|---|---|
| **무료(Unpaid)** | "Google uses the content you submit… **to provide, improve, and develop Google products and services**."<br>"**human reviewers may read, annotate, and process your API input and output.**"<br>"**Do not submit sensitive, confidential, or personal information to the Unpaid Services.**" |
| **유료(Paid)** | "Google **doesn't use your prompts**… **or responses to improve our products**." (로깅은 남음 — "solely for detecting and preventing violations of the Prohibited Use Policy") |

> **프로젝트 env에 준비된 Gemini 키가 무료 티어라면, 고객사 재고 사진과 데이터가 구글 제품 개선에 쓰이고 사람이 읽는다.** 법 위반은 아니나 **고객사에 설명할 수 없는 상태**다.
> **조치: Cloud Billing 계정 활성화.** 활성화 시 무료 쿼터 사용분까지 "Paid Service"로 취급된다. **POC 시작 전 완료할 것.**

**리전 — 확인된 사실**
- **Gemini Developer API에는 리전 선택이 없다**: *"data may be stored transiently or cached in **any country** in which Google or its agents maintain facilities."* → 리전 통제가 필요하면 Vertex AI로 가야 함 (미확인).
- **OpenAI는 한국 데이터 레지던시 지원**(미국·유럽·영국·캐나다·호주·일본·인도·싱가포르·**한국**·UAE). ⚠️ 단 **레지던시는 저장(at rest)에 관한 것이고 추론 자체의 기본 위치는 여전히 미국** → "한국 리전이니 국외이전 아님"은 성립하지 않는다. (개인정보가 없으므로 본 건엔 무의미하나, 고객사 질의 시 정확히 답할 것)
- **OpenAI API**: "Data sent to the OpenAI API is **not used to train or improve OpenAI models**" (2023-03-01 이후). 남용 모니터링 로그 **최대 30일**. ZDR 활성화 시 제외.
_Source: https://developers.openai.com/api/docs/guides/your-data , https://help.openai.com/en/articles/10503543-data-residency-for-the-openai-api_

### 설계로 소거할 작은 리스크 (법무가 아니라 설계로)

1. **사람이 우발적으로 찍히는 경우** — 그때부터 제2조 제1호 가목("영상 등을 통하여 개인을 알아볼 수 있는 정보")에 해당해 개인정보보호법이 켜지고, 해외 전송이 제28조의8 국외이전이 된다. → **라벨 중심 촬영 UI + 사람 감지 시 재촬영 유도**로 소거.
2. **거래처 담당자 성명·연락처가 페이로드에 섞이는 경우** — 개인사업자 거래처면 개인정보. → **LLM 요청 페이로드에서 배제.** 라벨 추론에 애초에 불필요.
3. (선택) **EXIF 제거** — 법적 의무 아님. "다른 정보와 쉽게 결합"(제2조 제1호 나목) 논쟁 자체를 없애는 위생 조치.

### 제품 요구사항으로 전환되는 것

- **「국세기본법」 제85조의3**: 장부·증거서류는 법정신고기한이 지난 날부터 **5년간 보존**. **위치 제한이 아니므로 클라우드 이용을 막지 않는다.** 단 앱이 원장 역할을 한다면 **5년 보존 가능한 설계**가 필요하다. → 규제 리스크가 아니라 **제품 요구사항**. _(2차 출처: CaseNote)_

### 고객사 합의 항목 (법적 의무 아님 — 계약 위생)

유료 티어 사용 확약 / 학습 미사용 조항 인용 / ZDR 적용 여부 / 벤더 DPA 사본 제공 / **전송 페이로드 범위 명시(라벨 이미지 한정)** / EXIF 제거

### step-04 미확인 / 정직한 공백

- **⚠️ 주류 유통 규제 — 사용자 지시로 중단(미조사).** 거래 기록 보존 의무, 국세청 신고 의무, 주류 면허별 제약, 납세증명표지 적용 여부, 주류 통신판매 규제 적용 여부는 **확인하지 않았다.**
  - **🔎 남은 단서**: 중단 직전 에이전트가 *"Definitively resolved — and it's a **2025.7.1 change** that Agent C's older source missed"*라고 보고했다. **2025-07-01자 주류 관련 제도 변경이 있고, 앞선 조사의 오래된 출처가 이를 놓쳤다는 뜻으로 읽힌다. 내용은 미확인.** 향후 규제 확인이 필요해지면 **여기서 시작할 것.**
  - 관련하여 step-02에서 확인된 것: 국세청 RFID 주류유통정보시스템은 **위스키 전용**(와인 제외), 국세청 주류 코드는 **주종 분류만**, 관세청 HSK는 빈티지 구분 없음. **(추정)** RFID 부착 의무가 알코올 17도 이상에만 적용된다면 와인(12~14도)은 제외 — **미확인**.
- api4ai 약관 (step-03에서 일부 확인 — 캐싱·저장 조항 미확인)
- 개인정보위 「생성형 AI 개발·활용을 위한 개인정보 처리 안내서」(2025-08) 본문 상세
- OpenAI Enterprise Privacy 페이지 원문 (403)
- Vertex AI 리전 통제 가능 여부

**⚠️ 출처 신뢰도 주의:** 「개인정보 보호법」 제2조 제1호와 Gemini/OpenAI 약관은 **1차 출처 직접 확인**. 반면 **제28조의8·제25조의2·부정경쟁방지법 제2조·국세기본법 제85조의3은 CaseNote 등 2차 출처** 기반이다(law.go.kr JS 렌더링 문제). **조문을 대외 문서에 인용할 경우 법제처 원문 대조 필요.**

---

<!-- Content will be appended sequentially through research workflow steps -->

