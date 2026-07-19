"""create receiving_amendments (Story 4.2, FR8)

수정 이력을 행으로 남긴다. 최종 수량만 덮어쓰면 무엇이 언제 왜 바뀌었는지 사라지고
5년 보존 원장(AR6)의 의미가 없어진다.

Revision ID: 0006_receiving_amendments
Revises: 0005_receiving_source
Create Date: 2026-07-19
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
import sqlmodel  # noqa: F401

from alembic import op

revision: str = "0006_receiving_amendments"
down_revision: str | None = "0005_receiving_source"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "receiving_amendments",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("receiving_record_id", sa.Uuid(), nullable=False),
        sa.Column("before_quantity", sa.Integer(), nullable=False),
        sa.Column("after_quantity", sa.Integer(), nullable=False),
        sa.Column("changed_by", sa.Uuid(), nullable=False),
        sa.Column("changed_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("reason", sa.String(), nullable=True),
        sa.ForeignKeyConstraint(["receiving_record_id"], ["receiving_records.id"]),
        sa.ForeignKeyConstraint(["changed_by"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_receiving_amendments_receiving_record_id",
        "receiving_amendments",
        ["receiving_record_id"],
    )
    op.create_index(
        "ix_receiving_amendments_changed_by", "receiving_amendments", ["changed_by"]
    )
    op.create_index(
        "ix_receiving_amendments_changed_at", "receiving_amendments", ["changed_at"]
    )


def downgrade() -> None:
    op.drop_index("ix_receiving_amendments_changed_at", table_name="receiving_amendments")
    op.drop_index("ix_receiving_amendments_changed_by", table_name="receiving_amendments")
    op.drop_index(
        "ix_receiving_amendments_receiving_record_id",
        table_name="receiving_amendments",
    )
    op.drop_table("receiving_amendments")
