"""Story 4.2 — 입고 수량 수정·취소 (FR8, AR6)."""
from __future__ import annotations

import uuid as _uuid
from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.pool import StaticPool
from sqlmodel import Session, SQLModel, create_engine

from app.core.db import get_session
from app.crud import receiving as receiving_crud
from app.main import app
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


def _token(client: TestClient, email="staff@wineerp.co") -> str:
    client.post(f"{API}/auth/signup", json={"email": email, "password": "pw123456"})
    return client.post(
        f"{API}/auth/login", data={"username": email, "password": "pw123456"}
    ).json()["access_token"]


def _manager_token(client: TestClient, engine) -> str:
    token = _token(client, "mgr@wineerp.co")
    with Session(engine) as s:
        user = s.exec(
            __import__("sqlmodel").select(User).where(User.email == "mgr@wineerp.co")
        ).one()
        user.role = UserRole.manager
        s.add(user)
        s.commit()
    return token


def _h(token):
    return {"Authorization": f"Bearer {token}"}


def _make_record(client, token) -> dict:
    vid = client.post(
        f"{API}/scan", json={"code": "3760000000015"}, headers=_h(token)
    ).json()["products"][0]["vintages"][0]["id"]
    return client.post(
        f"{API}/receiving",
        json={"wine_vintage_id": vid, "quantity": 12},
        headers=_h(token),
    ).json()


def _stock(engine, vintage_id: str) -> int:
    with Session(engine) as s:
        vid = _uuid.UUID(vintage_id)
        return receiving_crud.get_stock_map(s, [vid])[vid]


# --- 수정 ---------------------------------------------------------------------


def test_update_quantity_returns_200_and_reflects_stock(client, engine):
    token = _token(client)
    rec = _make_record(client, token)
    assert _stock(engine, rec["wine_vintage_id"]) == 12

    resp = client.patch(
        f"{API}/receiving/{rec['id']}", json={"quantity": 9}, headers=_h(token)
    )
    assert resp.status_code == 200
    assert resp.json()["quantity"] == 9
    assert _stock(engine, rec["wine_vintage_id"]) == 9


def test_amendment_row_records_before_and_after(client, engine):
    """🔴 최종 수량만 덮어쓰면 무엇이 얼마에서 얼마로 바뀌었는지 사라진다."""
    token = _token(client)
    rec = _make_record(client, token)
    client.patch(
        f"{API}/receiving/{rec['id']}",
        json={"quantity": 9, "reason": "오입력"},
        headers=_h(token),
    )

    with Session(engine) as s:
        history = receiving_crud.list_amendments(s, _uuid.UUID(rec["id"]))
    assert len(history) == 1
    assert (history[0].before_quantity, history[0].after_quantity) == (12, 9)
    assert history[0].reason == "오입력"
    assert history[0].changed_by is not None


def test_repeated_edits_accumulate_history(client, engine):
    token = _token(client)
    rec = _make_record(client, token)
    for q in (10, 8, 7):
        client.patch(f"{API}/receiving/{rec['id']}", json={"quantity": q}, headers=_h(token))

    with Session(engine) as s:
        history = receiving_crud.list_amendments(s, _uuid.UUID(rec["id"]))
    assert [(h.before_quantity, h.after_quantity) for h in history] == [
        (12, 10),
        (10, 8),
        (8, 7),
    ]


def test_same_quantity_leaves_no_amendment(client, engine):
    """변경이 없으면 이력에 잡음을 남기지 않는다."""
    token = _token(client)
    rec = _make_record(client, token)
    resp = client.patch(
        f"{API}/receiving/{rec['id']}", json={"quantity": 12}, headers=_h(token)
    )
    assert resp.status_code == 200
    with Session(engine) as s:
        assert receiving_crud.list_amendments(s, _uuid.UUID(rec["id"])) == []


def test_update_validates_range(client):
    token = _token(client)
    rec = _make_record(client, token)
    assert client.patch(
        f"{API}/receiving/{rec['id']}", json={"quantity": 0}, headers=_h(token)
    ).status_code == 422
    assert client.patch(
        f"{API}/receiving/{rec['id']}", json={"quantity": 1000}, headers=_h(token)
    ).status_code == 422


def test_update_unknown_record_404(client):
    token = _token(client)
    resp = client.patch(
        f"{API}/receiving/{_uuid.uuid4()}", json={"quantity": 3}, headers=_h(token)
    )
    assert resp.status_code == 404


def test_update_requires_auth(client):
    resp = client.patch(f"{API}/receiving/{_uuid.uuid4()}", json={"quantity": 3})
    assert resp.status_code == 401


# --- 취소(manager 전용) --------------------------------------------------------


def test_cancel_requires_manager(client, engine):
    """🔴 취소는 5년 보존 원장에서 재고를 빼는 일이고 복구 UI가 없다."""
    staff = _token(client)
    rec = _make_record(client, staff)
    assert client.delete(f"{API}/receiving/{rec['id']}", headers=_h(staff)).status_code == 403
    assert _stock(engine, rec["wine_vintage_id"]) == 12, "403인데 재고가 줄면 안 된다"


def test_manager_can_cancel_and_stock_excludes_it(client, engine):
    staff = _token(client)
    rec = _make_record(client, staff)
    mgr = _manager_token(client, engine)

    resp = client.delete(f"{API}/receiving/{rec['id']}", headers=_h(mgr))
    assert resp.status_code == 200
    assert _stock(engine, rec["wine_vintage_id"]) == 0


def test_cancel_is_soft_delete_not_hard(client, engine):
    """행은 남아야 한다(AR6, 5년 보존)."""
    from app.models.receiving import ReceivingRecord

    staff = _token(client)
    rec = _make_record(client, staff)
    mgr = _manager_token(client, engine)
    client.delete(f"{API}/receiving/{rec['id']}", headers=_h(mgr))

    with Session(engine) as s:
        row = s.get(ReceivingRecord, _uuid.UUID(rec["id"]))
    assert row is not None, "하드삭제되면 원장이 사라진다"
    assert row.deleted_at is not None


def test_cancelled_record_cannot_be_edited(client, engine):
    staff = _token(client)
    rec = _make_record(client, staff)
    mgr = _manager_token(client, engine)
    client.delete(f"{API}/receiving/{rec['id']}", headers=_h(mgr))

    resp = client.patch(
        f"{API}/receiving/{rec['id']}", json={"quantity": 3}, headers=_h(staff)
    )
    assert resp.status_code == 404


def test_cancelled_record_drops_out_of_history(client, engine):
    staff = _token(client)
    rec = _make_record(client, staff)
    mgr = _manager_token(client, engine)
    client.delete(f"{API}/receiving/{rec['id']}", headers=_h(mgr))

    body = client.get(f"{API}/receiving", params={"period": "month"}, headers=_h(staff)).json()
    assert all(item["id"] != rec["id"] for item in body["data"])


def test_no_hard_delete_path_exists_anywhere():
    """AR6 — 하드삭제 경로가 코드베이스 어디에도 없어야 한다.

    ⚠️ 이전 버전은 `dir(receiving_crud)`에서 "hard"라는 **이름**만 찾는 린트였다.
    `purge_record()`라는 이름으로 `session.delete()`를 추가하면 그대로 통과했다
    (코드리뷰에서 실증됨). 이름이 아니라 **호출**을 찾는다.

    예외: 원장이 아닌 행(예: 바코드↔제품 링크)의 삭제는 정당하다. 그런 줄에는 반드시
    `hard-delete-ok` 마커를 달아 **의도를 명시**한다 — 마커는 리뷰어가 보라고 남기는
    것이고, 이 테스트는 마커 없는 삭제만 잡는다. 원장(입고기록) 자체의 보존은 실행 테스트
    `test_archive_preserves_receiving_ledger`가 별도로 못 박는다(소스 스캔보다 강하다).
    """
    import pathlib

    app_dir = pathlib.Path(__file__).resolve().parents[1]
    offenders = []
    for path in app_dir.rglob("*.py"):
        if "tests" in path.parts:
            continue
        for lineno, line in enumerate(
            path.read_text(encoding="utf-8").splitlines(), start=1
        ):
            if "hard-delete-ok" in line:
                continue  # 명시적으로 허용된 비-원장 삭제(바코드 링크 등)
            if "session.delete(" in line or ".delete(synchronize_session" in line:
                offenders.append(f"{path.relative_to(app_dir)}:{lineno}: {line.strip()}")

    assert not offenders, (
        "하드삭제 호출이 있습니다. 입고 기록은 5년 보존 대상이며 soft-delete만 "
        "허용됩니다(AR6). 원장이 아닌 정당한 삭제면 'hard-delete-ok' 마커를 다세요: "
        + " | ".join(offenders)
    )


# --- Story 4.3: 메모 ----------------------------------------------------------


def test_memo_is_stored_on_create_and_shown_in_history(client):
    token = _token(client)
    vid = client.post(
        f"{API}/scan", json={"code": "3760000000015"}, headers=_h(token)
    ).json()["products"][0]["vintages"][0]["id"]
    client.post(
        f"{API}/receiving",
        json={"wine_vintage_id": vid, "quantity": 2, "memo": "코르크 손상"},
        headers=_h(token),
    )
    body = client.get(f"{API}/receiving", params={"period": "month"}, headers=_h(token)).json()
    assert body["data"][0]["memo"] == "코르크 손상"


def test_blank_memo_is_stored_as_null(client, engine):
    """`""`와 null이 공존하면 '메모 있음' 판정이 호출부마다 갈린다."""
    from app.models.receiving import ReceivingRecord

    token = _token(client)
    vid = client.post(
        f"{API}/scan", json={"code": "3760000000015"}, headers=_h(token)
    ).json()["products"][0]["vintages"][0]["id"]
    created = client.post(
        f"{API}/receiving",
        json={"wine_vintage_id": vid, "quantity": 1, "memo": "   "},
        headers=_h(token),
    ).json()

    with Session(engine) as s:
        assert s.get(ReceivingRecord, _uuid.UUID(created["id"])).memo is None


def test_memo_only_edit_is_saved_and_recorded(client, engine):
    """메모만 바꾸는 것도 유효한 수정이고 이력에 남아야 한다."""
    from app.models.receiving import ReceivingRecord

    token = _token(client)
    rec = _make_record(client, token)
    resp = client.patch(
        f"{API}/receiving/{rec['id']}",
        json={"quantity": 12, "memo": "명세서 불일치"},  # 수량은 그대로
        headers=_h(token),
    )
    assert resp.status_code == 200

    with Session(engine) as s:
        assert s.get(ReceivingRecord, _uuid.UUID(rec["id"])).memo == "명세서 불일치"
        history = receiving_crud.list_amendments(s, _uuid.UUID(rec["id"]))
    assert len(history) == 1, "메모 변경도 5년 보존 원장의 변경이다"
    assert history[0].before_quantity == history[0].after_quantity == 12


def test_blank_memo_on_update_clears_it(client, engine):
    from app.models.receiving import ReceivingRecord

    token = _token(client)
    rec = _make_record(client, token)
    client.patch(
        f"{API}/receiving/{rec['id']}", json={"quantity": 12, "memo": "임시"}, headers=_h(token)
    )
    client.patch(
        f"{API}/receiving/{rec['id']}", json={"quantity": 12, "memo": ""}, headers=_h(token)
    )
    with Session(engine) as s:
        assert s.get(ReceivingRecord, _uuid.UUID(rec["id"])).memo is None


def test_omitting_memo_keeps_existing(client, engine):
    """미지정과 삭제는 다르다 — 수량만 고칠 때 메모가 날아가면 안 된다."""
    from app.models.receiving import ReceivingRecord

    token = _token(client)
    rec = _make_record(client, token)
    client.patch(
        f"{API}/receiving/{rec['id']}",
        json={"quantity": 12, "memo": "유지되어야"},
        headers=_h(token),
    )
    client.patch(f"{API}/receiving/{rec['id']}", json={"quantity": 5}, headers=_h(token))

    with Session(engine) as s:
        row = s.get(ReceivingRecord, _uuid.UUID(rec["id"]))
    assert row.quantity == 5
    assert row.memo == "유지되어야"


def test_nothing_changed_writes_no_amendment(client, engine):
    token = _token(client)
    rec = _make_record(client, token)
    client.patch(
        f"{API}/receiving/{rec['id']}", json={"quantity": 12}, headers=_h(token)
    )
    with Session(engine) as s:
        assert receiving_crud.list_amendments(s, _uuid.UUID(rec["id"])) == []


def test_memo_length_limit(client):
    token = _token(client)
    rec = _make_record(client, token)
    resp = client.patch(
        f"{API}/receiving/{rec['id']}",
        json={"quantity": 12, "memo": "가" * 501},
        headers=_h(token),
    )
    assert resp.status_code == 422


# --- 교차 수정 귀속 (코드리뷰 이월: IDOR 오귀속) --------------------------------


def test_another_staff_can_amend_and_history_shows_who(client, engine):
    """staff끼리 수정은 **의도된 설계**(Story 4.2)지만, 화면이 그 사실을 숨기면 안 된다.

    🔴 이전에는 내역이 `staff_email`(최초 입고자)만 보여줘서, bob이 고친 수량이
    alice의 이름으로 표시됐다. 감사 행은 남지만 어떤 화면에도 노출되지 않아
    사실상 복구 불가능한 오귀속이었다.
    """
    alice = _token(client, "alice@wineerp.co")
    rec = _make_record(client, alice)  # alice가 12병 입고

    bob = _token(client, "bob@wineerp.co")
    resp = client.patch(
        f"{API}/receiving/{rec['id']}",
        json={"quantity": 3, "reason": "재확인"},
        headers=_h(bob),
    )
    assert resp.status_code == 200, "교차 수정은 허용된 설계다"

    item = client.get(
        f"{API}/receiving", params={"period": "month"}, headers=_h(alice)
    ).json()["data"][0]

    assert item["staff_email"] == "alice@wineerp.co", "입고자는 여전히 alice"
    assert item["quantity"] == 3
    assert item["amended_by"] == "bob@wineerp.co", "고친 사람이 드러나야 한다"


def test_unamended_record_has_no_amender(client, engine):
    alice = _token(client, "alice@wineerp.co")
    _make_record(client, alice)
    item = client.get(
        f"{API}/receiving", params={"period": "month"}, headers=_h(alice)
    ).json()["data"][0]
    assert item["amended_by"] is None


def test_history_shows_the_latest_amender_not_the_first(client, engine):
    alice = _token(client, "alice@wineerp.co")
    rec = _make_record(client, alice)
    bob = _token(client, "bob@wineerp.co")
    carol = _token(client, "carol@wineerp.co")

    client.patch(f"{API}/receiving/{rec['id']}", json={"quantity": 9}, headers=_h(bob))
    client.patch(f"{API}/receiving/{rec['id']}", json={"quantity": 4}, headers=_h(carol))

    item = client.get(
        f"{API}/receiving", params={"period": "month"}, headers=_h(alice)
    ).json()["data"][0]
    assert item["amended_by"] == "carol@wineerp.co"


def test_memo_change_is_recorded_in_the_amendment(client, engine):
    """🔴 수량만 기록하면 "명세서 불일치" -> "정상" 정정이 감사에서 사라진다.

    메모는 이의 사유가 적히는 유일한 칸이라, 그 변경이야말로 감사가 보고 싶어 한다.
    """
    token = _token(client)
    rec = _make_record(client, token)
    client.patch(
        f"{API}/receiving/{rec['id']}",
        json={"quantity": 12, "memo": "명세서 불일치"},
        headers=_h(token),
    )
    client.patch(
        f"{API}/receiving/{rec['id']}",
        json={"quantity": 12, "memo": "확인 완료"},
        headers=_h(token),
    )

    with Session(engine) as s:
        history = receiving_crud.list_amendments(s, _uuid.UUID(rec["id"]))
    assert [(h.before_memo, h.after_memo) for h in history] == [
        (None, "명세서 불일치"),
        ("명세서 불일치", "확인 완료"),
    ]


def test_quantity_edit_also_snapshots_the_memo(client, engine):
    """수량만 고쳐도 그 시점의 메모가 남아야 이력만으로 상태를 재구성할 수 있다."""
    token = _token(client)
    rec = _make_record(client, token)
    client.patch(
        f"{API}/receiving/{rec['id']}",
        json={"quantity": 12, "memo": "파손 2병"},
        headers=_h(token),
    )
    client.patch(f"{API}/receiving/{rec['id']}", json={"quantity": 10}, headers=_h(token))

    with Session(engine) as s:
        last = receiving_crud.list_amendments(s, _uuid.UUID(rec["id"]))[-1]
    assert (last.before_quantity, last.after_quantity) == (12, 10)
    assert last.before_memo == last.after_memo == "파손 2병"


def test_amend_locks_the_row(client, engine):
    """동시 수정에서 두 이력이 같은 before를 주장하면 재고가 조용히 틀린다.

    ⚠️ SQLite는 `FOR UPDATE`를 무시하므로 이 테스트는 **쿼리가 잠금을 요청하는지**만
    확인한다. 실제 직렬화는 PostgreSQL에서만 일어난다 — 여기서 검증할 수 없는 것을
    검증한 척하지 않는다.
    """
    from sqlalchemy.dialects import postgresql
    from sqlmodel import select as _select

    from app.models.receiving import ReceivingRecord

    stmt = _select(ReceivingRecord).where(ReceivingRecord.id == _uuid.uuid4())
    locked = str(stmt.with_for_update().compile(dialect=postgresql.dialect()))
    assert "FOR UPDATE" in locked

    import inspect

    src = inspect.getsource(receiving_crud.get_record)
    assert "with_for_update()" in src, "get_record가 잠금 경로를 제공해야 한다"

    from app.api.routes import receiving as route

    assert "for_update=True" in inspect.getsource(route.update_receiving)
    assert "for_update=True" in inspect.getsource(route.cancel_receiving)


def test_staff_can_gut_a_record_without_manager_approval(client, engine):
    """⚠️ 알려진 설계 공백 — 고치지 않고 **문서화**한다.

    취소(DELETE)는 manager 전용인데, staff가 수량을 1로 낮추면 같은 결과에 가깝다.
    200병짜리를 1로 만들면 재고의 99.5%가 403 없이 사라진다.

    고치지 않은 이유: 어떤 임계값도 임의적이다. "절반 이상 감소는 manager"라고 정하면
    12→5 같은 일상 정정이 막히고, 4.2가 "수정은 누구나"로 정한 근거(정정은 흔하고
    되돌릴 수 있다)와 충돌한다. **제품 판단이 필요한 지점**이므로 임의 규칙을
    발명하는 대신 현재 동작을 고정해 둔다 — 나중에 정책이 정해지면 이 테스트가
    바뀌어야 할 곳을 가리킨다.

    완화책은 이미 있다: 모든 수정이 `receiving_amendments`에 before/after로 남고,
    내역 화면이 `amended_by`로 누가 고쳤는지 보여준다.
    """
    staff = _token(client)
    vid = client.post(
        f"{API}/scan", json={"code": "3760000000015"}, headers=_h(staff)
    ).json()["products"][0]["vintages"][0]["id"]
    rec = client.post(
        f"{API}/receiving",
        json={"wine_vintage_id": vid, "quantity": 200},
        headers=_h(staff),
    ).json()

    assert client.delete(f"{API}/receiving/{rec['id']}", headers=_h(staff)).status_code == 403

    resp = client.patch(
        f"{API}/receiving/{rec['id']}", json={"quantity": 1}, headers=_h(staff)
    )
    assert resp.status_code == 200, "현재는 허용된다 — 정책이 정해지면 여기가 바뀐다"
    assert _stock(engine, rec["wine_vintage_id"]) == 1

    with Session(engine) as s:
        history = receiving_crud.list_amendments(s, _uuid.UUID(rec["id"]))
    assert (history[0].before_quantity, history[0].after_quantity) == (200, 1), (
        "최소한 흔적은 남는다 — 이것이 현재의 유일한 완화책이다"
    )
