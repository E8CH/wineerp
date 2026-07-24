"""감사 로그 — 누가 무엇을 넣고·고치고·지웠는지 (활동 이력).

한 곳에서 모든 변경을 시간순으로 본다. 기존 테이블에서 유도하지 않고 전용 테이블을 두는
이유: (1) 모델 등록·수정·삭제에는 지금까지 행위자가 전혀 남지 않았고(입고만 staff_id가
있었다), (2) 와인이 나중에 개명·아카이브돼도 "그때 무엇이었나"가 흔들리면 안 되며,
(3) 여러 종류의 이벤트를 한 리스트로 합치려면 union 쿼리보다 단일 테이블이 견고하다.

⚠️ **비정규화가 의도다.** actor_email·summary는 이벤트 시점의 스냅샷이다. 행위자를
FK로만 걸어 두면 그 사용자가 개명되거나 삭제됐을 때 과거 로그의 표기가 바뀐다 —
감사 로그는 "그 시점에 이렇게 보였다"를 보존해야 한다. detail(JSON)은 상세 화면용
구조화 데이터(before/after 등)를 담는다.
"""
from __future__ import annotations

import uuid
from datetime import UTC, datetime
from enum import StrEnum
from typing import Any

from sqlalchemy import JSON, Column, DateTime
from sqlmodel import Field, SQLModel


class AuditAction(StrEnum):
    """기록되는 변경의 종류. 값은 그대로 와이어로 나가 프론트가 한글 라벨로 매핑한다."""

    receiving_create = "receiving.create"
    receiving_amend = "receiving.amend"
    receiving_cancel = "receiving.cancel"
    wine_create = "wine.create"
    wine_update = "wine.update"
    wine_archive = "wine.archive"
    wine_initial_setup = "wine.initial_setup"


def _utcnow() -> datetime:
    return datetime.now(UTC)


class AuditLog(SQLModel, table=True):
    __tablename__ = "audit_logs"

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    action: AuditAction = Field(index=True, nullable=False)
    # 행위자. FK는 참조 무결성용이지만 표시는 denormalized actor_email으로 한다
    # (개명·삭제돼도 과거 로그가 흔들리지 않게).
    actor_id: uuid.UUID | None = Field(
        default=None, foreign_key="users.id", index=True
    )
    actor_email: str = Field(nullable=False)
    # 리스트에 한 줄로 뜨는 사람이 읽는 요약(예: "Château Margaux 2015 · 12병 입고").
    summary: str = Field(nullable=False)
    # 대상 종류/식별자 — 상세·필터용. FK는 걸지 않는다(대상 테이블이 여러 개고,
    # 아카이브·삭제돼도 로그는 남아야 한다).
    entity_type: str = Field(nullable=False)
    entity_id: uuid.UUID | None = Field(default=None, index=True)
    # 상세 화면용 구조화 데이터(before/after, 수량, 메모 등). 스키마는 action마다 다르다.
    detail: dict[str, Any] = Field(default_factory=dict, sa_column=Column(JSON))
    created_at: datetime = Field(
        default_factory=_utcnow,
        sa_column=Column(DateTime(timezone=True), index=True, nullable=False),
    )
