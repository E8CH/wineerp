"""DB 엔진/세션 — 지연 초기화.

DATABASE_URL 미설정이면 엔진을 만들지 않아 health가 DB에 의존하지 않는다.
"""
from __future__ import annotations

from collections.abc import Iterator

from sqlmodel import Session, create_engine

from app.core.config import settings

_engine = None


def get_engine():
    global _engine
    if _engine is None:
        if not settings.DATABASE_URL:
            raise RuntimeError(
                "DATABASE_URL 미설정 — DB가 필요한 기능(Story 1.2+)에서만 설정하세요."
            )
        _engine = create_engine(settings.DATABASE_URL, pool_pre_ping=True)
    return _engine


def get_session() -> Iterator[Session]:
    with Session(get_engine()) as session:
        yield session
