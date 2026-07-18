"""Alembic 환경 — DATABASE_URL은 앱 설정에서 주입. target_metadata는 SQLModel 메타데이터.

모델 스키마는 필요 시점 스토리에서 추가되며(1.2 user, 2.1 wine_*, 2.6 receiving),
그때 이 파일 상단에서 해당 모델 모듈을 import 하면 autogenerate가 인식한다.
"""
from __future__ import annotations

from logging.config import fileConfig

from sqlalchemy import engine_from_config, pool
from sqlmodel import SQLModel

from alembic import context
from app.core.config import settings

# 모델 등록 지점 (스토리별로 import 추가):
# from app.models import user  # noqa: F401  (Story 1.2)

config = context.config
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

if not settings.DATABASE_URL:
    raise RuntimeError("DATABASE_URL 미설정 — 마이그레이션에는 DB 연결이 필요합니다.")
config.set_main_option("sqlalchemy.url", settings.DATABASE_URL)

target_metadata = SQLModel.metadata


def run_migrations_offline() -> None:
    context.configure(
        url=settings.DATABASE_URL,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    with connectable.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
