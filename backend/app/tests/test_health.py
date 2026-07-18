"""AC2 스모크 — health가 DB 없이 200을 반환하고 /api/v1 프리픽스로 노출되는지."""
from fastapi.testclient import TestClient

from app.core.config import settings
from app.main import app

client = TestClient(app)


def test_health_returns_200_without_db():
    resp = client.get(f"{settings.API_V1_PREFIX}/health")
    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "ok"
    assert body["project"] == "wineerp"


def test_openapi_schema_exposed():
    resp = client.get(f"{settings.API_V1_PREFIX}/openapi.json")
    assert resp.status_code == 200
    assert resp.json()["info"]["title"] == "wineerp"


def test_root_ok():
    resp = client.get("/")
    assert resp.status_code == 200
    assert resp.json()["service"] == "wineerp"
