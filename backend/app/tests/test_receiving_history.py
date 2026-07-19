"""Story 4.1 — 입고 내역 조회 (FR9). KST 경계가 핵심."""
from __future__ import annotations

import uuid as _uuid
from collections.abc import Iterator
from datetime import UTC, date, datetime

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.pool import StaticPool
from sqlmodel import Session, SQLModel, create_engine

from app.core.db import get_session
from app.core.timeframe import Period, period_bounds
from app.main import app
from app.models.receiving import ReceivingRecord, ReceivingSource
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
    client.post(f"{API}/auth/signup", json={"email": "h@wineerp.co", "password": "pw123456"})
    return client.post(
        f"{API}/auth/login", data={"username": "h@wineerp.co", "password": "pw123456"}
    ).json()["access_token"]


def _vintage_id(client, token) -> str:
    return client.post(
        f"{API}/scan",
        json={"code": "3760000000015"},
        headers={"Authorization": f"Bearer {token}"},
    ).json()["products"][0]["vintages"][0]["id"]


def _staff_id(client, token) -> str:
    return client.get(
        f"{API}/auth/me", headers={"Authorization": f"Bearer {token}"}
    ).json()["id"]


def _insert(engine, *, vintage_id, staff_id, received_at, quantity=1, **kw):
    with Session(engine) as s:
        rec = ReceivingRecord(
            wine_vintage_id=_uuid.UUID(vintage_id),
            staff_id=_uuid.UUID(staff_id),
            quantity=quantity,
            received_at=received_at,
            **kw,
        )
        s.add(rec)
        s.commit()
        s.refresh(rec)
        return rec


def _history(client, token, **params):
    return client.get(
        f"{API}/receiving",
        params=params,
        headers={"Authorization": f"Bearer {token}"},
    )


# --- KST 경계 -----------------------------------------------------------------


def test_period_bounds_are_kst_not_utc():
    """UTC로 자르면 오전 9시(KST) 이전 입고가 전부 전날로 분류된다."""
    start, end = period_bounds(Period.day, date(2026, 7, 19))
    # KST 2026-07-19 00:00 == UTC 2026-07-18 15:00
    assert start == datetime(2026, 7, 18, 15, 0, tzinfo=UTC)
    assert end == datetime(2026, 7, 19, 15, 0, tzinfo=UTC)


def test_week_starts_on_monday():
    # 2026-07-19는 일요일 → 그 주의 월요일은 07-13
    start, _ = period_bounds(Period.week, date(2026, 7, 19))
    assert start == datetime(2026, 7, 12, 15, 0, tzinfo=UTC)  # KST 07-13 00:00


def test_month_covers_first_to_last_day():
    start, end = period_bounds(Period.month, date(2026, 7, 19))
    assert start == datetime(2026, 6, 30, 15, 0, tzinfo=UTC)  # KST 07-01 00:00
    assert end == datetime(2026, 7, 31, 15, 0, tzinfo=UTC)  # KST 08-01 00:00


def test_morning_receiving_lands_on_the_correct_korean_day(client, engine):
    """🔴 이 테스트가 KST 변환의 유일한 방어선이다.

    UTC 자정을 사이에 둔 두 레코드를 넣는다. 변환이 없으면 둘이 다른 날로 갈린다.
    """
    token = _token(client)
    vid, sid = _vintage_id(client, token), _staff_id(client, token)

    # KST 2026-07-19 08:00 == UTC 2026-07-18 23:00 (UTC 기준으론 '전날')
    morning = _insert(
        engine, vintage_id=vid, staff_id=sid,
        received_at=datetime(2026, 7, 18, 23, 0, tzinfo=UTC), quantity=5,
    )
    # KST 2026-07-19 20:00 == UTC 2026-07-19 11:00
    evening = _insert(
        engine, vintage_id=vid, staff_id=sid,
        received_at=datetime(2026, 7, 19, 11, 0, tzinfo=UTC), quantity=7,
    )

    body = _history(client, token, period="day", anchor="2026-07-19").json()
    ids = {item["id"] for item in body["data"]}
    assert str(morning.id) in ids, "오전 입고가 전날로 새면 안 된다"
    assert str(evening.id) in ids
    assert body["count"] == 2


def test_previous_korean_day_is_excluded(client, engine):
    token = _token(client)
    vid, sid = _vintage_id(client, token), _staff_id(client, token)
    # KST 2026-07-18 23:00 == UTC 2026-07-18 14:00 → 전날에 속한다
    _insert(
        engine, vintage_id=vid, staff_id=sid,
        received_at=datetime(2026, 7, 18, 14, 0, tzinfo=UTC),
    )
    assert _history(client, token, period="day", anchor="2026-07-19").json()["count"] == 0


# --- 필터·정렬·내용 ------------------------------------------------------------


def test_soft_deleted_records_are_excluded(client, engine):
    token = _token(client)
    vid, sid = _vintage_id(client, token), _staff_id(client, token)
    at = datetime(2026, 7, 19, 3, 0, tzinfo=UTC)
    _insert(engine, vintage_id=vid, staff_id=sid, received_at=at)
    _insert(
        engine, vintage_id=vid, staff_id=sid, received_at=at,
        deleted_at=datetime.now(UTC),
    )
    assert _history(client, token, period="day", anchor="2026-07-19").json()["count"] == 1


def test_newest_first(client, engine):
    token = _token(client)
    vid, sid = _vintage_id(client, token), _staff_id(client, token)
    _insert(
        engine, vintage_id=vid, staff_id=sid, quantity=1,
        received_at=datetime(2026, 7, 19, 1, 0, tzinfo=UTC),
    )
    _insert(
        engine, vintage_id=vid, staff_id=sid, quantity=2,
        received_at=datetime(2026, 7, 19, 5, 0, tzinfo=UTC),
    )
    data = _history(client, token, period="day", anchor="2026-07-19").json()["data"]
    assert [d["quantity"] for d in data] == [2, 1]


def test_row_carries_wine_staff_memo_and_source(client, engine):
    token = _token(client)
    vid, sid = _vintage_id(client, token), _staff_id(client, token)
    _insert(
        engine, vintage_id=vid, staff_id=sid,
        received_at=datetime(2026, 7, 19, 3, 0, tzinfo=UTC),
        memo="라벨 파손", source=ReceivingSource.initial_setup,
    )
    item = _history(client, token, period="day", anchor="2026-07-19").json()["data"][0]
    assert item["model_name"] == "Château Margaux"
    assert item["staff_email"] == "h@wineerp.co"
    assert item["memo"] == "라벨 파손"
    assert item["source"] == "initial_setup", "초기 세팅분을 입고로 읽으면 안 된다"
    assert "vintage" in item


def test_empty_period_returns_empty_list(client):
    token = _token(client)
    body = _history(client, token, period="day", anchor="2020-01-01").json()
    assert body == {"data": [], "count": 0}


def test_history_requires_auth(client):
    assert client.get(f"{API}/receiving").status_code == 401
