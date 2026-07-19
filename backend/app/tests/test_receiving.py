"""Story 2.6 — 입고 확정 (FR7) + 현재고 집계."""
from __future__ import annotations

from collections.abc import Iterator
from datetime import UTC, datetime, timedelta

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.pool import StaticPool
from sqlmodel import Session, SQLModel, create_engine

from app.core.db import get_session
from app.crud import receiving as receiving_crud
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


def _token(client: TestClient, email: str = "s@wineerp.co") -> str:
    client.post(f"{API}/auth/signup", json={"email": email, "password": "pw123456"})
    return client.post(
        f"{API}/auth/login", data={"username": email, "password": "pw123456"}
    ).json()["access_token"]


def _a_vintage_id(client: TestClient, token: str) -> str:
    resp = client.post(
        f"{API}/scan",
        json={"code": "3760000000015"},
        headers={"Authorization": f"Bearer {token}"},
    )
    return resp.json()["products"][0]["vintages"][0]["id"]


def _create(client, token, vintage_id, quantity=1, memo=None):
    return client.post(
        f"{API}/receiving",
        json={"wine_vintage_id": vintage_id, "quantity": quantity, "memo": memo},
        headers={"Authorization": f"Bearer {token}"},
    )


def test_create_receiving_returns_201(client):
    token = _token(client)
    vid = _a_vintage_id(client, token)
    resp = _create(client, token, vid, quantity=12)
    assert resp.status_code == 201
    body = resp.json()
    assert body["quantity"] == 12
    assert body["wine_vintage_id"] == vid


def test_received_at_is_server_generated(client):
    """서버 시각이 유일한 출처. 클라이언트가 보내면 조용히 무시가 아니라 422로 거절한다."""
    token = _token(client)
    vid = _a_vintage_id(client, token)
    before = datetime.now(UTC) - timedelta(seconds=5)

    injected = client.post(
        f"{API}/receiving",
        json={
            "wine_vintage_id": vid,
            "quantity": 1,
            "received_at": "1999-01-01T00:00:00Z",  # 주입 시도
        },
        headers={"Authorization": f"Bearer {token}"},
    )
    assert injected.status_code == 422, "알 수 없는 필드는 시끄럽게 거절되어야 한다"

    ok = _create(client, token, vid, quantity=1)
    assert ok.status_code == 201
    received = datetime.fromisoformat(ok.json()["received_at"])
    if received.tzinfo is None:  # SQLite는 오프셋을 저장하지 않는다
        received = received.replace(tzinfo=UTC)
    assert received > before  # 1999년이 아니라 지금


def test_staff_id_comes_from_token_not_body(client):
    """body의 staff_id는 받지도 읽지도 않는다 — 감사 추적이 무의미해지면 안 된다."""
    token = _token(client, "real@wineerp.co")
    vid = _a_vintage_id(client, token)
    me = client.get(
        f"{API}/auth/me", headers={"Authorization": f"Bearer {token}"}
    ).json()

    spoofed = client.post(
        f"{API}/receiving",
        json={
            "wine_vintage_id": vid,
            "quantity": 1,
            "staff_id": "00000000-0000-0000-0000-000000000000",  # 사칭 시도
        },
        headers={"Authorization": f"Bearer {token}"},
    )
    assert spoofed.status_code == 422

    ok = _create(client, token, vid, quantity=1)
    assert ok.json()["staff_id"] == me["id"]  # 담당자는 토큰에서만


def test_quantity_upper_bound_is_422_not_500(client):
    """상한이 없으면 PostgreSQL INTEGER를 넘겨 500으로 터진다.

    ⚠️ 이 테스트는 SQLite에서 돌기 때문에 상한 검증(422)만 확인한다 —
    실제 오버플로는 재현되지 않는다. 그래서 상한이 스키마에 있어야 한다.
    """
    token = _token(client)
    vid = _a_vintage_id(client, token)
    assert _create(client, token, vid, quantity=3_000_000_000).status_code == 422
    assert _create(client, token, vid, quantity=1000).status_code == 422
    assert _create(client, token, vid, quantity=999).status_code == 201


def test_quantity_must_be_at_least_one(client):
    token = _token(client)
    vid = _a_vintage_id(client, token)
    assert _create(client, token, vid, quantity=0).status_code == 422
    assert _create(client, token, vid, quantity=-3).status_code == 422


def test_unknown_vintage_returns_404(client):
    token = _token(client)
    resp = _create(client, token, "00000000-0000-0000-0000-000000000000")
    assert resp.status_code == 404


def test_create_requires_auth(client):
    resp = client.post(
        f"{API}/receiving",
        json={"wine_vintage_id": "00000000-0000-0000-0000-000000000000", "quantity": 1},
    )
    assert resp.status_code == 401


def test_stock_map_sums_and_excludes_soft_deleted(client, session_factory):
    token = _token(client)
    vid = _a_vintage_id(client, token)
    _create(client, token, vid, quantity=5)
    _create(client, token, vid, quantity=7)
    cancelled = _create(client, token, vid, quantity=100).json()

    import uuid as _uuid

    vintage_uuid = _uuid.UUID(vid)
    with session_factory() as s:
        from app.models.receiving import ReceivingRecord

        rec = s.get(ReceivingRecord, _uuid.UUID(cancelled["id"]))
        rec.deleted_at = datetime.now(UTC)  # 취소는 soft-delete만(AR6)
        s.add(rec)
        s.commit()

        stock = receiving_crud.get_stock_map(s, [vintage_uuid])
    assert stock[vintage_uuid] == 12  # 100은 제외


def test_stock_map_returns_zero_for_untouched_vintage(client, session_factory):
    """기록 없는 빈티지도 키가 있어야 한다 — 없으면 호출부가 null 처리를 재발명한다."""
    with session_factory() as s:
        product = wine_crud.create_product(
            session=s, producer="Empty", model_name="Empty"
        )
        vintage = wine_crud.add_vintage(s, wine_product_id=product.id, vintage=2020)
        stock = receiving_crud.get_stock_map(s, [vintage.id])
    assert stock == {vintage.id: 0}


def test_scan_response_reflects_stock(client):
    token = _token(client)
    vid = _a_vintage_id(client, token)
    _create(client, token, vid, quantity=6)

    resp = client.post(
        f"{API}/scan",
        json={"code": "3760000000015"},
        headers={"Authorization": f"Bearer {token}"},
    )
    vintages = resp.json()["products"][0]["vintages"]
    by_id = {v["id"]: v["stock"] for v in vintages}
    assert by_id[vid] == 6
    # 입고 안 한 다른 빈티지는 0
    assert all(s == 0 for i, s in by_id.items() if i != vid)
