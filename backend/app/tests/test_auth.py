"""Story 1.3 — 가입/로그인/현재사용자 (FR1). TestClient + SQLite 세션 오버라이드."""
from __future__ import annotations

from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.pool import StaticPool
from sqlmodel import Session, SQLModel, create_engine

from app.core.db import get_session
from app.main import app

API = "/api/v1/auth"


@pytest.fixture
def client() -> Iterator[TestClient]:
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
        yield c
    app.dependency_overrides.clear()


def _signup(client: TestClient, email="staff@wineerp.co", password="pw123456"):
    return client.post(f"{API}/signup", json={"email": email, "password": password})


def test_signup_creates_staff(client):
    resp = _signup(client)
    assert resp.status_code == 201
    body = resp.json()
    assert body["email"] == "staff@wineerp.co"
    assert body["role"] == "staff"
    assert "hashed_password" not in body and "password" not in body


def test_signup_duplicate_rejected(client):
    _signup(client)
    resp = _signup(client)
    assert resp.status_code == 400


def test_login_returns_token(client):
    _signup(client)
    resp = client.post(
        f"{API}/login",
        data={"username": "staff@wineerp.co", "password": "pw123456"},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["token_type"] == "bearer"
    assert body["access_token"]


def test_login_wrong_password_401(client):
    _signup(client)
    resp = client.post(
        f"{API}/login",
        data={"username": "staff@wineerp.co", "password": "WRONG"},
    )
    assert resp.status_code == 401


def test_login_unknown_user_401(client):
    resp = client.post(
        f"{API}/login",
        data={"username": "nobody@wineerp.co", "password": "x"},
    )
    assert resp.status_code == 401


def test_me_with_token(client):
    _signup(client)
    token = client.post(
        f"{API}/login",
        data={"username": "staff@wineerp.co", "password": "pw123456"},
    ).json()["access_token"]
    resp = client.get(f"{API}/me", headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 200
    assert resp.json()["email"] == "staff@wineerp.co"


def test_me_without_token_401(client):
    resp = client.get(f"{API}/me")
    assert resp.status_code == 401
