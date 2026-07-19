"""create receiving_records (FR7, soft-delete only per AR6)

Revision ID: 0003_receiving
Revises: 0002_wine
Create Date: 2026-07-19
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
import sqlmodel  # noqa: F401

from alembic import op

revision: str = "0003_receiving"
down_revision: str | None = "0002_wine"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "receiving_records",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("wine_vintage_id", sa.Uuid(), nullable=False),
        sa.Column("quantity", sa.Integer(), nullable=False),
        sa.Column("received_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("staff_id", sa.Uuid(), nullable=False),
        sa.Column("memo", sa.String(), nullable=True),
        # soft-delete 전용 컬럼. 하드삭제 금지(AR6, 5년 보존).
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["wine_vintage_id"], ["wine_vintages.id"]),
        sa.ForeignKeyConstraint(["staff_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_receiving_records_wine_vintage_id",
        "receiving_records",
        ["wine_vintage_id"],
    )
    op.create_index(
        "ix_receiving_records_staff_id", "receiving_records", ["staff_id"]
    )
    op.create_index(
        "ix_receiving_records_received_at", "receiving_records", ["received_at"]
    )
    # 재고 집계가 항상 deleted_at을 필터하므로 인덱스에 포함.
    op.create_index(
        "ix_receiving_records_deleted_at", "receiving_records", ["deleted_at"]
    )


def downgrade() -> None:
    op.drop_index("ix_receiving_records_deleted_at", table_name="receiving_records")
    op.drop_index("ix_receiving_records_received_at", table_name="receiving_records")
    op.drop_index("ix_receiving_records_staff_id", table_name="receiving_records")
    op.drop_index(
        "ix_receiving_records_wine_vintage_id", table_name="receiving_records"
    )
    op.drop_table("receiving_records")
