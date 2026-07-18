"""애플리케이션 설정 — 12-factor env 기반. 시크릿은 값이 아니라 이름만 코드에 존재."""
from __future__ import annotations

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=(".env", "../.env"),  # backend/.env 우선, 루트 .env 폴백
        env_ignore_empty=True,
        extra="ignore",
    )

    # --- 기본 ---
    PROJECT_NAME: str = "wineerp"
    API_V1_PREFIX: str = "/api/v1"
    ENVIRONMENT: str = "local"  # local | staging | production

    # --- 보안 (Story 1.3에서 실사용) ---
    SECRET_KEY: str = "change-me-in-env"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24

    # --- 데이터베이스 ---
    # 미설정 시 None → 앱은 기동되고 health는 200, DB 필요 라우트에서만 검증(Story 1.2+)
    DATABASE_URL: str | None = None

    # --- LLM 제공자 (Story 3.1에서 실사용, 유료 티어 필수) ---
    LLM_PROVIDER: str = "gemini"  # gemini | openai
    GEMINI_API_KEY: str | None = None
    OPENAI_API_KEY: str | None = None

    # --- 오브젝트 스토리지 (Story 2.3에서 실사용, Cloudflare R2) ---
    R2_ACCOUNT_ID: str | None = None
    R2_ACCESS_KEY_ID: str | None = None
    R2_SECRET_ACCESS_KEY: str | None = None
    R2_BUCKET: str | None = None


settings = Settings()
