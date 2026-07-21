"""Story 6.2 — 재고 목록 (GET /inventory).

빈티지(재고 단위) 단위로 현재고를 돌려준다. 리포트와 달리 역할 가드 없음(직원 열람).
"""
from __future__ import annotations

import uuid as _uuid
from collections.abc import Iterator
from datetime import UTC, datetime

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.pool import StaticPool
from sqlmodel import Session, SQLModel, create_engine

from app.core.db import get_session
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


def _token(client, email="staff@wineerp.co") -> str:
    client.post(f"{API}/auth/signup", json={"email": email, "password": "pw123456"})
    return client.post(
        f"{API}/auth/login", data={"username": email, "password": "pw123456"}
    ).json()["access_token"]


def _h(t):
    return {"Authorization": f"Bearer {t}"}


def _inventory(client, token):
    return client.get(f"{API}/inventory", headers=_h(token))


def _staff_id(client, token) -> str:
    return client.get(f"{API}/auth/me", headers=_h(token)).json()["id"]


def _vids(client, token, code="3760000000015") -> list[str]:
    return [
        v["id"]
        for v in client.post(
            f"{API}/scan", json={"code": code}, headers=_h(token)
        ).json()["products"][0]["vintages"]
    ]


def _insert(engine, *, vid, sid, qty, **kw):
    with Session(engine) as s:
        s.add(
            ReceivingRecord(
                wine_vintage_id=_uuid.UUID(vid),
                staff_id=_uuid.UUID(sid),
                quantity=qty,
                received_at=datetime(2026, 7, 15, 3, 0, tzinfo=UTC),
                **kw,
            )
        )
        s.commit()


# --- 권한 --------------------------------------------------------------------


def test_requires_auth(client):
    assert client.get(f"{API}/inventory").status_code == 401


def test_staff_can_view_inventory(client, engine):
    """리포트는 manager 전용이지만 재고 열람은 운영 정보 — 직원도 봐야 한다."""
    assert _inventory(client, _token(client)).status_code == 200


# --- 목록 구성 ----------------------------------------------------------------


def test_lists_every_seed_vintage(client, engine):
    """행은 빈티지 단위. 시드 10종의 빈티지 15개가 모두 나온다."""
    body = _inventory(client, _token(client)).json()
    assert len(body) == 15


def test_zero_stock_wine_still_listed(client, engine):
    """등록됐지만 아직 안 받은 마스터도 재고 0으로 보인다 — 숨기면 "왜 안 보이지"가 된다.

    이 테스트의 이빨은 **조인 방향**에 있다: `list_inventory_rows`가 product⋈vintage로
    조인하므로 receiving이 0건이어도 행이 남는다. receiving을 inner join하도록 바꾸면
    재고 0 와인이 통째로 사라지고 이 단언(15종 전부)이 깨진다. (get_stock_map의 0-fill은
    라우트의 `stock.get(v.id, 0)`이 이중으로 막으므로 여기서 검증 대상이 아니다.)
    """
    body = _inventory(client, _token(client)).json()
    assert all(item["stock"] == 0 for item in body)
    assert len(body) == 15


def test_nv_vintage_is_null_not_missing(client, engine):
    """NV(Moët)는 vintage=null. 빠진 값이 아니라 유효 상태다."""
    body = _inventory(client, _token(client)).json()
    moet = [i for i in body if i["producer"] == "Moët & Chandon"]
    assert len(moet) == 1
    assert moet[0]["vintage"] is None


# --- 현재고 집계 --------------------------------------------------------------


def test_stock_reflects_receiving_sum(client, engine):
    staff = _token(client)
    vid, sid = _vids(client, staff)[0], _staff_id(client, staff)
    _insert(engine, vid=vid, sid=sid, qty=4)
    _insert(engine, vid=vid, sid=sid, qty=6)

    body = _inventory(client, staff).json()
    item = next(i for i in body if i["vintage_id"] == vid)
    assert item["stock"] == 10


def test_initial_setup_counts_toward_stock(client, engine):
    """재고는 한 곳(get_stock_map)에서만 세므로 세팅분도 포함된다 — 리포트와 일관."""
    staff = _token(client)
    vid, sid = _vids(client, staff)[0], _staff_id(client, staff)
    _insert(engine, vid=vid, sid=sid, qty=3, source=ReceivingSource.initial_setup)

    body = _inventory(client, staff).json()
    item = next(i for i in body if i["vintage_id"] == vid)
    assert item["stock"] == 3


def test_soft_deleted_excluded_from_stock(client, engine):
    staff = _token(client)
    vid, sid = _vids(client, staff)[0], _staff_id(client, staff)
    _insert(engine, vid=vid, sid=sid, qty=4)
    _insert(engine, vid=vid, sid=sid, qty=99, deleted_at=datetime.now(UTC))

    body = _inventory(client, staff).json()
    item = next(i for i in body if i["vintage_id"] == vid)
    assert item["stock"] == 4


# --- 정렬 계약 ----------------------------------------------------------------


def test_sorted_by_producer_then_newest_vintage_first(client, engine):
    body = _inventory(client, _token(client)).json()

    producers = [i["producer"] for i in body]
    assert producers == sorted(producers), "생산자 알파벳순으로 묶인다"

    # 같은 생산자 행이 흩어지지 않고 인접해야 한다(정렬 1순위 = producer).
    # producers==sorted만으로는 두 생산자 사이에 끼어드는 경우를 못 잡는다.
    runs = [p for j, p in enumerate(producers) if j == 0 or producers[j - 1] != p]
    assert len(runs) == len(set(producers)), "같은 생산자 행이 인접해야 한다"

    margaux = [i["vintage"] for i in body if i["producer"] == "Château Margaux"]
    assert margaux == [2018, 2015], "같은 와인 안에서는 최신 빈티지가 위"


def test_nv_sorts_after_years_within_same_product(client, engine):
    """한 제품 안에 NV와 연도가 섞이면 NV가 맨 끝 — 시드엔 이 조합이 없어 직접 만든다.

    실행 테스트는 SQLite라 NULL이 원래 마지막이라 이것만으로는 `nullslast`를 증명하지
    못한다(아래 Postgres 컴파일 테스트가 그 공백을 메운다). 그래도 반환 목록의 관측 가능한
    순서 계약은 여기서 고정한다.
    """
    from app.crud import wine as wine_crud

    with Session(engine) as s:
        p = wine_crud.create_product(
            session=s, producer="ZZZ Estate", model_name="Mixed Bag"
        )
        for yr in (2015, None, 2020):
            wine_crud.add_vintage(s, wine_product_id=p.id, vintage=yr)

    body = _inventory(client, _token(client)).json()
    mixed = [i["vintage"] for i in body if i["producer"] == "ZZZ Estate"]
    assert mixed == [2020, 2015, None], "최신 연도 우선, NV는 맨 끝"


def test_inventory_order_sql_is_correct_on_postgres():
    """운영 방언(PostgreSQL)에서 프로덕션 정렬 구문이 내는 SQL을 검사한다.

    ⚠️ 반드시 `inventory_rows_stmt`를 호출한다 — 테스트가 구문을 재작성하면 프로덕션을
    바꿔도 자기 사본만 검사해 초록불로 남는다(이 프로젝트 상습 결함). 실행 테스트는
    SQLite에서만 돌아 `nullslast` 회귀를 못 잡으므로, 이 컴파일 단언이 그 공백을 메운다.
    """
    from sqlalchemy.dialects import postgresql

    from app.crud import wine as wine_crud

    stmt = wine_crud.inventory_rows_stmt()
    sql = " ".join(str(stmt.compile(dialect=postgresql.dialect())).split())
    assert "wine_vintages.vintage DESC NULLS LAST, wine_vintages.id" in sql, sql
