"""리포트 집계 (FR10).

⚠️ 버킷팅을 SQL이 아니라 여기서 하는 이유: KST 기준 일별 묶음을 SQL로 하면
SQLite(`strftime`)와 PostgreSQL(`date_trunc … AT TIME ZONE`)이 갈리고, 4.1에서 겪은
시간대 함정을 방언마다 다시 밟는다. 월 최대 ~3,000행이라 애플리케이션 집계 비용은
무의미하다. 경계 계산은 `core.timeframe.period_bounds`를 그대로 재사용한다.
"""
from __future__ import annotations

import uuid
from collections import defaultdict
from datetime import UTC, datetime, timedelta
from zoneinfo import ZoneInfo

from sqlmodel import Session, select

from app.core.config import settings
from app.models.receiving import ReceivingRecord
from app.models.wine import WineProduct, WineVintage

TOP_PRODUCT_LIMIT = 5


def receiving_report(
    session: Session, *, start: datetime, end: datetime
) -> dict:
    """기간 내 입고 집계. 초기 세팅분도 포함한다.

    구분은 `source`로 하되 리포트에서 빼지는 않는다 — 재고에 반영되는 수량이
    리포트에 없으면 "재고 100, 리포트 40"이 되어 관리자가 무엇을 믿을지 모른다.
    """
    tz = ZoneInfo(settings.TIMEZONE)
    rows = session.exec(
        select(ReceivingRecord, WineVintage, WineProduct)
        .join(WineVintage, ReceivingRecord.wine_vintage_id == WineVintage.id)
        .join(WineProduct, WineVintage.wine_product_id == WineProduct.id)
        .where(ReceivingRecord.deleted_at.is_(None))  # soft-delete 제외(AR6)
        # 아카이브(삭제)된 제품은 리포트에서도 제외한다. 재고에서 사라진 모델이 리포트엔
        # 남으면 "재고 40 · 리포트 100"이 되어 관리자가 무엇을 믿을지 모른다(재고=리포트 원칙).
        # 과거 기록 자체는 내역(원장)에 그대로 남는다.
        .where(WineProduct.archived_at.is_(None))
        .where(ReceivingRecord.received_at >= start)
        .where(ReceivingRecord.received_at < end)
    ).all()

    per_day: dict[str, int] = defaultdict(int)
    # ⚠️ 이름 문자열이 아니라 제품 id로 묶는다. 3.2가 LLM이 읽은 라벨 텍스트로 마스터를
    # 만들기 때문에 model_name+producer가 같은 **서로 다른 제품**이 실제로 생길 수 있고,
    # 문자열로 묶으면 재고는 두 줄인데 리포트는 한 줄이 되어 단위가 어긋난다.
    per_product: dict[uuid.UUID, int] = defaultdict(int)
    product_names: dict[uuid.UUID, tuple[str, str]] = {}
    vintages: set = set()
    products: set = set()
    total = 0

    for rec, vintage, product in rows:
        received = rec.received_at
        if received.tzinfo is None:  # SQLite는 오프셋을 저장하지 않는다
            received = received.replace(tzinfo=UTC)
        local_date = received.astimezone(tz).date().isoformat()
        per_day[local_date] += rec.quantity
        per_product[product.id] += rec.quantity
        product_names[product.id] = (product.model_name, product.producer)
        vintages.add(vintage.id)
        products.add(product.id)
        total += rec.quantity

    # ⚠️ 입고가 없던 날도 0으로 채운다. 빼면 막대가 붙어 그려지고 보는 사람은
    # "매일 들어왔다"고 읽는다 — 그래프가 하는 가장 흔한 거짓말이다.
    buckets = []
    cursor = start.astimezone(tz).date()
    last = (end.astimezone(tz) - timedelta(seconds=1)).date()
    while cursor <= last:
        key = cursor.isoformat()
        buckets.append({"date": key, "quantity": per_day.get(key, 0)})
        cursor += timedelta(days=1)

    # 동점은 이름·생산자·id 순으로 완전히 결정한다. id까지 넣지 않으면 동명이생산자
    # 제품에서 DB 행 순서(ORDER BY 없음)에 기대게 되고 방언마다 5위가 달라진다.
    top = sorted(
        per_product.items(),
        key=lambda kv: (-kv[1], product_names[kv[0]][0], product_names[kv[0]][1], str(kv[0])),
    )
    return {
        "buckets": buckets,
        "top_products": [
            {
                "model_name": product_names[pid][0],
                "producer": product_names[pid][1],
                "quantity": qty,
            }
            for pid, qty in top[:TOP_PRODUCT_LIMIT]
        ],
        "total_quantity": total,
        "record_count": len(rows),
        # 두 단위를 모두 내려보낸다. 화면이 "품목 N종"이라고만 쓰면 상위 품목 목록
        # (제품 단위)과 숫자가 안 맞아 보인다 — 재고 단위는 빈티지, 목록 단위는 제품이다.
        "distinct_wines": len(vintages),
        "distinct_products": len(products),
    }
