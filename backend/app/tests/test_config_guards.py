"""부팅 시점 설정 가드.

⚠️ 기본 `SECRET_KEY`로 프로덕션이 뜨면 저장소를 본 누구나 유효한 JWT를 서명할 수 있다.
인증이 있는 척하는 상태가 인증이 없는 것보다 나쁘다 — 아무도 눈치채지 못하기 때문이다.
"""
from __future__ import annotations

import pytest

from app.core.config import DEFAULT_SECRET_KEY, Settings


def _settings(**kw) -> Settings:
    return Settings(_env_file=None, **kw)


def test_production_refuses_default_secret_key():
    s = _settings(ENVIRONMENT="production", SECRET_KEY=DEFAULT_SECRET_KEY)
    with pytest.raises(RuntimeError, match="SECRET_KEY"):
        s.assert_production_ready()


def test_production_accepts_a_real_secret_key():
    _settings(ENVIRONMENT="production", SECRET_KEY="a-real-random-value").assert_production_ready()


def test_local_may_keep_the_default():
    """개발 편의는 유지한다 — 막아야 하는 것은 프로덕션 부팅뿐이다."""
    _settings(ENVIRONMENT="local", SECRET_KEY=DEFAULT_SECRET_KEY).assert_production_ready()
