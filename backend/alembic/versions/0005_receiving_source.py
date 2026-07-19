"""add source to receiving_records (Story 3.3, FR13)

초기 세팅의 재고 기준선을 입고 이벤트와 데이터로 구분한다. 별도 테이블로 나누지 않는
이유는 재고를 세는 곳을 하나로 유지하기 위함이다(crud.receiving.get_stock_map).

Revision ID: 0005_receiving_source
Revises: 0004_receiving_idempotency
Create Date: 2026-07-19
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
import sqlmodel  # noqa: F401

from alembic import op

revision: str = "0005_receiving_source"
down_revision: str | None = "0004_receiving_idempotency"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # server_default로 기존 행을 전부 'receiving'으로 채운 뒤 NOT NULL을 건다.
    op.add_column(
        "receiving_records",
        sa.Column(
            "source",
            sa.String(),
            nullable=False,
            server_default="receiving",
        ),
    )
    op.create_index(
        "ix_receiving_records_source", "receiving_records", ["source"]
    )


def downgrade() -> None:
    op.drop_index("ix_receiving_records_source", table_name="receiving_records")
    op.drop_column("receiving_records", "source")
