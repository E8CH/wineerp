"""활동 로그(감사) — 누가 데이터를 넣고·고치고·지웠는지.

기록은 변경 라우트가 남긴다. 여기서는 (1) manager 전용 경계, (2) 각 이벤트 종류가
실제로 남는지, (3) 무변경 수정은 로그하지 않는지(잡음 방지 가드의 변이 검증),
(4) 행위자 이메일이 스냅샷으로 남는지를 못 박는다.
"""
from __future__ import annotations

from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.pool import StaticPool
from sqlmodel import Session, SQLModel, create_engine, select

from app.core.db import get_session
from app.main import app
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


def _manager_token(client: TestClient, engine, email="mgr@wineerp.co") -> str:
    token = _token(client, email)
    with Session(engine) as s:
        user = s.exec(select(User).where(User.email == email)).one()
        user.role = UserRole.manager
        s.add(user)
        s.commit()
    return token


def _h(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def _create_wine(client, token, **kwargs):
    body = {"producer": "Test Maison", "model_name": "Cuvée Test", **kwargs}
    return client.post(f"{API}/wines", json=body, headers=_h(token))


def _audit(client, mgr) -> list[dict]:
    resp = client.get(f"{API}/audit", headers=_h(mgr))
    assert resp.status_code == 200
    return resp.json()["data"]


def _actions(events: list[dict]) -> list[str]:
    return [e["action"] for e in events]


# --- 권한 -------------------------------------------------------------------


def test_audit_requires_manager(client, engine):
    staff = _token(client)
    assert client.get(f"{API}/audit", headers=_h(staff)).status_code == 403


def test_audit_requires_auth(client):
    assert client.get(f"{API}/audit").status_code == 401


# --- 이벤트 기록 ------------------------------------------------------------


def test_wine_create_is_logged(client, engine):
    staff = _token(client)
    mgr = _manager_token(client, engine)
    _create_wine(client, staff, vintage=2019)

    events = _audit(client, mgr)
    assert "wine.create" in _actions(events)
    created = next(e for e in events if e["action"] == "wine.create")
    assert "Cuvée Test" in created["summary"]
    # 행위자는 실제로 등록한 직원이다(토큰 기준), manager 조회자가 아니다.
    assert created["actor_email"] == "staff@wineerp.co"


def test_initial_setup_is_logged_separately(client, engine):
    """등록과 초기재고 설정은 다른 사실이라 별도 이벤트로 남는다."""
    staff = _token(client)
    mgr = _manager_token(client, engine)
    _create_wine(client, staff, vintage=2019, initial_quantity=6)

    actions = _actions(_audit(client, mgr))
    assert "wine.create" in actions
    assert "wine.initial_setup" in actions


def test_no_initial_setup_event_without_quantity(client, engine):
    """초기재고를 안 넣으면 initial_setup 이벤트도 없다 — 가짜 재고 이벤트 방지."""
    staff = _token(client)
    mgr = _manager_token(client, engine)
    _create_wine(client, staff, vintage=2019)  # initial_quantity 없음

    assert "wine.initial_setup" not in _actions(_audit(client, mgr))


def test_receiving_create_is_logged(client, engine):
    staff = _token(client)
    mgr = _manager_token(client, engine)
    vid = _create_wine(client, staff, vintage=2019).json()["vintage_id"]

    client.post(
        f"{API}/receiving",
        json={"wine_vintage_id": vid, "quantity": 12},
        headers=_h(staff),
    )

    events = _audit(client, mgr)
    created = next(e for e in events if e["action"] == "receiving.create")
    assert "12병" in created["summary"]
    assert created["detail"]["quantity"] == 12


def test_idempotent_replay_is_not_logged_twice(client, engine):
    """멱등 재생은 '생성'이 아니다 — 재시도해도 로그는 한 줄이어야 한다."""
    staff = _token(client)
    mgr = _manager_token(client, engine)
    vid = _create_wine(client, staff, vintage=2019).json()["vintage_id"]
    body = {
        "wine_vintage_id": vid,
        "quantity": 5,
        "idempotency_key": "11111111-1111-1111-1111-111111111111",
    }
    client.post(f"{API}/receiving", json=body, headers=_h(staff))
    client.post(f"{API}/receiving", json=body, headers=_h(staff))  # 재시도

    creates = [e for e in _audit(client, mgr) if e["action"] == "receiving.create"]
    assert len(creates) == 1


def test_receiving_amend_is_logged(client, engine):
    staff = _token(client)
    mgr = _manager_token(client, engine)
    vid = _create_wine(client, staff, vintage=2019).json()["vintage_id"]
    rec = client.post(
        f"{API}/receiving",
        json={"wine_vintage_id": vid, "quantity": 10},
        headers=_h(staff),
    ).json()

    client.patch(
        f"{API}/receiving/{rec['id']}",
        json={"quantity": 15},
        headers=_h(staff),
    )

    amend = next(e for e in _audit(client, mgr) if e["action"] == "receiving.amend")
    assert amend["detail"]["before_quantity"] == 10
    assert amend["detail"]["after_quantity"] == 15


def test_noop_amend_is_not_logged(client, engine):
    """⚠️ 변이 검증 — 값이 안 바뀐 수정은 로그하지 않는다. `if changed:` 가드를 지우면
    이 단언이 깨진다(무변경 잡음이 진짜 수정을 묻는 것을 막는 가드)."""
    staff = _token(client)
    mgr = _manager_token(client, engine)
    vid = _create_wine(client, staff, vintage=2019).json()["vintage_id"]
    rec = client.post(
        f"{API}/receiving",
        json={"wine_vintage_id": vid, "quantity": 10},
        headers=_h(staff),
    ).json()

    # 같은 수량으로 PATCH — 아무것도 바뀌지 않는다.
    client.patch(
        f"{API}/receiving/{rec['id']}",
        json={"quantity": 10},
        headers=_h(staff),
    )

    assert "receiving.amend" not in _actions(_audit(client, mgr))


def test_receiving_cancel_is_logged(client, engine):
    staff = _token(client)
    mgr = _manager_token(client, engine)
    vid = _create_wine(client, staff, vintage=2019).json()["vintage_id"]
    rec = client.post(
        f"{API}/receiving",
        json={"wine_vintage_id": vid, "quantity": 7},
        headers=_h(staff),
    ).json()

    client.delete(f"{API}/receiving/{rec['id']}", headers=_h(mgr))

    cancel = next(e for e in _audit(client, mgr) if e["action"] == "receiving.cancel")
    assert cancel["actor_email"] == "mgr@wineerp.co"  # 취소는 manager가 했다
    assert cancel["detail"]["quantity"] == 7


def test_wine_update_is_logged_with_before_after(client, engine):
    staff = _token(client)
    mgr = _manager_token(client, engine)
    pid = _create_wine(client, staff, vintage=2019).json()["product_id"]

    client.patch(
        f"{API}/wines/{pid}",
        json={"producer": "New Maison", "model_name": "Renamed"},
        headers=_h(mgr),
    )

    update = next(e for e in _audit(client, mgr) if e["action"] == "wine.update")
    assert update["detail"]["before"]["model_name"] == "Cuvée Test"
    assert update["detail"]["after"]["model_name"] == "Renamed"


def test_wine_archive_is_logged(client, engine):
    staff = _token(client)
    mgr = _manager_token(client, engine)
    pid = _create_wine(client, staff, vintage=2019).json()["product_id"]

    client.delete(f"{API}/wines/{pid}", headers=_h(mgr))

    archive = next(e for e in _audit(client, mgr) if e["action"] == "wine.archive")
    # 삭제 시점의 표기가 스냅샷으로 남는다(아카이브 뒤에도 "그때 무엇이었나").
    assert archive["detail"]["model_name"] == "Cuvée Test"


# --- 정렬·스냅샷 ------------------------------------------------------------


def test_events_are_newest_first(client, engine):
    """연속 리스트라 최신순이어야 한다 — 위에 방금 한 일이 온다."""
    staff = _token(client)
    mgr = _manager_token(client, engine)
    pid = _create_wine(client, staff, vintage=2019).json()["product_id"]  # wine.create
    client.delete(f"{API}/wines/{pid}", headers=_h(mgr))  # wine.archive (나중)

    events = _audit(client, mgr)
    # 가장 최근 것이 배열 맨 앞: archive가 create보다 앞에 온다.
    idx_archive = _actions(events).index("wine.archive")
    idx_create = _actions(events).index("wine.create")
    assert idx_archive < idx_create
