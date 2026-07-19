"""record memo changes in receiving_amendments (코드리뷰 이월)

수량만 기록하면 메모 정정이 감사에서 사라진다. 메모는 명세서 불일치·파손 같은
이의 사유가 적히는 유일한 칸이고, 그 변경이야말로 감사가 보고 싶어 하는 것이다.

Revision ID: 0007_amendment_memo
Revises: 0006_receiving_amendments
Create Date: 2026-07-19
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
import sqlmodel  # noqa: F401

from alembic import op

revision: str = "0007_amendment_memo"
down_revision: str | None = "0006_receiving_amendments"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "receiving_amendments", sa.Column("before_memo", sa.String(), nullable=True)
    )
    op.add_column(
        "receiving_amendments", sa.Column("after_memo", sa.String(), nullable=True)
    )


def downgrade() -> None:
    op.drop_column("receiving_amendments", "after_memo")
    op.drop_column("receiving_amendments", "before_memo")
