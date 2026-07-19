"""라벨 추론 입출력 스키마 (FR6 지원)."""
from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field


class LabelInferenceRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    image_key: str = Field(max_length=512)
    content_type: str = "image/jpeg"


class InferenceRead(BaseModel):
    """⚠️ 항상 200이다. 추론 실패는 HTTP 오류가 아니라 도메인 결과이며,
    UI는 `needs_manual_input`으로 수동 입력 폴백을 띄운다(FR6·SM-C2)."""

    model_name: str | None
    confidence: float
    failed: bool
    low_confidence: bool
    needs_manual_input: bool
    reason: str | None = None
