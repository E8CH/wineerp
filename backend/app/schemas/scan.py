"""스캔/매칭 입출력 스키마 (FR5)."""
from __future__ import annotations

import uuid

from pydantic import BaseModel, ConfigDict


class ScanRequest(BaseModel):
    code: str


class WineVintageRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    vintage: int | None
    lwin11: str | None
    representative_image_key: str | None
    stock: int = 0  # 현재고 (Story 2.6) — 입고 합계, soft-delete 제외


class WineProductRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    producer: str
    model_name: str
    region: str | None
    country: str | None
    grape: str | None
    lwin7: str | None
    vintages: list[WineVintageRead] = []


class ScanResult(BaseModel):
    code: str
    products: list[WineProductRead]
