"""입고 기록 (FR7).

원장 성격의 테이블이다. `deleted_at`만으로 취소를 표현하고 하드삭제는 금지(AR6) —
국세기본법 §85조의3의 5년 보존 대상이기 때문. 재고 집계는 반드시
`deleted_at IS NULL`을 필터한다.

`received_at`·`staff_id`는 서버가 정한다. 공용 창고 단말의 시계는 어긋나고,
클라이언트가 담당자를 지정할 수 있으면 감사 추적이 무의미해진다.
"""
from __future__ import annotations

import uuid
from datetime import UTC, datetime

from sqlmodel import Field, SQLModel


def _utcnow() -> datetime:
    return datetime.now(UTC)


class ReceivingRecord(SQLModel, table=True):
    __tablename__ = "receiving_records"

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    wine_vintage_id: uuid.UUID = Field(
        foreign_key="wine_vintages.id", index=True, nullable=False
    )
    quantity: int = Field(nullable=False)
    received_at: datetime = Field(default_factory=_utcnow, index=True, nullable=False)
    staff_id: uuid.UUID = Field(foreign_key="users.id", index=True, nullable=False)
    memo: str | None = None  # FR12 — 입력 UI는 Story 4.3
    deleted_at: datetime | None = Field(default=None, index=True)  # soft-delete 전용
    created_at: datetime = Field(default_factory=_utcnow, nullable=False)
