"""create wine master tables (2-tier + barcode N:M)

Revision ID: 0002_wine
Revises: 0001_users
Create Date: 2026-07-18
"""
from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
import sqlmodel  # noqa: F401

from alembic import op

revision: str = "0002_wine"
down_revision: str | None = "0001_users"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "wine_products",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("producer", sa.String(), nullable=False),
        sa.Column("model_name", sa.String(), nullable=False),
        sa.Column("region", sa.String(), nullable=True),
        sa.Column("country", sa.String(), nullable=True),
        sa.Column("grape", sa.String(), nullable=True),
        sa.Column("lwin7", sa.String(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_wine_products_model_name", "wine_products", ["model_name"])
    op.create_index("ix_wine_products_lwin7", "wine_products", ["lwin7"])

    op.create_table(
        "wine_vintages",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("wine_product_id", sa.Uuid(), nullable=False),
        sa.Column("vintage", sa.Integer(), nullable=True),  # NV=NULL 허용
        sa.Column("lwin11", sa.String(), nullable=True),
        sa.Column("representative_image_key", sa.String(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["wine_product_id"], ["wine_products.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_wine_vintages_wine_product_id", "wine_vintages", ["wine_product_id"])

    op.create_table(
        "barcodes",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("code", sa.String(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_barcodes_code", "barcodes", ["code"], unique=True)

    op.create_table(
        "barcode_wine_product_link",
        sa.Column("barcode_id", sa.Uuid(), nullable=False),
        sa.Column("wine_product_id", sa.Uuid(), nullable=False),
        sa.ForeignKeyConstraint(["barcode_id"], ["barcodes.id"]),
        sa.ForeignKeyConstraint(["wine_product_id"], ["wine_products.id"]),
        sa.PrimaryKeyConstraint("barcode_id", "wine_product_id"),
    )


def downgrade() -> None:
    op.drop_table("barcode_wine_product_link")
    op.drop_index("ix_barcodes_code", table_name="barcodes")
    op.drop_table("barcodes")
    op.drop_index("ix_wine_vintages_wine_product_id", table_name="wine_vintages")
    op.drop_table("wine_vintages")
    op.drop_index("ix_wine_products_lwin7", table_name="wine_products")
    op.drop_index("ix_wine_products_model_name", table_name="wine_products")
    op.drop_table("wine_products")
