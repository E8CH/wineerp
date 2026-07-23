"""add wine_products.archived_at (모델 삭제 = 아카이브)

모델 "삭제"를 아카이브로 구현한다(Story 7.x). 제품을 지우면 카탈로그·재고·리포트·
스캔에서 사라지지만, 딸린 입고기록(원장, 국세기본법 §85조의3 5년 보존)은 하드삭제하지
않고 남긴다. 내역 화면은 아카이브 제품의 과거 기록을 계속 보여준다. archived_at IS NULL
필터를 여러 읽기 경로에서 쓰므로 인덱스를 둔다.

Revision ID: 0009_wine_archived
Revises: 0008_stored_images
Create Date: 2026-07-23
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

revision: str = "0009_wine_archived"
down_revision: str | None = "0008_stored_images"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "wine_products",
        sa.Column("archived_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index(
        "ix_wine_products_archived_at", "wine_products", ["archived_at"]
    )


def downgrade() -> None:
    op.drop_index("ix_wine_products_archived_at", table_name="wine_products")
    op.drop_column("wine_products", "archived_at")
