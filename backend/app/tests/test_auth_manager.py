"""Story 1.4 — 관리자 역할 분기 (FR2). manager 시드 후 역할 가드 검증."""
from __future__ import annotations

from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.pool import StaticPool
from sqlmodel import Session, SQLModel, create_engine

from app.core.db import get_session
from app.crud import user as user_crud
from app.main import app
from app.models.user import UserRole

API = "/api/v1/auth"


@pytest.fixture
def ctx() -> Iterator[tuple[TestClient, object]]:
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    SQLModel.metadata.create_all(engine)

    def _override() -> Iterator[Session]:
        with Session(engine) as s:
            yield s

    app.dependency_overrides[get_session] = _override
    with TestClient(app) as c:
        yield c, engine
    app.dependency_overrides.clear()


def _seed_manager(engine, email="boss@wineerp.co", password="pw123456"):
    with Session(engine) as s:
        user_crud.create_user(s, email=email, password=password, role=UserRole.manager)


def _token(client, email, password="pw123456"):
    return client.post(
        f"{API}/login", data={"username": email, "password": password}
    ).json()["access_token"]


def test_manager_me_returns_manager_role(ctx):
    client, engine = ctx
    _seed_manager(engine)
    token = _token(client, "boss@wineerp.co")
    resp = client.get(f"{API}/me", headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 200
    assert resp.json()["role"] == "manager"


def test_manager_can_create_manager(ctx):
    client, engine = ctx
    _seed_manager(engine)
    token = _token(client, "boss@wineerp.co")
    resp = client.post(
        f"{API}/managers",
        json={"email": "boss2@wineerp.co", "password": "pw123456"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 201
    assert resp.json()["role"] == "manager"


def test_staff_cannot_create_manager(ctx):
    client, engine = ctx
    # staff 가입 후 토큰
    client.post(f"{API}/signup", json={"email": "s@wineerp.co", "password": "pw123456"})
    token = _token(client, "s@wineerp.co")
    resp = client.post(
        f"{API}/managers",
        json={"email": "x@wineerp.co", "password": "pw123456"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 403


def test_create_manager_requires_auth(ctx):
    client, _ = ctx
    resp = client.post(
        f"{API}/managers", json={"email": "x@wineerp.co", "password": "pw123456"}
    )
    assert resp.status_code == 401
