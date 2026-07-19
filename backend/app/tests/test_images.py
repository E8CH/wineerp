"""Story 2.3 — 이미지 업로드·EXIF 제거·StoragePort(로컬) (FR4)."""
from __future__ import annotations

import io
from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient
from PIL import Image
from sqlalchemy.pool import StaticPool
from sqlmodel import Session, SQLModel, create_engine

from app.core.db import get_session
from app.main import app

API = "/api/v1"


def _jpeg_with_exif() -> bytes:
    img = Image.new("RGB", (12, 12), "red")
    exif = img.getexif()
    exif[0x0110] = "SecretCameraModel"  # Model 태그(제거 대상)
    buf = io.BytesIO()
    img.save(buf, "JPEG", exif=exif.tobytes())
    return buf.getvalue()


@pytest.fixture
def engine_and_session(tmp_path) -> Iterator[Session]:
    engine = create_engine(
        "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool
    )
    SQLModel.metadata.create_all(engine)
    with Session(engine) as s:
        yield s


@pytest.fixture
def ctx(tmp_path) -> Iterator[tuple[TestClient, object]]:
    """⚠️ 스토리지를 override하지 않는다.

    운영 기본값은 DB 어댑터이고, 예전처럼 로컬 어댑터를 끼워 넣으면 **테스트가
    운영에서 쓰지 않는 경로만 검증**하게 된다. 사진이 재배포마다 사라지던 문제가
    그 사각지대에서 나왔다.
    """
    engine = create_engine(
        "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool
    )
    SQLModel.metadata.create_all(engine)

    def _session() -> Iterator[Session]:
        with Session(engine) as s:
            yield s

    app.dependency_overrides[get_session] = _session
    with TestClient(app) as c:
        yield c, tmp_path
    app.dependency_overrides.clear()


def _token(client: TestClient) -> str:
    client.post(f"{API}/auth/signup", json={"email": "s@wineerp.co", "password": "pw123456"})
    return client.post(
        f"{API}/auth/login", data={"username": "s@wineerp.co", "password": "pw123456"}
    ).json()["access_token"]


def test_upload_stores_and_strips_exif(ctx):
    client, tmp_path = ctx
    token = _token(client)
    resp = client.post(
        f"{API}/images",
        files={"file": ("label.jpg", _jpeg_with_exif(), "image/jpeg")},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 201
    body = resp.json()
    assert body["key"].startswith("labels/")

    # ⚠️ 저장 위치를 단언하지 않는다. 어댑터(R2/DB/local)는 교체 가능해야 하고,
    # 검증할 것은 "다시 꺼냈을 때 EXIF가 없다"이다.
    fetched = client.get(
        f"{API}/images/{body['key']}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert fetched.status_code == 200
    with Image.open(io.BytesIO(fetched.content)) as img:
        exif = img.getexif()
        assert 0x0110 not in exif  # Model 태그 사라짐


def test_upload_requires_auth(ctx):
    client, _ = ctx
    resp = client.post(
        f"{API}/images",
        files={"file": ("label.jpg", _jpeg_with_exif(), "image/jpeg")},
    )
    assert resp.status_code == 401


def test_upload_rejects_non_image(ctx):
    client, _ = ctx
    token = _token(client)
    resp = client.post(
        f"{API}/images",
        files={"file": ("x.jpg", b"not-an-image", "image/jpeg")},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 400


# --- Story 6.1: 조회 -----------------------------------------------------------


def _upload(client, token) -> str:
    return client.post(
        f"{API}/images",
        files={"file": ("label.jpg", _jpeg_with_exif(), "image/jpeg")},
        headers={"Authorization": f"Bearer {token}"},
    ).json()["key"]


def test_uploaded_image_can_be_fetched_back(ctx):
    """찍은 사진을 다시 볼 수 없으면 FR4가 요구하는 표시가 불가능하다."""
    client, _ = ctx
    token = _token(client)
    key = _upload(client, token)

    resp = client.get(f"{API}/images/{key}", headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 200
    assert resp.headers["content-type"].startswith("image/")
    assert len(resp.content) > 0


def test_fetch_requires_auth(ctx):
    """🔴 인증이 없으면 key를 아는 누구나 고객사 재고 사진을 본다."""
    client, _ = ctx
    key = _upload(client, _token(client))
    assert client.get(f"{API}/images/{key}").status_code == 401


def test_unknown_key_404(ctx):
    client, _ = ctx
    token = _token(client)
    resp = client.get(
        f"{API}/images/labels/nope.jpg", headers={"Authorization": f"Bearer {token}"}
    )
    assert resp.status_code == 404


def test_validate_image_key_rejects_traversal():
    """경로 이탈 가드를 **단위로** 검증한다.

    ⚠️ HTTP 요청으로는 이 가드에 닿지 않는다 — ASGI/클라이언트가 `..`를 라우팅 전에
    정규화해 404가 나고, `400 또는 404`를 허용하는 테스트는 가드를 지워도 통과한다
    (실제로 변이 검증에서 통과했다). 그래서 함수를 직접 부른다.
    """
    from fastapi import HTTPException

    from app.api.routes.images import validate_image_key

    for bad in ["labels/../../etc/passwd", "/etc/passwd", "..", "~/.ssh/id_rsa"]:
        with pytest.raises(HTTPException) as exc:
            validate_image_key(bad)
        assert exc.value.status_code == 400, bad

    validate_image_key("labels/abc123.jpg")  # 정상 key는 통과


def test_response_carries_cache_headers(ctx):
    """같은 병을 반복 스캔한다 — 캐시가 없으면 매번 수백 KB를 받는다."""
    client, _ = ctx
    token = _token(client)
    key = _upload(client, token)
    resp = client.get(f"{API}/images/{key}", headers={"Authorization": f"Bearer {token}"})
    assert "max-age" in resp.headers.get("cache-control", "")
    assert resp.headers.get("etag")


def test_db_adapter_survives_and_overwrites(engine_and_session):
    """재업로드는 덮어쓴다(라벨 다시 찍기). 그리고 파일시스템에 의존하지 않는다."""
    from app.adapters.storage_db import DbStorageAdapter

    session = engine_and_session
    a = DbStorageAdapter(session)
    a.put_object(b"first", "labels/x.jpg", "image/jpeg")
    a.put_object(b"second", "labels/x.jpg", "image/png")

    assert a.get_object("labels/x.jpg") == b"second"
    assert a.get_content_type("labels/x.jpg") == "image/png"
