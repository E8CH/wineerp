"""Story 2.3 — 이미지 업로드·EXIF 제거·StoragePort(로컬) (FR4)."""
from __future__ import annotations

import io
from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient
from PIL import Image
from sqlalchemy.pool import StaticPool
from sqlmodel import Session, SQLModel, create_engine

from app.adapters.storage_local import LocalStorageAdapter
from app.api.deps import get_storage
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
def ctx(tmp_path) -> Iterator[tuple[TestClient, object]]:
    engine = create_engine(
        "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool
    )
    SQLModel.metadata.create_all(engine)
    storage = LocalStorageAdapter(tmp_path)

    def _session() -> Iterator[Session]:
        with Session(engine) as s:
            yield s

    app.dependency_overrides[get_session] = _session
    app.dependency_overrides[get_storage] = lambda: storage
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
    assert body["url"].startswith("local:///labels/")

    # 저장 파일 존재 + EXIF 제거 확인
    stored = tmp_path / body["key"]
    assert stored.exists()
    with Image.open(stored) as img:
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
