"""신규 와인 등록 스키마 (FR6)."""
from __future__ import annotations

import uuid

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.receiving import MAX_QUANTITY


class WineCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    producer: str = Field(min_length=1, max_length=200)
    model_name: str = Field(min_length=1, max_length=200)
    # ⚠️ nullable — NV(Non-Vintage)는 인식 실패가 아니라 1급 유효 상태다(AR2).
    # 샴페인 85~95%·셰리 ~98%가 NV다.
    vintage: int | None = Field(default=None, ge=1800, le=2200)
    region: str | None = Field(default=None, max_length=200)
    country: str | None = Field(default=None, max_length=100)
    grape: str | None = Field(default=None, max_length=200)
    # 스캔에서 넘어온 코드가 있으면 연결한다(N:M, AR3). 없어도 등록은 성립한다 —
    # 바코드 없는 와인이 절반가량이라는 것이 이 제품의 전제다.
    barcode: str | None = Field(default=None, max_length=128)
    representative_image_key: str | None = Field(default=None, max_length=512)
    # 초기 세팅(FR13)에서 보유 수량을 함께 넣을 때만 채운다. 선택 사항이며,
    # 있으면 마스터 생성과 같은 요청에서 기준 재고가 기록된다 — 두 번 호출하게 하면
    # 사이에서 실패했을 때 수량 없는 마스터가 남고 작업자는 알 수 없다.
    initial_quantity: int | None = Field(default=None, ge=1, le=MAX_QUANTITY)


class WineCreated(BaseModel):
    product_id: uuid.UUID
    vintage_id: uuid.UUID
    # 기준 재고를 함께 만들었으면 그 레코드 id. 아니면 None.
    receiving_record_id: uuid.UUID | None = None


class InventoryItem(BaseModel):
    """재고 목록 1행 = 한 빈티지(재고 단위) (Story 6.2)."""

    wine_product_id: uuid.UUID
    producer: str
    model_name: str
    region: str | None = None
    country: str | None = None
    grape: str | None = None
    vintage_id: uuid.UUID
    # None = NV. "빈티지 없음"이 아니라 유효 상태 — 화면에서 오류로 표기하지 말 것.
    vintage: int | None = None
    representative_image_key: str | None = None
    # 현재고 = 입고 합계(서버 집계). 화면에서 재계산 금지.
    stock: int


class VintageStock(BaseModel):
    """카탈로그 상세에서 한 제품 아래의 빈티지 1건 (Story 7.x)."""

    vintage_id: uuid.UUID
    vintage: int | None = None  # None = NV
    stock: int
    representative_image_key: str | None = None


class ProductCatalogItem(BaseModel):
    """모델(제품) 카탈로그 1장 = 한 WineProduct + 그 빈티지들 (Story 7.x).

    카탈로그는 제품 단위 카드다(재고 탭은 빈티지 단위 행). 대표 사진은 빈티지 중 사진이
    있는 첫 항목에서 취한다. total_stock은 빈티지 재고의 합.
    """

    product_id: uuid.UUID
    producer: str
    model_name: str
    region: str | None = None
    country: str | None = None
    grape: str | None = None
    representative_image_key: str | None = None
    total_stock: int
    vintages: list[VintageStock]


class WineUpdate(BaseModel):
    """모델(제품) 메타 수정 (Story 7.x). 입고내역·재고는 제품을 조인으로 읽어 자동 전파된다.

    빈티지·바코드·수량은 여기서 다루지 않는다 — 그건 입고/등록 경로의 책임이다.
    """

    model_config = ConfigDict(extra="forbid")

    producer: str = Field(min_length=1, max_length=200)
    model_name: str = Field(min_length=1, max_length=200)
    region: str | None = Field(default=None, max_length=200)
    country: str | None = Field(default=None, max_length=100)
    grape: str | None = Field(default=None, max_length=200)
