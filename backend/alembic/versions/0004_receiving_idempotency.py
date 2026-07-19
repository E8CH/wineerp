"""add idempotency_key to receiving_records (Story 2.7)

재시도 중복 방지. 네트워크 실패는 정의상 클라이언트가 결과를 모르는 상태이므로,
결과를 아는 서버만이 중복을 판정할 수 있다.

Revision ID: 0004_receiving_idempotency
Revises: 0003_receiving
Create Date: 2026-07-19
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
import sqlmodel  # noqa: F401

from alembic import op

revision: str = "0004_receiving_idempotency"
down_revision: str | None = "0003_receiving"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "receiving_records",
        sa.Column("idempotency_key", sa.Uuid(), nullable=True),
    )
    op.create_index(
        "ix_receiving_records_idempotency_key",
        "receiving_records",
        ["idempotency_key"],
        unique=True,
    )


def downgrade() -> None:
    op.drop_index(
        "ix_receiving_records_idempotency_key", table_name="receiving_records"
    )
    op.drop_column("receiving_records", "idempotency_key")
