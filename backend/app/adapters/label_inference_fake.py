"""FakeInferenceAdapter — 키 없이 도는 LabelInferencePort 구현.

Story 3.2(신규 등록 UI)가 유료 키를 기다리지 않고 진행되도록 존재한다. 이것이
Ports & Adapters(AR4)의 실용적 이득이다 — 막히는 것은 실호출뿐이고, 그건 어댑터
한 파일에 갇힌다.

⚠️ 운영 기본값이기도 하다(`LLM_PROVIDER` 미설정 시). 설정이 비어 있을 때 실벤더로
새지 않게 하려는 의도이며, 이 어댑터는 **추론하는 척하지 않는다** — 결정적인 값을
돌려주고 그 사실을 `reason`에 밝힌다.
"""
from __future__ import annotations

from app.services.ports import InferenceResult


class FakeInferenceAdapter:
    def __init__(
        self,
        *,
        model_name: str | None = "Fake Estate Cuvée",
        confidence: float = 0.42,
        failed: bool = False,
    ) -> None:
        self._model_name = model_name
        self._confidence = confidence
        self._failed = failed

    def infer(self, image: bytes, content_type: str) -> InferenceResult:
        if self._failed:
            return InferenceResult(failed=True, reason="fake-adapter-failure")
        # 기본 신뢰도를 임계값 아래로 둬서 UI가 저신뢰 경고와 수동 입력을 노출하게 한다.
        # 개발 중에 "AI가 잘 맞히네"라는 착각이 생기지 않도록 하는 것이 목적이다.
        return InferenceResult(
            model_name=self._model_name,
            confidence=self._confidence,
            reason="fake-adapter: 실제 추론이 아님(유료 키 미설정)",
        )
