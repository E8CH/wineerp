"""create audit_logs (활동 로그 — 누가 넣고·고치고·지웠는지)

모든 데이터 변경(입고 생성·수정·취소, 모델 등록·수정·삭제)을 한 테이블에 시간순으로
남긴다. actor_email·summary는 시점 스냅샷(비정규화)이라 사용자 개명·모델 아카이브 뒤에도
과거 로그가 흔들리지 않는다. detail은 상세 화면용 구조화 JSON. entity_id는 조회·필터용이며
대상 테이블이 여러 개라 FK는 걸지 않는다. created_at으로 최신순 정렬하므로 인덱스를 둔다.

Revision ID: 0010_audit_logs
Revises: 0009_wine_archived
Create Date: 2026-07-24
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
import sqlmodel  # noqa: F401

from alembic import op

revision: str = "0010_audit_logs"
down_revision: str | None = "0009_wine_archived"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "audit_logs",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("action", sa.String(), nullable=False),
        # 행위자는 삭제될 수 있으므로 nullable. 표시는 actor_email(스냅샷)으로 한다.
        sa.Column("actor_id", sa.Uuid(), nullable=True),
        sa.Column("actor_email", sa.String(), nullable=False),
        sa.Column("summary", sa.String(), nullable=False),
        sa.Column("entity_type", sa.String(), nullable=False),
        sa.Column("entity_id", sa.Uuid(), nullable=True),
        sa.Column("detail", sa.JSON(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["actor_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_audit_logs_action", "audit_logs", ["action"])
    op.create_index("ix_audit_logs_actor_id", "audit_logs", ["actor_id"])
    op.create_index("ix_audit_logs_entity_id", "audit_logs", ["entity_id"])
    op.create_index("ix_audit_logs_created_at", "audit_logs", ["created_at"])


def downgrade() -> None:
    op.drop_index("ix_audit_logs_created_at", table_name="audit_logs")
    op.drop_index("ix_audit_logs_entity_id", table_name="audit_logs")
    op.drop_index("ix_audit_logs_actor_id", table_name="audit_logs")
    op.drop_index("ix_audit_logs_action", table_name="audit_logs")
    op.drop_table("audit_logs")
