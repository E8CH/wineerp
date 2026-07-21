"""재고 목록 조회 (Story 6.2, FR — UX-DR3 재고 탭).

빈티지(재고 단위) 단위로 현재고를 돌려준다. 리포트와 달리 **역할 가드 없음** —
직원도 입고 중 재고를 봐야 한다(리포트는 매출·집계라 manager 전용이지만, 재고 열람은
운영 정보다).
"""
from __future__ import annotations

from fastapi import APIRouter

from app.api.deps import CurrentUser, SessionDep
from app.crud import receiving as receiving_crud
from app.crud import wine as wine_crud
from app.schemas.wine import InventoryItem

router = APIRouter(prefix="/inventory", tags=["inventory"])


@router.get("", response_model=list[InventoryItem])
def list_inventory(session: SessionDep, _: CurrentUser) -> list[InventoryItem]:
    rows = wine_crud.list_inventory_rows(session)
    # 현재고는 빈티지 전체를 한 번에 합산한다(행마다 조회하면 N+1, NFR1 위반).
    # get_stock_map은 기록 없는 빈티지도 0으로 채워 주므로 재고 0 와인도 목록에 남는다
    # (등록됐으나 아직 안 받은 마스터 — 숨기면 "왜 안 보이지"가 된다).
    stock = receiving_crud.get_stock_map(session, [v.id for _p, v in rows])
    return [
        InventoryItem(
            wine_product_id=p.id,
            producer=p.producer,
            model_name=p.model_name,
            region=p.region,
            country=p.country,
            grape=p.grape,
            vintage_id=v.id,
            vintage=v.vintage,
            representative_image_key=v.representative_image_key,
            stock=stock.get(v.id, 0),
        )
        for p, v in rows
    ]
