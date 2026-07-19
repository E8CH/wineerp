"""Story 5.1 — 종합 리포트 (FR10). manager 전용 + KST 일별 버킷."""
from __future__ import annotations

import uuid as _uuid
from collections.abc import Iterator
from datetime import UTC, datetime

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.pool import StaticPool
from sqlmodel import Session, SQLModel, create_engine, select

from app.core.db import get_session
from app.main import app
from app.models.receiving import ReceivingRecord, ReceivingSource
from app.models.user import User, UserRole
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


def _token(client, email="staff@wineerp.co") -> str:
    client.post(f"{API}/auth/signup", json={"email": email, "password": "pw123456"})
    return client.post(
        f"{API}/auth/login", data={"username": email, "password": "pw123456"}
    ).json()["access_token"]


def _manager(client, engine) -> str:
    token = _token(client, "mgr@wineerp.co")
    with Session(engine) as s:
        user = s.exec(select(User).where(User.email == "mgr@wineerp.co")).one()
        user.role = UserRole.manager
        s.add(user)
        s.commit()
    return token


def _h(t):
    return {"Authorization": f"Bearer {t}"}


def _vids(client, token) -> list[str]:
    return [
        v["id"]
        for v in client.post(
            f"{API}/scan", json={"code": "3760000000015"}, headers=_h(token)
        ).json()["products"][0]["vintages"]
    ]


def _staff_id(client, token) -> str:
    return client.get(f"{API}/auth/me", headers=_h(token)).json()["id"]


def _insert(engine, *, vid, sid, at, qty, **kw):
    with Session(engine) as s:
        s.add(
            ReceivingRecord(
                wine_vintage_id=_uuid.UUID(vid),
                staff_id=_uuid.UUID(sid),
                quantity=qty,
                received_at=at,
                **kw,
            )
        )
        s.commit()


def _report(client, token, **params):
    return client.get(f"{API}/reports/receiving", params=params, headers=_h(token))


# --- 권한 ---------------------------------------------------------------------


def test_staff_gets_403(client, engine):
    assert _report(client, _token(client), period="week").status_code == 403


def test_manager_gets_200(client, engine):
    assert _report(client, _manager(client, engine), period="week").status_code == 200


def test_requires_auth(client):
    assert client.get(f"{API}/reports/receiving").status_code == 401


def test_day_period_is_rejected(client, engine):
    """일간은 막대가 하나뿐이라 그래프의 의미가 없다."""
    assert _report(client, _manager(client, engine), period="day").status_code == 422


# --- 집계 ---------------------------------------------------------------------


def test_buckets_use_korean_calendar_day(client, engine):
    """🔴 UTC로 묶으면 오전 입고가 전날 막대로 간다."""
    staff = _token(client)
    vid, sid = _vids(client, staff)[0], _staff_id(client, staff)
    # KST 2026-07-15 08:00 == UTC 2026-07-14 23:00
    _insert(engine, vid=vid, sid=sid, at=datetime(2026, 7, 14, 23, 0, tzinfo=UTC), qty=5)

    mgr = _manager(client, engine)
    body = _report(client, mgr, period="month", anchor="2026-07-15").json()
    by_date = {b["date"]: b["quantity"] for b in body["buckets"]}
    assert by_date["2026-07-15"] == 5
    assert by_date["2026-07-14"] == 0


def test_empty_days_are_filled_with_zero(client, engine):
    """빼면 막대가 붙어 그려지고 "매일 들어왔다"로 읽힌다."""
    staff = _token(client)
    vid, sid = _vids(client, staff)[0], _staff_id(client, staff)
    _insert(engine, vid=vid, sid=sid, at=datetime(2026, 7, 15, 3, 0, tzinfo=UTC), qty=2)

    mgr = _manager(client, engine)
    body = _report(client, mgr, period="week", anchor="2026-07-15").json()
    assert len(body["buckets"]) == 7, "주간은 항상 7개 막대"
    assert sum(1 for b in body["buckets"] if b["quantity"] == 0) == 6


def test_month_has_one_bucket_per_day(client, engine):
    mgr = _manager(client, engine)
    body = _report(client, mgr, period="month", anchor="2026-07-15").json()
    assert len(body["buckets"]) == 31  # 7월


def test_top_products_sorted_by_quantity(client, engine):
    staff = _token(client)
    vids, sid = _vids(client, staff), _staff_id(client, staff)
    at = datetime(2026, 7, 15, 3, 0, tzinfo=UTC)
    _insert(engine, vid=vids[0], sid=sid, at=at, qty=3)
    _insert(engine, vid=vids[1], sid=sid, at=at, qty=9)

    mgr = _manager(client, engine)
    body = _report(client, mgr, period="week", anchor="2026-07-15").json()
    # 같은 제품의 두 빈티지 → 제품 단위로 합산된다
    assert body["top_products"][0]["quantity"] == 12
    assert body["total_quantity"] == 12
    assert body["distinct_wines"] == 2
    assert body["record_count"] == 2


def test_initial_setup_is_included(client, engine):
    """재고에 반영되는 수량이 리포트에 없으면 관리자가 무엇을 믿을지 모른다."""
    staff = _token(client)
    vid, sid = _vids(client, staff)[0], _staff_id(client, staff)
    at = datetime(2026, 7, 15, 3, 0, tzinfo=UTC)
    _insert(engine, vid=vid, sid=sid, at=at, qty=4)
    _insert(
        engine, vid=vid, sid=sid, at=at, qty=6, source=ReceivingSource.initial_setup
    )

    mgr = _manager(client, engine)
    body = _report(client, mgr, period="week", anchor="2026-07-15").json()
    assert body["total_quantity"] == 10


def test_soft_deleted_excluded(client, engine):
    staff = _token(client)
    vid, sid = _vids(client, staff)[0], _staff_id(client, staff)
    at = datetime(2026, 7, 15, 3, 0, tzinfo=UTC)
    _insert(engine, vid=vid, sid=sid, at=at, qty=4)
    _insert(engine, vid=vid, sid=sid, at=at, qty=99, deleted_at=datetime.now(UTC))

    mgr = _manager(client, engine)
    body = _report(client, mgr, period="week", anchor="2026-07-15").json()
    assert body["total_quantity"] == 4


def test_empty_period_returns_zero_buckets_not_error(client, engine):
    mgr = _manager(client, engine)
    body = _report(client, mgr, period="week", anchor="2020-01-01").json()
    assert body["total_quantity"] == 0
    assert body["top_products"] == []
    assert all(b["quantity"] == 0 for b in body["buckets"])
