"""Story 1.2 — User 모델·CRUD·해시·DATABASE_URL 정규화 검증 (SQLite in-memory)."""
from __future__ import annotations

import pytest
from sqlalchemy.exc import IntegrityError
from sqlalchemy.pool import StaticPool
from sqlmodel import Session, SQLModel, create_engine

from app.core.config import normalize_db_url
from app.core.security import get_password_hash, verify_password
from app.crud.user import create_user, get_user_by_email
from app.models.user import User, UserRole


@pytest.fixture
def session():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    SQLModel.metadata.create_all(engine)
    with Session(engine) as s:
        yield s


# --- AC5: 스킴 정규화 (DB 불필요) ---
@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        ("postgresql://u:p@h:5432/db", "postgresql+psycopg://u:p@h:5432/db"),
        ("postgres://u:p@h:5432/db", "postgresql+psycopg://u:p@h:5432/db"),
        ("postgresql+psycopg://u:p@h/db", "postgresql+psycopg://u:p@h/db"),
        (None, None),
    ],
)
def test_normalize_db_url(raw, expected):
    assert normalize_db_url(raw) == expected


# --- AC4: 비밀번호 해시 ---
def test_password_hash_roundtrip():
    h = get_password_hash("s3cret!")
    assert h != "s3cret!"
    assert verify_password("s3cret!", h)
    assert not verify_password("wrong", h)


# --- AC1,2: User 생성·역할 기본 ---
def test_create_user_defaults(session):
    user = create_user(session, email="a@wineerp.co", password="pw123456")
    assert isinstance(user.id.hex, str)
    assert user.email == "a@wineerp.co"
    assert user.role == UserRole.staff  # 기본 staff
    assert user.is_active is True
    assert user.hashed_password != "pw123456"  # 평문 미저장
    assert user.created_at is not None


def test_create_manager_and_lookup(session):
    create_user(session, email="m@wineerp.co", password="pw", role=UserRole.manager)
    found = get_user_by_email(session, "m@wineerp.co")
    assert found is not None
    assert found.role == UserRole.manager
    assert get_user_by_email(session, "nobody@wineerp.co") is None


# --- AC1: email unique ---
def test_email_unique(session):
    create_user(session, email="dup@wineerp.co", password="pw")
    with pytest.raises(IntegrityError):
        u = User(email="dup@wineerp.co", hashed_password="x")
        session.add(u)
        session.commit()
