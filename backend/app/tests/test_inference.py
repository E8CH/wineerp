"""Story 3.1 — LabelInferencePort & 벤더 어댑터 (AR4·AR9)."""
from __future__ import annotations

from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.pool import StaticPool
from sqlmodel import Session, SQLModel, create_engine

from app.adapters import label_inference
from app.adapters.label_inference import (
    GeminiAdapter,
    OpenAIAdapter,
    PaidTierNotConfirmedError,
    get_label_inference,
)
from app.adapters.label_inference_fake import FakeInferenceAdapter
from app.adapters.storage_local import LocalStorageAdapter
from app.api.deps import get_label_inference as deps_get_inference
from app.core.db import get_session
from app.main import app
from app.services.ports import InferenceResult

API = "/api/v1"


@pytest.fixture
def client(tmp_path) -> Iterator[TestClient]:
    engine = create_engine(
        "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool
    )
    SQLModel.metadata.create_all(engine)

    def _session() -> Iterator[Session]:
        with Session(engine) as s:
            yield s

    from app.api.deps import get_storage

    storage = LocalStorageAdapter(tmp_path)
    storage.put_object(b"fake-jpeg-bytes", "labels/a.jpg", "image/jpeg")

    app.dependency_overrides[get_session] = _session
    app.dependency_overrides[get_storage] = lambda: storage
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()


def _token(client: TestClient) -> str:
    client.post(f"{API}/auth/signup", json={"email": "i@wineerp.co", "password": "pw123456"})
    return client.post(
        f"{API}/auth/login", data={"username": "i@wineerp.co", "password": "pw123456"}
    ).json()["access_token"]


def _infer(client, token, key="labels/a.jpg"):
    return client.post(
        f"{API}/inference/label",
        json={"image_key": key},
        headers={"Authorization": f"Bearer {token}"},
    )


# --- 유료 티어 fail-closed 가드 (AR9) -------------------------------------


def test_real_adapters_refuse_without_paid_tier_confirmation(monkeypatch):
    """🔴 키만 넣으면 동작하는 상태를 만들지 않는다.

    무료 티어에서는 사람이 입출력을 읽는다 — 고객사 라벨 사진을 보낼 수 없다.
    키로는 티어를 알 수 없으므로 운영자의 명시적 단언이 유일한 방어선이다.
    """
    monkeypatch.setattr(label_inference.settings, "LLM_PAID_TIER_CONFIRMED", False)
    with pytest.raises(PaidTierNotConfirmedError):
        GeminiAdapter("some-key")
    with pytest.raises(PaidTierNotConfirmedError):
        OpenAIAdapter("some-key")


def test_real_adapters_construct_once_confirmed(monkeypatch):
    monkeypatch.setattr(label_inference.settings, "LLM_PAID_TIER_CONFIRMED", True)
    assert GeminiAdapter("some-key") is not None
    assert OpenAIAdapter("some-key") is not None


def test_factory_defaults_to_fake(monkeypatch):
    """설정이 비어 있을 때 실벤더로 새면 안 된다."""
    monkeypatch.setattr(label_inference.settings, "LLM_PROVIDER", "")
    assert isinstance(get_label_inference(), FakeInferenceAdapter)


def test_factory_selects_provider(monkeypatch):
    monkeypatch.setattr(label_inference.settings, "LLM_PAID_TIER_CONFIRMED", True)
    monkeypatch.setattr(label_inference.settings, "LLM_PROVIDER", "gemini")
    monkeypatch.setattr(label_inference.settings, "GEMINI_API_KEY", "k")
    assert isinstance(get_label_inference(), GeminiAdapter)

    monkeypatch.setattr(label_inference.settings, "LLM_PROVIDER", "openai")
    monkeypatch.setattr(label_inference.settings, "OPENAI_API_KEY", "k")
    assert isinstance(get_label_inference(), OpenAIAdapter)


def test_factory_requires_key_for_selected_provider(monkeypatch):
    monkeypatch.setattr(label_inference.settings, "LLM_PAID_TIER_CONFIRMED", True)
    monkeypatch.setattr(label_inference.settings, "LLM_PROVIDER", "gemini")
    monkeypatch.setattr(label_inference.settings, "GEMINI_API_KEY", None)
    with pytest.raises(RuntimeError):
        get_label_inference()


# --- 타임아웃·실패가 도메인 값으로 반환되는가 ------------------------------


def test_timeout_becomes_failed_result_not_exception(monkeypatch):
    """타임아웃이 예외로 새면 라우트가 500을 내고 수동 폴백(FR6)이 끊긴다."""
    import httpx

    monkeypatch.setattr(label_inference.settings, "LLM_PAID_TIER_CONFIRMED", True)

    def _timeout(*args, **kwargs):
        raise httpx.ReadTimeout("too slow")

    monkeypatch.setattr(httpx, "post", _timeout)
    result = GeminiAdapter("k").infer(b"img", "image/jpeg")
    assert isinstance(result, InferenceResult)
    assert result.failed is True
    assert result.needs_manual_input is True


def test_call_uses_configured_timeout(monkeypatch):
    """타임아웃 인자가 실제로 전달되는지 — 없으면 현장 흐름이 무한정 멈춘다."""
    import httpx

    monkeypatch.setattr(label_inference.settings, "LLM_PAID_TIER_CONFIRMED", True)
    monkeypatch.setattr(label_inference.settings, "LLM_TIMEOUT_SECONDS", 3)
    seen = {}

    class _Resp:
        def raise_for_status(self):
            pass

        def json(self):
            text = '{"model_name":"X","confidence":0.9}'
            return {"candidates": [{"content": {"parts": [{"text": text}]}}]}

    def _post(url, **kwargs):
        seen.update(kwargs)
        return _Resp()

    monkeypatch.setattr(httpx, "post", _post)
    result = GeminiAdapter("k").infer(b"img", "image/jpeg")
    assert seen["timeout"] == 3
    assert result.model_name == "X"


def test_malformed_response_becomes_failed_result(monkeypatch):
    import httpx

    monkeypatch.setattr(label_inference.settings, "LLM_PAID_TIER_CONFIRMED", True)

    class _Resp:
        def raise_for_status(self):
            pass

        def json(self):
            return {"candidates": [{"content": {"parts": [{"text": "설명만 있고 JSON 없음"}]}}]}

    monkeypatch.setattr(httpx, "post", lambda url, **kw: _Resp())
    result = GeminiAdapter("k").infer(b"img", "image/jpeg")
    assert result.failed is True
    assert result.reason == "gemini-no-json"


# --- 도메인 값 의미 ---------------------------------------------------------


def test_low_confidence_flags_manual_review():
    low = InferenceResult(model_name="Ch. X", confidence=0.3)
    assert low.is_low_confidence is True
    assert low.needs_manual_input is False  # 이름은 있으니 채우되 경고를 띄운다

    empty = InferenceResult(model_name=None, confidence=0.9)
    assert empty.needs_manual_input is True  # 이름이 없으면 신뢰도와 무관하게 수동


# --- 라우트 -----------------------------------------------------------------


def test_label_endpoint_returns_domain_result(client):
    token = _token(client)
    resp = _infer(client, token)
    assert resp.status_code == 200
    body = resp.json()
    assert body["model_name"] == "Fake Estate Cuvée"
    assert body["low_confidence"] is True  # fake는 기본적으로 저신뢰


def test_label_endpoint_failure_is_200_not_500(client):
    """추론 실패는 HTTP 오류가 아니다 — UI가 수동 입력으로 분기해야 한다."""
    app.dependency_overrides[deps_get_inference] = lambda: FakeInferenceAdapter(
        failed=True
    )
    token = _token(client)
    resp = _infer(client, token)
    assert resp.status_code == 200
    assert resp.json()["needs_manual_input"] is True


def test_missing_image_returns_404(client):
    token = _token(client)
    assert _infer(client, token, key="labels/none.jpg").status_code == 404


def test_label_endpoint_requires_auth(client):
    assert client.post(f"{API}/inference/label", json={"image_key": "x"}).status_code == 401


def test_adapter_receives_only_image_bytes(client):
    """AR9 — 페이로드에 PII가 들어갈 경로를 타입으로 없앤다.

    포트 시그니처가 (bytes, str)뿐이므로 어댑터는 거래처·매입가에 닿을 수 없다.
    """
    seen = {}

    class _Spy:
        def infer(self, image: bytes, content_type: str) -> InferenceResult:
            seen["image"] = image
            seen["content_type"] = content_type
            return InferenceResult(model_name="X", confidence=0.9)

    app.dependency_overrides[deps_get_inference] = lambda: _Spy()
    token = _token(client)
    assert _infer(client, token).status_code == 200
    assert seen["image"] == b"fake-jpeg-bytes"
    assert set(seen) == {"image", "content_type"}
