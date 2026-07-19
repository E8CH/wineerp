# Story 3.1: LabelInferencePort & 벤더 어댑터 (AR4·AR9)

Status: review

## Story

As a 개발팀,
I want 라벨→모델명 추론을 벤더 교체 가능한 Port로 격리하기를,
so that Gemini/OpenAI를 스위치하고 외부 API 리스크를 흡수한다.

## 왜 유료 키 없이도 이 스토리를 진행하는가

AR4의 요점이 **벤더 격리**다. 포트·어댑터 구조와 **FakeAdapter**를 먼저 세우면 Story 3.2(신규 등록 UI)가 유료 키를 기다리지 않고 진행된다. 막히는 것은 **실호출뿐**이며, 그것은 어댑터 한 파일 안에 갇힌다 — 그게 이 설계의 목적이다.

## Acceptance Criteria

1. **포트 계약**: `LabelInferencePort.infer(image: bytes, content_type: str) -> InferenceResult`.
   - ⚠️ 시그니처가 **이미지 바이트만** 받는다. `image_key`나 도메인 객체를 넘기지 않는 이유는 편의가 아니라 **구조적 보장**이다 — 거래처 PII·매입가를 LLM 페이로드에 넣을 수 있는 경로 자체를 타입으로 없앤다(AR9).
2. **`InferenceResult`는 도메인 값**: `model_name`·`confidence`·`failed`·`reason`. 실패·저신뢰를 **예외가 아니라 값으로** 반환해 라우트가 수동 입력 폴백(FR6)으로 분기한다.
3. **어댑터 3종**: `GeminiAdapter` · `OpenAIAdapter` · `FakeInferenceAdapter`(키 불필요, dev/테스트). env `LLM_PROVIDER`로 선택.
4. **🔴 유료 티어 fail-closed 가드**: 실벤더 어댑터는 `LLM_PAID_TIER_CONFIRMED=true`가 아니면 **생성 자체를 거부**한다(명확한 오류).
   - 키 문자열로는 무료/유료를 판별할 수 없다. 무료 티어 약관상 **사람이 입출력을 읽고 구글 제품 개선에 사용**되므로, 고객사 재고 사진이 조용히 그리로 갈 수 있는 상태를 기본값으로 두면 안 된다. 운영자가 명시적으로 단언하게 만든다.
   - 기본 provider는 `fake` — 설정이 비어 있을 때 실벤더로 새지 않는다.
5. **타임아웃**: 실어댑터 호출에 timeout(기본 8초, env). 초과 시 예외가 아니라 `failed=True` 결과.
6. **엔드포인트**: `POST /api/v1/inference/label`(인증) — `{image_key}` → `{model_name, confidence, failed, reason}`. 라우트·서비스는 **어댑터 구현을 직접 import하지 않는다**(deps 팩토리 경유).
7. **StoragePort에 `get_object`**: key→bytes. 라우트가 이미지를 읽어 어댑터에 바이트로 넘긴다(어댑터는 스토리지를 모른다).
8. **검증**: 포트 계약(Fake) · 저신뢰/실패가 값으로 반환 · 타임아웃→failed · provider 선택 · **유료 가드 미확인 시 실어댑터 거부** · 미인증 401 · 없는 key 404.
9. **변이 검증**: 유료 가드를 제거하면 테스트가 실패해야 한다. 타임아웃 처리를 제거하면 실패해야 한다. ([[test-mutation-verification]])

## Tasks / Subtasks

- [x] **T1. 포트·도메인 값 정리** (AC: 1, 2)
  - [x] `services/ports.py` — `InferenceResult`를 frozen dataclass로, `LabelInferencePort.infer` 시그니처 확정
  - [x] `StoragePort.get_object(key) -> bytes` 추가
- [x] **T2. 스토리지 read 경로** (AC: 7)
  - [x] `storage_local.py`·`storage_r2.py`에 `get_object` 구현(없는 key → `FileNotFoundError`)
- [x] **T3. FakeInferenceAdapter** (AC: 3)
  - [x] 결정적 응답(테스트·dev). 저신뢰·실패를 재현할 수 있게 구성 가능
- [x] **T4. 실벤더 어댑터 + 유료 가드** (AC: 3, 4, 5)
  - [x] `adapters/label_inference.py` 팩토리 — `LLM_PROVIDER` 분기, 유료 미확인 시 거부
  - [x] `GeminiAdapter`·`OpenAIAdapter` — HTTP 호출은 timeout 필수, 예외→`failed` 결과
  - [x] config에 `LLM_PAID_TIER_CONFIRMED: bool = False`, `LLM_TIMEOUT_SECONDS: int = 8`
- [x] **T5. 라우트** (AC: 6)
  - [x] `api/deps.py`에 `LabelInferenceDep`, `api/routes/inference.py`, main 등록
- [x] **T6. 테스트 + 변이 검증** (AC: 8, 9)

## Dev Notes

### 유료 가드는 왜 fail-closed인가

메모리·리서치 기준 이건 이 프로젝트의 **0순위 항목**이다. Gemini 무료 티어 약관 원문: *"human reviewers may read, annotate, and process your API input and output"*, *"Do not submit sensitive, confidential, or personal information to the Unpaid Services"*. 법 위반은 아니지만 **고객사에 설명할 수 없다.**

키만 보고는 티어를 알 수 없으므로 기술적 검증은 불가능하다. 할 수 있는 최선은 **기본값을 안전한 쪽에 두고**(provider=fake), 실벤더를 켜려면 운영자가 명시적으로 단언하게 만드는 것이다. "환경변수에 키만 넣었더니 그냥 동작했다"가 일어나지 않게 한다.

### 왜 어댑터가 `bytes`만 받는가

"이미지 key를 넘기고 어댑터가 알아서 읽게 하면 편하지 않나?" — 편하지만, 그러면 어댑터가 스토리지·DB에 닿을 수 있게 되고 페이로드에 무엇이 들어갈지 타입으로 보장할 수 없다. **PII 배제를 규율이 아니라 구조로 만든다.** 라우트가 읽어서 바이트만 건넨다.

### 실패는 예외가 아니라 값

FR6은 저신뢰·실패 시 수동 입력 폴백을 요구한다. 어댑터가 예외를 던지면 라우트마다 try/except가 번지고 하나만 빠뜨려도 500이 난다. `InferenceResult(failed=True, reason=...)`로 반환하면 분기가 타입에 드러난다.

### 재사용 (재구현 금지)

| 대상 | 위치 |
|---|---|
| `StoragePort` 팩토리 패턴 | `backend/app/adapters/storage.py` — 동일 구조로 `label_inference.py` 작성 |
| `CurrentUser`/`SessionDep`/`StorageDep` | `backend/app/api/deps.py` |
| 테스트 픽스처 | `backend/app/tests/test_receiving.py` |

### 범위 밖

- 신규 등록 UI·AiInferenceField → Story 3.2
- 실제 Gemini/OpenAI 호출 검증 → 유료 키 확보 후(어댑터 한 파일에 갇혀 있음)
- `WineCatalogPort`(LWIN·api4ai) → 별도

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (dev-story)

### Debug Log References

- `uv run pytest -q` -> **67 passed** (53 -> +14) / `uv run ruff check .` -> All checks passed
- `flutter analyze` -> No issues / `flutter test` -> 44 passed (변경 없음 — 백엔드 전용 스토리)
- `openapi.json` 재생성: paths 10, schemas 16

### Completion Notes List

- **AC1~9 충족.** 유료 키 없이 포트·어댑터·엔드포인트가 완성되어 **Story 3.2가 대기 없이 진행 가능**하다. 막힌 것은 실호출뿐이고 `adapters/label_inference.py` 한 파일에 갇혀 있다 — AR4의 목적 그대로다.
- **🔴 유료 티어 fail-closed**: `LLM_PROVIDER` 기본값을 `fake`로, 실벤더는 `LLM_PAID_TIER_CONFIRMED=true` 없이 **생성 자체를 거부**. 키로는 티어를 판별할 수 없으므로 기술적 검증은 불가능하고, 할 수 있는 최선은 기본값을 안전한 쪽에 두고 운영자가 명시적으로 단언하게 만드는 것이다. "env에 키만 넣었더니 그냥 동작했다"가 일어나지 않는다.
- **PII 배제를 규율이 아니라 구조로**: 포트 시그니처가 `(bytes, str)`뿐이라 어댑터가 스토리지·DB에 닿을 수 없다. 스파이 어댑터로 실제 전달 인자가 이미지 바이트와 content_type뿐임을 테스트로 고정했다(AR9).
- **실패는 값**: 타임아웃·형식 오류·빈 이름 전부 `InferenceResult(failed=True, reason=...)`. 라우트는 **항상 200**을 준다 — 추론 실패는 HTTP 오류가 아니라 도메인 결과이고, 500으로 만들면 수동 입력 폴백(FR6)이 끊긴다.
- **Fake가 저신뢰를 기본값으로 반환**: 개발 중 "AI가 잘 맞히네"라는 착각이 생기지 않도록 임계값 아래(0.42)를 돌려주고 `reason`에 실제 추론이 아님을 밝힌다.
- **`LOW_CONFIDENCE_THRESHOLD`를 정확도 KPI로 삼지 말 것** — 라벨/빈티지 인식 정확도의 재현 가능한 공개 벤치마크는 존재하지 않으며 유통 수치는 전부 원출처 검증에 실패했다(리서치 2026-07-17). 이 값은 UI 분기용 임계치일 뿐이다.
- **변이 검증 4건 전부 검출**([[test-mutation-verification]]):
  - 유료 가드 무력화 -> **실패** / 타임아웃 인자 제거 -> **실패** / 실패를 예외로 되돌림 -> **실패** / 기본 provider를 gemini로 -> **실패**(3건)
- **새 의존성 없음**: `httpx`는 이미 있었다.
- **한계**: Gemini/OpenAI **실호출은 미검증**(유료 키 대기). 프롬프트·응답 파싱은 모킹으로만 확인했으므로 실제 모델 출력 형태에 따라 `_parse_json_result` 조정이 필요할 수 있다. 이것이 이 스토리에서 유일하게 사용자 대기인 부분이다.

### File List

**(NEW)** `backend/app/adapters/label_inference.py`, `backend/app/adapters/label_inference_fake.py`, `backend/app/api/routes/inference.py`, `backend/app/schemas/inference.py`, `backend/app/tests/test_inference.py`
**(MOD)** `backend/app/services/ports.py`(InferenceResult dataclass·포트 시그니처·StoragePort.get_object), `backend/app/adapters/storage_local.py`·`storage_r2.py`(get_object), `backend/app/core/config.py`(LLM_* 설정), `backend/app/api/deps.py`(LabelInferenceDep), `backend/app/api/main.py`, `backend/scripts/gen_openapi.py`(직접 실행 경로·cp949), `openapi.json`
