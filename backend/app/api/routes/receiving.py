"""입고 확정 라우트 (FR7)."""
from __future__ import annotations

from fastapi import APIRouter, HTTPException, status

from app.api.deps import CurrentUser, SessionDep
from app.crud import receiving as receiving_crud
from app.models.wine import WineVintage
from app.schemas.receiving import ReceivingCreate, ReceivingRead

router = APIRouter(prefix="/receiving", tags=["receiving"])


@router.post("", response_model=ReceivingRead, status_code=status.HTTP_201_CREATED)
def create_receiving(
    payload: ReceivingCreate,
    session: SessionDep,
    current_user: CurrentUser,
) -> ReceivingRead:
    if session.get(WineVintage, payload.wine_vintage_id) is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="해당 빈티지를 찾을 수 없습니다.",
        )
    record = receiving_crud.create_record(
        session,
        wine_vintage_id=payload.wine_vintage_id,
        quantity=payload.quantity,
        staff_id=current_user.id,  # 담당자는 토큰에서만 — body를 신뢰하지 않는다
        memo=payload.memo,
    )
    return ReceivingRead.model_validate(record)
