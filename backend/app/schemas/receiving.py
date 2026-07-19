"""입고 입출력 스키마 (FR7)."""
from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class ReceivingCreate(BaseModel):
    """⚠️ `staff_id`·`received_at`은 의도적으로 없다.

    필드를 두면 언젠가 신뢰하는 코드가 생긴다. 담당자는 JWT에서, 시각은 서버에서만 온다.
    """

    wine_vintage_id: uuid.UUID
    quantity: int = Field(ge=1)  # 최소 1병 — 0병 입고는 입고가 아니다
    memo: str | None = None


class ReceivingRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    wine_vintage_id: uuid.UUID
    quantity: int
    received_at: datetime
    staff_id: uuid.UUID
    memo: str | None
