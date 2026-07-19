"""리포트 스키마 (FR10)."""
from __future__ import annotations

from pydantic import BaseModel


class DayBucket(BaseModel):
    date: str  # KST 로컬 날짜 YYYY-MM-DD
    quantity: int


class TopProduct(BaseModel):
    model_name: str
    producer: str
    quantity: int


class ReceivingReport(BaseModel):
    buckets: list[DayBucket]
    top_products: list[TopProduct]
    total_quantity: int
    record_count: int
    distinct_wines: int
