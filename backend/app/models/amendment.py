"""입고 수정 이력 (FR8, AR6).

"수정 이력 보존"을 `updated_at` 하나로 때우면 **무엇이 얼마에서 얼마로** 바뀌었는지가
사라진다. 재고가 안 맞을 때 확인할 것이 없어지고, 국세기본법 §85조의3이 요구하는 것도
최종 상태가 아니라 장부와 증거서류다. 행 하나 더 쓰는 비용이 훨씬 싸다.
"""
from __future__ import annotations

import uuid
from datetime import UTC, datetime

from sqlalchemy import Column, DateTime
from sqlmodel import Field, SQLModel


def _utcnow() -> datetime:
    return datetime.now(UTC)


class ReceivingAmendment(SQLModel, table=True):
    __tablename__ = "receiving_amendments"

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    receiving_record_id: uuid.UUID = Field(
        foreign_key="receiving_records.id", index=True, nullable=False
    )
    before_quantity: int = Field(nullable=False)
    after_quantity: int = Field(nullable=False)
    changed_by: uuid.UUID = Field(foreign_key="users.id", index=True, nullable=False)
    changed_at: datetime = Field(
        default_factory=_utcnow,
        sa_column=Column(DateTime(timezone=True), index=True, nullable=False),
    )
    reason: str | None = None
