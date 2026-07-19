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
from enum import StrEnum

from sqlalchemy import Column, DateTime
from sqlmodel import Field, SQLModel


class ReceivingSource(StrEnum):
    """입고 이벤트인지 초기 세팅의 재고 기준선인지(Story 3.3).

    별도 테이블로 나누지 않은 이유: 재고를 세는 곳은 `get_stock_map` 한 곳이어야 한다.
    소스를 나누면 재고·리포트·엑셀 쿼리가 전부 union을 해야 하고, 하나만 빠뜨려도
    재고가 조용히 틀린다.
    """

    receiving = "receiving"
    initial_setup = "initial_setup"


def _utcnow() -> datetime:
    return datetime.now(UTC)


def _tz_column(*, index: bool = False, nullable: bool = False) -> Column:
    """`_utcnow()`가 aware datetime을 돌려주므로 컬럼도 timestamptz여야 한다.

    SQLModel 기본 `datetime`은 TIMESTAMP WITHOUT TIME ZONE으로 생성되어
    마이그레이션(0003, timezone=True)과 어긋난다. 어긋난 채로 두면 운영은 오프셋을
    보존하고 테스트(SQLite)는 잃어버려 와이어 포맷이 갈리고, autogenerate는 매번
    허위 타입 변경 diff를 낸다.
    """
    return Column(DateTime(timezone=True), index=index, nullable=nullable)


class ReceivingRecord(SQLModel, table=True):
    __tablename__ = "receiving_records"

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    wine_vintage_id: uuid.UUID = Field(
        foreign_key="wine_vintages.id", index=True, nullable=False
    )
    quantity: int = Field(nullable=False)
    received_at: datetime = Field(
        default_factory=_utcnow, sa_column=_tz_column(index=True)
    )
    staff_id: uuid.UUID = Field(foreign_key="users.id", index=True, nullable=False)
    memo: str | None = None  # FR12 — 입력 UI는 Story 4.3
    source: ReceivingSource = Field(
        default=ReceivingSource.receiving, index=True, nullable=False
    )
    # 재시도 중복 방지(Story 2.7). nullable — 키 없는 호출(스크립트·배치)을 막지 않는다.
    # PostgreSQL·SQLite 모두 unique 인덱스에서 NULL끼리는 충돌하지 않는다.
    idempotency_key: uuid.UUID | None = Field(default=None, unique=True, index=True)
    # soft-delete 전용 (AR6). 하드삭제 금지.
    deleted_at: datetime | None = Field(
        default=None, sa_column=_tz_column(index=True, nullable=True)
    )
    created_at: datetime = Field(default_factory=_utcnow, sa_column=_tz_column())
