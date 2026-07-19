"""입고 내역 조회 (FR9, UX-DR12)."""
from __future__ import annotations

from datetime import date

from fastapi import APIRouter

from app.api.deps import CurrentUser, SessionDep
from app.core.timeframe import Period, period_bounds
from app.crud import receiving as receiving_crud
from app.schemas.receiving import ReceivingHistory, ReceivingHistoryItem

router = APIRouter(prefix="/receiving", tags=["receiving"])


@router.get("", response_model=ReceivingHistory)
def list_receiving(
    session: SessionDep,
    _: CurrentUser,
    period: Period = Period.day,
    anchor: date | None = None,
) -> ReceivingHistory:
    """기간 내 입고 내역. 경계는 KST 달력 기준이다(core.timeframe 참조)."""
    start, end = period_bounds(period, anchor)
    rows = receiving_crud.list_records(session, start=start, end=end)
    items = [
        ReceivingHistoryItem(
            id=rec.id,
            wine_vintage_id=rec.wine_vintage_id,
            producer=product.producer,
            model_name=product.model_name,
            vintage=vintage.vintage,
            quantity=rec.quantity,
            received_at=rec.received_at,
            staff_email=user.email,
            memo=rec.memo,
            representative_image_key=vintage.representative_image_key,
            source=str(rec.source),
        )
        for rec, vintage, product, user in rows
    ]
    return ReceivingHistory(data=items, count=len(items))
