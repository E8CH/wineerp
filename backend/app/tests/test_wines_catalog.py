"""Story 7.x — 모델 카탈로그(목록·상세·수정·삭제=아카이브).

삭제는 아카이브다: 카탈로그·재고·리포트·스캔에서 빠지되 입고기록(원장, 5년 보존)은
남고, 바코드 링크만 제거해 같은 모델을 충돌 없이 재등록할 수 있다.
"""
from __future__ import annotations

import uuid as _uuid
from collections.abc import Iterator
from datetime import UTC, datetime, timedelta

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.pool import StaticPool
from sqlmodel import Session, SQLModel, create_engine, select

from app.core.db import get_session
from app.main import app
from app.models.receiving import ReceivingRecord
from app.models.user import User, UserRole

API = "/api/v1"


@pytest.fixture
def engine():
    eng = create_engine(
        "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool
    )
    SQLModel.metadata.create_all(eng)
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


def _token(client: TestClient, email="staff@wineerp.co") -> str:
    client.post(f"{API}/auth/signup", json={"email": email, "password": "pw123456"})
    return client.post(
        f"{API}/auth/login", data={"username": email, "password": "pw123456"}
    ).json()["access_token"]


def _manager_token(client: TestClient, engine) -> str:
    token = _token(client, "mgr@wineerp.co")
    with Session(engine) as s:
        user = s.exec(select(User).where(User.email == "mgr@wineerp.co")).one()
        user.role = UserRole.manager
        s.add(user)
        s.commit()
    return token


def _h(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def _create(client, token, **kwargs):
    body = {"producer": "Test Maison", "model_name": "Cuvée Test", **kwargs}
    return client.post(f"{API}/wines", json=body, headers=_h(token))


def _inventory(client, token):
    return client.get(f"{API}/inventory", headers=_h(token)).json()


def _scan(client, token, code):
    return client.post(
        f"{API}/scan", json={"code": code}, headers=_h(token)
    ).json()["products"]


def _report_totals(engine):
    from app.crud.report import receiving_report

    with Session(engine) as s:
        return receiving_report(
            s,
            start=datetime.now(UTC) - timedelta(days=1),
            end=datetime.now(UTC) + timedelta(days=1),
        )


# --- 목록·상세 ---------------------------------------------------------------


def test_list_catalog_groups_vintages_under_one_product(client):
    """카탈로그는 제품 단위 카드다(재고 탭은 빈티지 단위 행). 같은 제품의 두 빈티지는
    한 장으로 묶이고 total_stock은 합산된다."""
    token = _token(client)
    created = _create(client, token, vintage=2019, initial_quantity=5).json()
    pid = created["product_id"]
    # 같은 제품에 다른 빈티지를 붙이려면 등록이 새 제품을 만들므로, 여기선 한 제품에
    # 빈티지 하나인 일반 케이스를 검증한다(대부분의 등록이 1제품 1빈티지다).
    resp = client.get(f"{API}/wines", headers=_h(token))
    assert resp.status_code == 200
    items = resp.json()
    mine = [i for i in items if i["product_id"] == pid]
    assert len(mine) == 1
    assert mine[0]["model_name"] == "Cuvée Test"
    assert mine[0]["total_stock"] == 5
    assert len(mine[0]["vintages"]) == 1
    assert mine[0]["vintages"][0]["vintage"] == 2019
    assert mine[0]["vintages"][0]["stock"] == 5


def test_catalog_viewable_by_staff(client):
    """열람은 직원도 가능(재고와 같은 운영 정보). 수정·삭제만 manager 전용이다."""
    token = _token(client)  # staff
    _create(client, token, vintage=2020)
    assert client.get(f"{API}/wines", headers=_h(token)).status_code == 200


def test_detail_returns_vintages_and_stock(client):
    token = _token(client)
    pid = _create(client, token, vintage=2018, initial_quantity=3).json()["product_id"]
    resp = client.get(f"{API}/wines/{pid}", headers=_h(token))
    assert resp.status_code == 200
    body = resp.json()
    assert body["product_id"] == pid
    assert body["total_stock"] == 3
    assert body["vintages"][0]["vintage"] == 2018


def test_catalog_item_carries_registration_date(client):
    """카드 표시 + 등록일 검색을 위해 created_at을 실어 보낸다."""
    token = _token(client)
    _create(client, token, vintage=2019)
    items = client.get(f"{API}/wines", headers=_h(token)).json()
    assert items
    assert items[0]["created_at"]  # ISO 8601 문자열


def test_detail_unknown_returns_404(client):
    token = _token(client)
    assert client.get(f"{API}/wines/{_uuid.uuid4()}", headers=_h(token)).status_code == 404


def test_list_requires_auth(client):
    assert client.get(f"{API}/wines").status_code == 401


# --- 수정(전파) --------------------------------------------------------------


def test_update_requires_manager(client, engine):
    token = _token(client)  # staff
    pid = _create(client, token, vintage=2019).json()["product_id"]
    resp = client.patch(
        f"{API}/wines/{pid}",
        json={"producer": "New", "model_name": "New Name"},
        headers=_h(token),
    )
    assert resp.status_code == 403


def test_update_propagates_to_inventory_and_history(client, engine):
    """모델명을 고치면 재고·내역이 **자동 반영**된다 — 모델명을 복사해 둔 곳이 없다."""
    staff = _token(client)
    mgr = _manager_token(client, engine)
    created = _create(client, staff, vintage=2019, initial_quantity=4).json()
    pid, vid = created["product_id"], created["vintage_id"]

    resp = client.patch(
        f"{API}/wines/{pid}",
        json={"producer": "Renamed Maison", "model_name": "Renamed Cuvée",
              "region": "Bordeaux", "country": "France", "grape": "Merlot"},
        headers=_h(mgr),
    )
    assert resp.status_code == 200
    assert resp.json()["model_name"] == "Renamed Cuvée"

    # 재고에 새 이름이 뜬다.
    inv = client.get(f"{API}/inventory", headers=_h(staff)).json()
    row = next(r for r in inv if r["vintage_id"] == vid)
    assert row["model_name"] == "Renamed Cuvée"
    assert row["producer"] == "Renamed Maison"

    # 내역에도 새 이름이 뜬다(초기 세팅분이 내역에 있다).
    hist = client.get(f"{API}/receiving?period=month", headers=_h(staff)).json()
    assert any(i["model_name"] == "Renamed Cuvée" for i in hist["data"])


# --- 삭제(아카이브) ----------------------------------------------------------


def test_delete_requires_manager(client, engine):
    token = _token(client)  # staff
    pid = _create(client, token, vintage=2019).json()["product_id"]
    assert client.delete(f"{API}/wines/{pid}", headers=_h(token)).status_code == 403


def test_archive_removes_from_catalog_inventory_reports(client, engine):
    """삭제된 모델은 카탈로그·재고·리포트에서 사라진다. 필터를 지우면 이 단언이 깨진다."""
    staff = _token(client)
    mgr = _manager_token(client, engine)
    created = _create(client, staff, vintage=2019, initial_quantity=6).json()
    pid, vid = created["product_id"], created["vintage_id"]

    # 삭제 전: 재고·리포트에 잡힌다.
    assert any(r["vintage_id"] == vid for r in _inventory(client, staff))
    assert _report_totals(engine)["total_quantity"] == 6

    assert client.delete(f"{API}/wines/{pid}", headers=_h(mgr)).status_code == 204

    # 삭제 후: 카탈로그·재고·리포트에서 사라진다.
    catalog = client.get(f"{API}/wines", headers=_h(staff)).json()
    assert all(i["product_id"] != pid for i in catalog)
    assert all(r["vintage_id"] != vid for r in _inventory(client, staff))
    assert _report_totals(engine)["total_quantity"] == 0


def test_archive_preserves_receiving_ledger_but_hides_from_history(client, engine):
    """⚠️ 원장 보존 — 삭제해도 입고기록은 DB에 그대로 남는다(국세기본법 5년 보존).
    동시에 삭제된 모델의 과거 입고는 **내역에서 빠진다**(재고·리포트와 같은 아카이브 필터).

    이것이 '삭제=아카이브'의 핵심 안전장치다. 소스 스캔 가드(session.delete)보다 강하다:
    archive_product가 실수로 입고기록을 지우면 원장 단언(DB row)이 실행으로 잡는다.
    내역 필터를 지우면 아래 `len(data) == 0` 단언이 깨진다(변이 검증).
    삭제 사실은 이제 활동 로그 탭(GET /audit)에서 확인한다.
    """
    staff = _token(client)
    mgr = _manager_token(client, engine)
    created = _create(client, staff, vintage=2019, initial_quantity=8).json()
    pid = created["product_id"]

    client.delete(f"{API}/wines/{pid}", headers=_h(mgr))

    # 입고기록 원장은 그대로다(하드삭제 아님).
    with Session(engine) as s:
        recs = s.exec(select(ReceivingRecord)).all()
        assert len(recs) == 1
        assert recs[0].quantity == 8
        assert recs[0].deleted_at is None  # 취소도 아니다 — 원장은 온전하다

    # 하지만 내역에는 더 이상 뜨지 않는다 — "재고엔 없는데 내역엔 있는" 괴리를 없앤다.
    hist = client.get(f"{API}/receiving?period=month", headers=_h(staff)).json()
    assert len(hist["data"]) == 0


def test_archive_frees_barcode_for_clean_reregistration(client, engine):
    """삭제 후 같은 바코드를 다시 스캔하면 미매칭이고, 같은 모델을 새로 등록해도
    바코드가 새 제품 하나에만 걸린다(옛/새 제품 이중 매칭 충돌 없음)."""
    staff = _token(client)
    mgr = _manager_token(client, engine)
    created = _create(client, staff, vintage=2019, barcode="REREG-0001").json()
    pid = created["product_id"]

    # 삭제 전: 바코드가 매칭된다.
    assert len(_scan(client, staff, "REREG-0001")) == 1

    client.delete(f"{API}/wines/{pid}", headers=_h(mgr))

    # 삭제 후: 바코드가 풀려 미매칭.
    assert _scan(client, staff, "REREG-0001") == []

    # 같은 모델을 새로 등록 → 바코드가 새 제품 하나에만 걸린다(충돌 없음).
    new = _create(client, staff, vintage=2019, barcode="REREG-0001").json()
    assert new["product_id"] != pid
    products = _scan(client, staff, "REREG-0001")
    assert len(products) == 1
    assert products[0]["id"] == new["product_id"]


def test_archived_product_not_editable(client, engine):
    """아카이브된 제품은 상세·수정·재삭제 대상이 아니다(404)."""
    staff = _token(client)
    mgr = _manager_token(client, engine)
    pid = _create(client, staff, vintage=2019).json()["product_id"]
    client.delete(f"{API}/wines/{pid}", headers=_h(mgr))

    assert client.get(f"{API}/wines/{pid}", headers=_h(staff)).status_code == 404
    assert client.patch(
        f"{API}/wines/{pid}", json={"producer": "X", "model_name": "Y"}, headers=_h(mgr)
    ).status_code == 404
    assert client.delete(f"{API}/wines/{pid}", headers=_h(mgr)).status_code == 404
