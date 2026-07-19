"""LabelInferencePort 팩토리 + 실벤더 어댑터 (AR4·AR9).

🔴 **유료 티어 fail-closed.** 실벤더 어댑터는 `LLM_PAID_TIER_CONFIRMED=true`가 아니면
생성되지 않는다.

키 문자열로는 무료/유료를 판별할 수 없으므로 기술적 검증이 불가능하다. 할 수 있는
최선은 기본값을 안전한 쪽(fake)에 두고, 실벤더를 켤 때 운영자가 **명시적으로 단언**하게
만드는 것이다. "env에 키만 넣었더니 그냥 동작했다"가 일어나면 안 된다 —
Gemini 무료 티어 약관은 *"human reviewers may read, annotate, and process your API
input and output"* 이고 *"Do not submit sensitive, confidential, or personal
information to the Unpaid Services"* 라고 명시한다. 법 위반은 아니지만 고객사 재고
사진이 거기로 가면 설명할 방법이 없다.
"""
from __future__ import annotations

import base64
import logging

import httpx

from app.core.config import settings
from app.services.ports import InferenceResult, LabelInferencePort

logger = logging.getLogger(__name__)

# ⚠️ 실호출로 두 번 다듬은 프롬프트(2026-07-19).
#
# 1차: 초안은 "생산자명과 제품명이 다르면 제품명 우선"이었는데, 보르도 라벨에서
#      OpenAI가 "Grand Vin de Bordeaux"(등급 문구)를 골랐다 — 샤토는 생산자명이 곧
#      제품명이라 지시가 정반대였다.
# 2차: **실제 병 사진**(Mar de Frades Albariño)으로 재검증하니 두 모델 다
#      "Mar de Frades"만 반환했다. 그러면 같은 생산자의 다른 퀴베(Finca Valiñas 등)가
#      **하나의 WineProduct로 합쳐지고** 그 아래 WineVintage가 섞인다 — 2계층 모델
#      (AR2)이 존재하는 이유를 정면으로 깬다. "병을 구분하는 이름"을 요구하도록 바꿨다.
#
# 무엇을 **버려야 하는지** 명시하는 편이 무엇을 고르라고 하는 것보다 잘 듣는다.
_PROMPT = (
    "이 와인 라벨 사진에서 **이 병을 다른 병과 구분하는 이름**을 추출하세요.\n"
    "- 생산자가 여러 와인을 만들면 생산자명만으로는 부족합니다. 품종·퀴베·밭 이름 등"
    " 라벨에 적힌 구분자를 함께 넣으세요 (예: Mar de Frades Albariño).\n"
    "- 생산자명 자체가 제품명인 경우(보르도 샤토 등)는 그대로 씁니다"
    " (예: Château Margaux).\n"
    "- 다음은 이름이 아니므로 제외하세요: 등급·품질 문구"
    "(Grand Vin, Grand Cru, Reserva 등), 원산지·등급 표기"
    "(Rías Baixas, Denominación de Origen, Appellation … Contrôlée),"
    " 병입 문구(Mis en bouteille …), 용량·도수, 수입사·판매원 표기, 연도.\n"
    "- 라벨에서 이름을 읽을 수 없으면 model_name을 null로 두세요. 추측하지 마세요.\n"
    "- confidence는 글자가 선명하고 이름이 분명할 때만 0.8 이상을 주세요.\n"
    'JSON만 출력: {"model_name": "..." 또는 null, "confidence": 0.0~1.0}'
)


class PaidTierNotConfirmedError(RuntimeError):
    """유료 티어 미확인 상태에서 실벤더를 요청했을 때."""


def _require_paid_tier(provider: str) -> None:
    if not settings.LLM_PAID_TIER_CONFIRMED:
        raise PaidTierNotConfirmedError(
            f"{provider} 어댑터는 LLM_PAID_TIER_CONFIRMED=true 없이는 사용할 수 없습니다. "
            "무료 티어에서는 사람이 입출력을 읽고 제공사 제품 개선에 사용됩니다 — "
            "고객사 라벨·재고 사진을 보낼 수 없습니다. "
            "Billing을 활성화한 뒤 이 값을 true로 설정하세요."
        )


class _HttpInferenceAdapter:
    """실벤더 공통 — 타임아웃·실패를 도메인 값으로 변환한다."""

    def _post(self, url: str, *, headers: dict, json: dict) -> dict | None:
        try:
            resp = httpx.post(
                url,
                headers=headers,
                json=json,
                timeout=settings.LLM_TIMEOUT_SECONDS,  # 타임아웃 없는 호출은 현장 흐름을 멈춘다
            )
            resp.raise_for_status()
            return resp.json()
        except Exception:
            # 페이로드에 이미지가 있으므로 예외 본문을 그대로 로깅하지 않는다.
            logger.warning("label inference call failed", exc_info=False)
            return None


class GeminiAdapter(_HttpInferenceAdapter):
    def __init__(self, api_key: str, model: str = "gemini-2.5-flash") -> None:
        _require_paid_tier("Gemini")
        self._key = api_key
        self._model = model

    def infer(self, image: bytes, content_type: str) -> InferenceResult:
        body = self._post(
            f"https://generativelanguage.googleapis.com/v1beta/models/{self._model}:generateContent",
            headers={"x-goog-api-key": self._key},
            json={
                "contents": [
                    {
                        "parts": [
                            {"text": _PROMPT},
                            {
                                "inline_data": {
                                    "mime_type": content_type,
                                    "data": base64.b64encode(image).decode(),
                                }
                            },
                        ]
                    }
                ]
            },
        )
        if body is None:
            return InferenceResult(failed=True, reason="gemini-call-failed")
        try:
            text = body["candidates"][0]["content"]["parts"][0]["text"]
        except (KeyError, IndexError, TypeError):
            return InferenceResult(failed=True, reason="gemini-unexpected-response")
        return _parse_json_result(text, "gemini")


class OpenAIAdapter(_HttpInferenceAdapter):
    def __init__(self, api_key: str, model: str = "gpt-4o-mini") -> None:
        _require_paid_tier("OpenAI")
        self._key = api_key
        self._model = model

    def infer(self, image: bytes, content_type: str) -> InferenceResult:
        data_url = f"data:{content_type};base64,{base64.b64encode(image).decode()}"
        body = self._post(
            "https://api.openai.com/v1/chat/completions",
            headers={"Authorization": f"Bearer {self._key}"},
            json={
                "model": self._model,
                "messages": [
                    {
                        "role": "user",
                        "content": [
                            {"type": "text", "text": _PROMPT},
                            {"type": "image_url", "image_url": {"url": data_url}},
                        ],
                    }
                ],
            },
        )
        if body is None:
            return InferenceResult(failed=True, reason="openai-call-failed")
        try:
            text = body["choices"][0]["message"]["content"]
        except (KeyError, IndexError, TypeError):
            return InferenceResult(failed=True, reason="openai-unexpected-response")
        return _parse_json_result(text, "openai")


def _parse_json_result(text: str, provider: str) -> InferenceResult:
    """모델 응답에서 JSON을 꺼낸다. 형태가 어긋나면 실패 값으로 돌려 수동 폴백을 태운다."""
    import json
    import re

    match = re.search(r"\{.*\}", text, re.DOTALL)
    if match is None:
        return InferenceResult(failed=True, reason=f"{provider}-no-json")
    try:
        data = json.loads(match.group(0))
        name = data.get("model_name")
        confidence = float(data.get("confidence", 0.0))
    except (ValueError, TypeError):
        return InferenceResult(failed=True, reason=f"{provider}-bad-json")
    if not name:
        return InferenceResult(failed=True, reason=f"{provider}-empty-name")
    return InferenceResult(
        model_name=str(name), confidence=max(0.0, min(1.0, confidence))
    )


def get_label_inference() -> LabelInferencePort:
    """env로 어댑터를 선택한다. 라우트는 이 팩토리만 알고 구현을 직접 import하지 않는다.

    기본값이 `fake`인 것은 의도적이다 — 설정이 비어 있을 때 실벤더로 새면 안 된다.
    """
    provider = (settings.LLM_PROVIDER or "fake").strip().lower()

    if provider == "gemini":
        if not settings.GEMINI_API_KEY:
            raise RuntimeError("LLM_PROVIDER=gemini인데 GEMINI_API_KEY가 없습니다.")
        return GeminiAdapter(settings.GEMINI_API_KEY)

    if provider == "openai":
        if not settings.OPENAI_API_KEY:
            raise RuntimeError("LLM_PROVIDER=openai인데 OPENAI_API_KEY가 없습니다.")
        return OpenAIAdapter(settings.OPENAI_API_KEY)

    from app.adapters.label_inference_fake import FakeInferenceAdapter

    return FakeInferenceAdapter()
