"""create stored_images (Story 6.1, FR4)

라벨 사진이 재배포를 견디게 한다. 이전에는 R2 자격증명이 없어 컨테이너 로컬 디스크로
폴백했고, Railway가 배포마다 컨테이너를 교체해 사진이 전부 사라졌다 —
DB의 representative_image_key만 남아 깨진 참조가 됐다.

Revision ID: 0008_stored_images
Revises: 0007_amendment_memo
Create Date: 2026-07-19
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
import sqlmodel  # noqa: F401

from alembic import op

revision: str = "0008_stored_images"
down_revision: str | None = "0007_amendment_memo"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "stored_images",
        sa.Column("key", sa.String(length=512), nullable=False),
        sa.Column("content_type", sa.String(), nullable=False),
        sa.Column("data", sa.LargeBinary(), nullable=False),
        sa.Column("size", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("key"),
    )


def downgrade() -> None:
    op.drop_table("stored_images")
