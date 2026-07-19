"""입고 입출력 스키마 (FR7)."""
from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

# UI 스테퍼 상한과 일치. 상한이 없으면 3000000000 같은 값이 검증을 통과해
# PostgreSQL INTEGER(2147483647)를 넘겨 422가 아닌 500으로 터진다.
# 테스트는 SQLite라 상한이 없어 CI가 영원히 못 잡는 종류의 결함이다.
MAX_QUANTITY = 999


class ReceivingCreate(BaseModel):
    """⚠️ `staff_id`·`received_at`은 의도적으로 없다.

    필드를 두면 언젠가 신뢰하는 코드가 생긴다. 담당자는 JWT에서, 시각은 서버에서만 온다.
    `extra="forbid"`로 주입 시도를 조용한 201이 아니라 시끄러운 422로 만든다.
    """

    model_config = ConfigDict(extra="forbid")

    wine_vintage_id: uuid.UUID
    quantity: int = Field(ge=1, le=MAX_QUANTITY)  # 0병 입고는 입고가 아니다
    memo: str | None = Field(default=None, max_length=500)


class ReceivingRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    wine_vintage_id: uuid.UUID
    quantity: int
    received_at: datetime
    staff_id: uuid.UUID
    memo: str | None
