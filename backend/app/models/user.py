"""User 엔티티 — 인증·역할의 데이터 토대.

역할(`role`)이 권한의 단일 기준(staff|manager). is_superuser 사용 금지(anti-pattern).
"""
from __future__ import annotations

import uuid
from datetime import UTC, datetime
from enum import StrEnum

from sqlalchemy import Column, DateTime
from sqlmodel import Field, SQLModel


class UserRole(StrEnum):
    staff = "staff"
    manager = "manager"


def _utcnow() -> datetime:
    return datetime.now(UTC)


def _tz_column() -> Column:
    """`_utcnow()`가 aware datetime을 주므로 컬럼도 timestamptz여야 한다.

    SQLModel 기본 `datetime`은 TIMESTAMP WITHOUT TIME ZONE으로 생성되어 마이그레이션
    (0001·0002, timezone=True)과 어긋난다. 어긋난 채 두면 `alembic revision --autogenerate`가
    매번 허위 타입 변경 diff를 낸다.
    """
    return Column(DateTime(timezone=True), nullable=False)


class User(SQLModel, table=True):
    __tablename__ = "users"

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    email: str = Field(unique=True, index=True, nullable=False)
    hashed_password: str = Field(nullable=False)
    role: UserRole = Field(default=UserRole.staff, nullable=False)
    is_active: bool = Field(default=True, nullable=False)
    created_at: datetime = Field(default_factory=_utcnow, sa_column=_tz_column())
