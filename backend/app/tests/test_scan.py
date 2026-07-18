"""Story 2.4 — 스캔 매칭 (FR5). 시드 후 바코드→후보 검증."""
from __future__ import annotations

from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.pool import StaticPool
from sqlmodel import Session, SQLModel, create_engine

from app.core.db import get_session
from app.main import app
from app.seed.wines import seed_demo_wines

API = "/api/v1"


@pytest.fixture
def client() -> Iterator[TestClient]:
    engine = create_engine(
        "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool
    )
    SQLModel.metadata.create_all(engine)
    with Session(engine) as s:
        seed_demo_wines(s)

    def _session() -> Iterator[Session]:
        with Session(engine) as s:
            yield s

    app.dependency_overrides[get_session] = _session
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()


def _token(client: TestClient) -> str:
    client.post(f"{API}/auth/signup", json={"email": "s@wineerp.co", "password": "pw123456"})
    return client.post(
        f"{API}/auth/login", data={"username": "s@wineerp.co", "password": "pw123456"}
    ).json()["access_token"]


def _scan(client, code, token):
    return client.post(
        f"{API}/scan", json={"code": code}, headers={"Authorization": f"Bearer {token}"}
    )


def test_scan_known_barcode_returns_product_and_vintages(client):
    token = _token(client)
    resp = _scan(client, "3760000000015", token)  # 샤토 마고 (2 빈티지)
    assert resp.status_code == 200
    body = resp.json()
    assert len(body["products"]) == 1
    p = body["products"][0]
    assert p["model_name"] == "Château Margaux"
    assert sorted(v["vintage"] for v in p["vintages"]) == [2015, 2018]


def test_scan_shared_barcode_returns_multiple_products(client):
    token = _token(client)
    resp = _scan(client, "SHARED-8801234567890", token)
    assert resp.status_code == 200
    names = sorted(p["model_name"] for p in resp.json()["products"])
    assert names == ["Geyserville", "Monte Bello"]


def test_scan_nv_vintage_is_null(client):
    token = _token(client)
    resp = _scan(client, "3185370000060", token)  # Moët NV
    p = resp.json()["products"][0]
    assert p["vintages"][0]["vintage"] is None


def test_scan_unknown_barcode_empty(client):
    token = _token(client)
    resp = _scan(client, "0000000000000", token)
    assert resp.status_code == 200
    assert resp.json()["products"] == []


def test_scan_requires_auth(client):
    resp = client.post(f"{API}/scan", json={"code": "3760000000015"})
    assert resp.status_code == 401
