"""Story 2.4 — 스캔 매칭 (FR5). 시드 후 바코드→후보 검증."""
from __future__ import annotations

from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.pool import StaticPool
from sqlmodel import Session, SQLModel, create_engine

from app.core.db import get_session
from app.crud import wine as wine_crud
from app.main import app
from app.seed.wines import seed_demo_wines

API = "/api/v1"


@pytest.fixture
def engine():
    eng = create_engine(
        "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool
    )
    SQLModel.metadata.create_all(eng)
    with Session(eng) as s:
        seed_demo_wines(s)
    return eng


@pytest.fixture
def session_factory(engine):
    """테스트가 시드 외 픽스처를 직접 추가할 때 사용."""

    def _factory() -> Session:
        return Session(engine)

    return _factory


@pytest.fixture
def client(engine) -> Iterator[TestClient]:
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
    # Story 2.5 — 정렬은 계약. 최신 빈티지 우선(sorted 우회 금지).
    assert [v["vintage"] for v in p["vintages"]] == [2018, 2015]


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


def test_vintages_sorted_desc_with_nv_last(client, session_factory):
    """Story 2.5 AC1 — 최신 빈티지 우선, NV(null)는 최후.

    ⚠️ PostgreSQL은 DESC에서 NULL이 먼저, SQLite는 나중에 온다.
    NULLS LAST를 명시하지 않으면 테스트만 통과하고 운영에서 NV가 맨 위로 올라온다.
    """
    with session_factory() as s:
        product = wine_crud.create_product(
            session=s, producer="Test Maison", model_name="Mixed Cuvée"
        )
        # 의도적으로 뒤섞인 순서로 삽입 — 삽입 순서에 의존하지 않음을 확인
        for v in (2011, None, 2020, 2015):
            wine_crud.add_vintage(s, wine_product_id=product.id, vintage=v)
        barcode = wine_crud.get_or_create_barcode(s, "TEST-MIXED-NV")
        wine_crud.link_barcode_to_product(
            s, barcode_id=barcode.id, wine_product_id=product.id
        )

    token = _token(client)
    resp = _scan(client, "TEST-MIXED-NV", token)
    assert resp.status_code == 200
    vintages = [v["vintage"] for v in resp.json()["products"][0]["vintages"]]
    assert vintages == [2020, 2015, 2011, None]


def test_scan_requires_auth(client):
    resp = client.post(f"{API}/scan", json={"code": "3760000000015"})
    assert resp.status_code == 401
