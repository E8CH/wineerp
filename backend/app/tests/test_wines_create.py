"""Story 3.2 — 신규 와인 등록 (FR6)."""
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
def engine():
    eng = create_engine(
        "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool
    )
    SQLModel.metadata.create_all(eng)
    with Session(eng) as s:
        seed_demo_wines(s)
    return eng


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
    client.post(f"{API}/auth/signup", json={"email": "w@wineerp.co", "password": "pw123456"})
    return client.post(
        f"{API}/auth/login", data={"username": "w@wineerp.co", "password": "pw123456"}
    ).json()["access_token"]


def _create(client, token, **kwargs):
    body = {"producer": "Test Maison", "model_name": "Cuvée Test", **kwargs}
    return client.post(
        f"{API}/wines", json=body, headers={"Authorization": f"Bearer {token}"}
    )


def _scan(client, token, code):
    return client.post(
        f"{API}/scan", json={"code": code}, headers={"Authorization": f"Bearer {token}"}
    )


def test_create_wine_returns_201_with_ids(client):
    token = _token(client)
    resp = _create(client, token, vintage=2019)
    assert resp.status_code == 201
    body = resp.json()
    assert body["product_id"] and body["vintage_id"]


def test_nv_registration_stores_null_vintage(client):
    """NV는 인식 실패가 아니라 유효 상태다(AR2)."""
    token = _token(client)
    resp = _create(client, token, barcode="NEW-NV-0001")  # vintage 미지정 = NV
    assert resp.status_code == 201

    scanned = _scan(client, token, "NEW-NV-0001").json()
    vintages = scanned["products"][0]["vintages"]
    assert len(vintages) == 1
    assert vintages[0]["vintage"] is None


def test_barcode_is_linked_and_immediately_scannable(client):
    """등록 직후 같은 바코드를 스캔하면 매칭되어야 한다 — 그게 등록의 목적이다."""
    token = _token(client)
    assert _scan(client, token, "NEW-CODE-777").json()["products"] == []

    _create(client, token, vintage=2020, barcode="NEW-CODE-777")

    products = _scan(client, token, "NEW-CODE-777").json()["products"]
    assert len(products) == 1
    assert products[0]["model_name"] == "Cuvée Test"
    assert products[0]["vintages"][0]["vintage"] == 2020


def test_existing_barcode_is_reused_not_duplicated(client):
    """이미 있는 바코드에 새 제품을 붙이면 N:M으로 둘 다 나와야 한다(AR3)."""
    token = _token(client)
    _create(client, token, vintage=2020, barcode="3760000000015")  # 샤토 마고 바코드

    products = _scan(client, token, "3760000000015").json()["products"]
    names = sorted(p["model_name"] for p in products)
    assert names == ["Château Margaux", "Cuvée Test"]


def test_registration_without_barcode_is_valid(client):
    """바코드 없는 와인이 절반가량이라는 것이 이 제품의 전제다."""
    assert _create(client, _token(client), vintage=2018).status_code == 201


def test_required_fields_are_enforced(client):
    token = _token(client)
    resp = client.post(
        f"{API}/wines",
        json={"producer": "", "model_name": "X"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 422
    assert _create(client, token, vintage=1500).status_code == 422  # 비현실적 연도


def test_unknown_field_is_rejected(client):
    """extra='forbid' — 클라이언트/서버 필드 드리프트를 경계에서 잡는다."""
    token = _token(client)
    resp = client.post(
        f"{API}/wines",
        json={"producer": "A", "model_name": "B", "staff_id": "x"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 422


def test_create_requires_auth(client):
    resp = client.post(f"{API}/wines", json={"producer": "A", "model_name": "B"})
    assert resp.status_code == 401
