"""애플리케이션 설정 — 12-factor env 기반. 시크릿은 값이 아니라 이름만 코드에 존재."""
from __future__ import annotations

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


def normalize_db_url(url: str | None) -> str | None:
    """Railway/일반 제공자의 `postgres://`·`postgresql://` → psycopg3 드라이버용 스킴으로 정규화."""
    if not url:
        return url
    if url.startswith("postgresql+"):
        return url  # 이미 드라이버 지정됨
    if url.startswith("postgresql://"):
        return "postgresql+psycopg://" + url[len("postgresql://") :]
    if url.startswith("postgres://"):
        return "postgresql+psycopg://" + url[len("postgres://") :]
    return url


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

    @field_validator("DATABASE_URL")
    @classmethod
    def _normalize_database_url(cls, v: str | None) -> str | None:
        return normalize_db_url(v)

    # --- LLM 제공자 (Story 3.1에서 실사용, 유료 티어 필수) ---
    LLM_PROVIDER: str = "gemini"  # gemini | openai
    GEMINI_API_KEY: str | None = None
    OPENAI_API_KEY: str | None = None

    # --- 오브젝트 스토리지 (Cloudflare R2; 미설정 시 로컬 파일 어댑터로 폴백) ---
    R2_ACCOUNT_ID: str | None = None
    R2_ACCESS_KEY_ID: str | None = None
    R2_SECRET_ACCESS_KEY: str | None = None
    R2_BUCKET: str | None = None
    IMAGE_STORAGE_DIR: str = "_local_storage"  # 로컬 어댑터 저장 경로

    @property
    def r2_configured(self) -> bool:
        return bool(
            self.R2_ACCOUNT_ID
            and self.R2_ACCESS_KEY_ID
            and self.R2_SECRET_ACCESS_KEY
            and self.R2_BUCKET
        )


settings = Settings()
