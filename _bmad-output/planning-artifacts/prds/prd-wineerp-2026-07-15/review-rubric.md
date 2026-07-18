# PRD Quality Review — wineerp (와인 입고/재고관리 서비스)

*Reviewer: finalize-gate rubric reviewer. Path: Fast (assumptions tagged inline). Deliverable: client POC. Reviewed 2026-07-15 against `prd.md` + `addendum.md`.*

## Overall verdict

Gate verdict: **pass-with-fixes.** This is a genuinely usable, downstream-ready PRD. It has a real thesis (실물[바코드·라벨] 기준으로 명세서를 대체한다), two load-bearing personas, contiguous FR/UJ/SM IDs, testable consequences on nearly every FR, honest Non-Goals, and — notably — it does not hide the one thing that would sink the engagement: the confirmed feature set (관리자 역할 + LLM 추론 + 리포트 전체) exceeds the contracted POC (1주·3페이지·200만원), and that tension is flagged loudly at §4 Notes, §6, OQ-1, and §13. What holds it back from a clean pass: the headline success metric (SM-1, 50% 단축) has no baseline or measurement method; the Assumptions Index does not round-trip (the §10–§12 assumptions sit *after* the index and are never captured); and "OCR" leaks in as a synonym for the glossary's "LLM 모델명 추론." None are structural — all are surgical fixes before build hand-off.

## Decision-readiness — strong

A decision-maker can act on this. The central trade-off is not smoothed to neutral: §6 opens with a "용어 주의" admitting the In-Scope list is drawn on the confirmed-feature basis, not the contract basis, and routes the reconciliation to OQ-1 with an explicit "회장 보고 전 재협의 필요." The `[NOTE FOR PM]` at §4 (line 166) sits at the real tension — the money/schedule overshoot — not at a safe checkpoint. Open Questions are actually open: OQ-2 (바코드↔빈티지) and OQ-3 (매칭 기준 데이터 제공 가능 여부) are live unknowns that the POC exists to answer, not rhetorical questions. The one thing a decision-maker still cannot do is *price the POC* — but the PRD correctly declares that out of its own scope and hands it to OQ-1, which is the right move rather than a dodge.

### Findings
- **high** SM-1 gives no way to declare success (§7, line 199) — "검수·입력 시간 50% 단축 … 병당 처리시간. 검증 FR-3~FR-8." The baseline (current 명세서 대조 병당 시간) is never captured, and no measurement protocol is stated (how many bottles, whose timing, under what conditions). For a POC whose headline pitch *is* the time saving, this is the number the client will ask about first, and today it is unfalsifiable. *Fix:* add a one-line measurement definition — e.g. "baseline = 시연 전 명세서 방식 N병 실측 평균, target = 동일 N병 앱 방식 실측; 50% = 두 평균 비교," and note who records it.

## Substance over theater — strong

No furniture. Exactly two personas (§2.1 직원, §2.2 관리자), each driving distinct FRs and UJs — well under the four-persona theater line, and §2.4 Non-Users does real de-scoping work. The Vision (§1) is category-specific and could not be swapped into another PRD: it names the concrete pain (하루 10~100병, 연 ~1,000종, 부정확한 명세서 와인명). NFRs mostly carry product-specific bounds rather than adjectives (매칭 2초, LLM 3~5초, 하루 ~100건, ~1,000종). The Differentiation/innovation risk is avoided by simply not claiming novelty — the PRD sells a workflow, not a moat, which is honest for a POC.

### Findings
- **low** A couple of NFRs still lean on adjectives before the assumption rescues them (§10, line 235: "지연 없이 동작" — softened only by the `[ASSUMPTION: 2초]`). Fine as-is, but the adjective and the number should not disagree. *Fix:* lead with the bound ("스캔→결과 표시 2초 이내") and drop "지연 없이."

## Strategic coherence — strong

There is a thesis and the features serve it. Everything flows from "명세서가 아니라 실물을 기준으로 품목을 확정한다": FR-3/4/5 (scan → label → match) are the thesis; FR-6 (LLM 신규 등록) is the escape hatch when the master DB misses; FR-7/8 close the loop; FR-9/10/11 serve the secondary persona's reporting job. Prioritization follows the thesis, not ease — the POC deliberately scopes to 10종 마스터 (§6.1) to test identification, the risky part, rather than front-loading easy CRUD. Counter-metrics are present and pointed: SM-C1 (속도만 좇다 오등록↑ 방지) and SM-C2 (LLM 자동채움 맹신 방지) directly guard the two ways this product could game its own primary metrics. MVP scope kind reads as problem-solving/experience, and the scope logic matches.

*No findings — this dimension holds up.*

## Done-ness clarity — adequate

This is the dimension to be hardest on, and it mostly earns "adequate." Every FR (1–11) carries a **Consequences (testable)** block, and most are genuinely verifiable: FR-1 "동일 이메일 중복 가입은 거부된다," FR-7 "`와인 마스터 + 수량 + 입고일시 + 담당 직원`으로 입고 기록이 생성된다," FR-11 엑셀 컬럼 집합 named. That is above the bar for story creation to source from.

Where it thins: (a) FR-6's fallback trigger — "LLM 추론이 실패·저신뢰일 때 … 폴백" (line 127) — leaves "저신뢰" undefined, so an engineer cannot test the branch that the whole risk story (SM-C2, §13) hangs on. (b) SM-1's un-measurable state (see Decision-readiness). (c) The reporting FRs are the softest: FR-10 defers its actual content to an assumption ("기간별 입고량·품목 분포" — 구체 지표 확정 필요), which is honest but means "done" for the graph is not yet knowable.

### Findings
- **medium** FR-6 fallback has no threshold (§4.2, line 127) — "저신뢰일 때" is untestable and it gates the SM-C2 safety behavior. *Fix:* state the trigger even coarsely — e.g. "LLM이 모델명을 반환하지 못하거나 신뢰도 필드가 임계 미만/부재이면 수동 입력 폼을 기본 노출"; leave the exact number to architecture but name the condition.
- **low** FR-10 done-state is deferred to assumption (§4.2, line 159). Acceptable for Fast/POC, but flag that story creation cannot size this FR until the 지표 are picked (OQ-adjacent). *Fix:* either pin the two charts (기간별 입고 수량 막대 + 상위 품목) as MVP-fixed, or add an OQ so it is tracked, not just parenthetical.

## Scope honesty — strong

Omissions are explicit, not inferred. §5 Non-Goals does real work (판매/유통 상태, 품질 검수, 회계/세무, 출고 차감 — each with a one-line reason), and §6.2 Out-of-Scope pairs each cut with its rationale (10종 vs 1,000종, 웹 vs 모바일-우선, 오프라인). Inferences carry `[ASSUMPTION]` tags at their point of use and most are indexed in §9. De-scoping is proposed openly (관리자 웹, 오프라인) rather than done silently.

Open-items density is high — 6 OQ + ~12 `[ASSUMPTION]` + 3 `[NOTE FOR PM]` — but for a *POC whose explicit purpose is to resolve unknowns* (바코드↔빈티지, LLM 실용성, 데이터 제공 가능성) this is appropriate, not a red flag. The density would block a green-light-to-build; here it correctly signals "this is a discovery POC, price and scope accordingly," which is exactly the message OQ-1 carries.

### Findings
- **medium** Assumptions Index does not round-trip (§9 vs §10–§12). The index (§9, lines 220–229) is placed *before* the NFR/Aesthetic sections, so four inline assumptions are never captured: §10 매칭 "2초 이내" (line 235), §10 "POC 수준 기본 보안" (line 238), §10 LLM "3~5초 이내" (line 239), §12 "다크/차분한 와인 톤" (line 250). Downstream tooling that harvests the index will miss these. *Fix:* append the four to §9, or move §9 to the true end of the document (after §13).

## Downstream usability — strong (with one drift)

This PRD feeds UX → architecture → epics, so the dimension matters. It mostly extracts cleanly: §3 Glossary fixes the domain nouns (와인 마스터, 빈티지, 매칭, 입고 기록); FR IDs are contiguous 1–11, UJ 1–3, SM 1–5 + C1–C2, OQ 1–6 — no gaps or dupes. `실현 UJ-x` tags give FR→UJ traceability, and every UJ names a persona (민수=직원, 지영=관리자) traceable to §2. Cross-references (OQ numbers, §pointers) resolve. Each FR section stands alone.

The one real drift: **"OCR" appears as an un-glossaried synonym for "LLM 모델명 추론."** The glossary and FR-6 consistently say "LLM이 라벨 사진을 분석해 추론한 모델명," but §4 Notes (line 166, "FR-6(OCR)") and §6.1 (line 184, "라벨 OCR 자동 채움") switch to "OCR." OCR (문자 인식) and vision-LLM inference are technically different capabilities; an architect reading §6.1 could scope a plain OCR component and mis-serve the requirement.

### Findings
- **medium** Glossary drift: OCR vs "LLM 모델명 추론" (§4 line 166, §6.1 line 184 vs §3 line 76 / FR-6). *Fix:* replace "OCR" with "LLM 라벨 모델명 추론" in both places; if OCR is genuinely meant as a distinct fallback, define it in §3.
- **low** FR-4 (라벨 사진 촬영) carries no `실현 UJ-x` tag though it is load-bearing in UJ-1/UJ-2. Minor traceability gap. *Fix:* add "실현 UJ-1, UJ-2."

## Shape fit — strong

The shape matches the product. Two stakeholder roles with meaningfully different jobs (operator vs reporter) make UJs and personas load-bearing, not overhead — and the PRD provides exactly three UJs, one per distinct journey, without over-formalizing. It is chain-top (feeds UX/arch/epics), and it correctly invests more in downstream usability (glossary, IDs, traceability) than a standalone POC would need. Not over-formalized (no persona bloat), not under-formalized (a two-role field tool with no UJs would have been wrong). NFRs and Platform are sized to a POC — candidate stack pushed to addendum/브리프, not prematurely fixed. Good fit.

*No findings.*

## Mechanical notes

- **Glossary drift:** OCR ↔ "LLM 모델명 추론" (see Downstream usability, medium). Otherwise domain nouns are used consistently across FRs/UJs/SMs.
- **ID continuity:** FR-1..11, UJ-1..3, SM-1..5 + SM-C1..C2, OQ-1..6 — all contiguous, unique, no dangling cross-refs. Clean.
- **Assumptions Index roundtrip:** broken in one direction — 4 inline `[ASSUMPTION]`s in §10/§12 are not indexed (see Scope honesty, medium). Every §9 index entry does appear inline (reverse direction OK).
- **UJ persona linkage:** all 3 UJs name a defined persona by role (직원/관리자) via illustrative names (민수/지영); linkage is unambiguous.
- **Required sections:** all present for a chain-top POC PRD — Vision, Personas, UJs, Glossary, FRs, Non-Goals, MVP Scope, Success Metrics + Counter-metrics, Open Questions, Assumptions Index, NFRs, Platform, Risks.

## Fix priority before build hand-off

1. (high) SM-1 — add baseline + measurement protocol (§7).
2. (medium) FR-6 — name the "저신뢰" fallback trigger condition (§4.2).
3. (medium) Assumptions Index — capture §10/§12 assumptions or relocate §9 to end.
4. (medium) OCR → "LLM 라벨 모델명 추론" wording fix (§4 Notes, §6.1).
5. (low) FR-4 UJ tag; FR-10 chart done-state; §10 adjective/number alignment.
