"""2계층 와인 식별 모델 (리서치 2026-07-17 근거).

WineProduct("같은 와인" 상위) 1:N WineVintage(가격결정·재고 단위, vintage nullable=NV).
Barcode N:M WineProduct — 바코드는 producer+wine+size까지만 특정, 빈티지 미인코딩.
lwin7/lwin11을 내부 표준키로 보관(카탈로그 벤더 교체 시 안정 매핑).
"""
from __future__ import annotations

import uuid
from datetime import UTC, datetime

from sqlalchemy import Column, DateTime
from sqlmodel import Field, SQLModel


def _utcnow() -> datetime:
    return datetime.now(UTC)


def _tz_column() -> Column:
    """`_utcnow()`가 aware datetime을 주므로 컬럼도 timestamptz여야 한다.

    SQLModel 기본 `datetime`은 TIMESTAMP WITHOUT TIME ZONE으로 생성되어 마이그레이션
    (0001·0002, timezone=True)과 어긋난다. 어긋난 채 두면 `alembic revision --autogenerate`가
    매번 허위 타입 변경 diff를 낸다.
    """
    return Column(DateTime(timezone=True), nullable=False)


class WineProduct(SQLModel, table=True):
    __tablename__ = "wine_products"

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    producer: str = Field(nullable=False)
    model_name: str = Field(index=True, nullable=False)
    region: str | None = None
    country: str | None = None
    grape: str | None = None
    lwin7: str | None = Field(default=None, index=True)  # 내부 표준키(와인)
    created_at: datetime = Field(default_factory=_utcnow, sa_column=_tz_column())


class WineVintage(SQLModel, table=True):
    __tablename__ = "wine_vintages"

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    wine_product_id: uuid.UUID = Field(foreign_key="wine_products.id", index=True, nullable=False)
    vintage: int | None = None  # nullable — NV(Non-Vintage)는 1급 유효 상태
    lwin11: str | None = None  # 내부 표준키(+빈티지)
    representative_image_key: str | None = None  # R2 오브젝트 key (Story 2.3)
    created_at: datetime = Field(default_factory=_utcnow, sa_column=_tz_column())


class Barcode(SQLModel, table=True):
    __tablename__ = "barcodes"

    id: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    code: str = Field(unique=True, index=True, nullable=False)
    created_at: datetime = Field(default_factory=_utcnow, sa_column=_tz_column())


class BarcodeWineProductLink(SQLModel, table=True):
    __tablename__ = "barcode_wine_product_link"

    # N:M — 바코드↔와인 양방향 다중(수입사별 코드 난립 등)
    barcode_id: uuid.UUID = Field(
        foreign_key="barcodes.id", primary_key=True, nullable=False
    )
    wine_product_id: uuid.UUID = Field(
        foreign_key="wine_products.id", primary_key=True, nullable=False
    )
