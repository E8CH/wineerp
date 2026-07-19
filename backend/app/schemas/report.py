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
    # 재고 단위(빈티지) 수. `top_products`는 제품 단위이므로 두 숫자는 다를 수 있다.
    distinct_wines: int
    distinct_products: int = 0
