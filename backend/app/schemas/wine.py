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
