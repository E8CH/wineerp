"""라벨 추론 입출력 스키마 (FR6 지원)."""
from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class LabelInferenceRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    image_key: str = Field(max_length=512)
    # ⚠️ 자유 문자열이면 안 된다. 이 값은 Gemini의 `inline_data.mime_type`과
    # OpenAI의 `data:` URL에 **그대로 실려** 벤더로 나간다. 자유 입력이면 인증된
    # 클라이언트가 임의 텍스트를 페이로드에 주입할 수 있고, 그건 AR9가 타입으로
    # 닫았다고 주장한 바로 그 통로다. 허용목록으로 좁힌다.
    content_type: Literal["image/jpeg", "image/png", "image/webp"] = "image/jpeg"


class InferenceRead(BaseModel):
    """⚠️ 항상 200이다. 추론 실패는 HTTP 오류가 아니라 도메인 결과이며,
    UI는 `needs_manual_input`으로 수동 입력 폴백을 띄운다(FR6·SM-C2)."""

    model_name: str | None
    confidence: float
    failed: bool
    low_confidence: bool
    needs_manual_input: bool
    reason: str | None = None
