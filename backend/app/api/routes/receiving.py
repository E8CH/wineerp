"""입고 확정 라우트 (FR7)."""
from __future__ import annotations

from fastapi import APIRouter, HTTPException, Response, status
from sqlalchemy.exc import IntegrityError

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
    response: Response,
) -> ReceivingRead:
    """입고 확정. `idempotency_key`가 있으면 재시도해도 레코드는 하나만 생긴다(Story 2.7).

    네트워크 실패는 정의상 클라이언트가 결과를 모르는 상태다. 응답이 유실된 뒤의 재시도를
    구분할 수 있는 쪽은 결과를 아는 서버뿐이며, 클라이언트의 '제출 중 비활성'은 동시 제출만
    막고 순차 재시도는 막지 못한다.
    """
    key = payload.idempotency_key
    if key is not None:
        existing = receiving_crud.find_by_idempotency_key(session, key)
        if existing is not None:
            # 재생은 '생성'이 아니다. 201로 답하면 클라이언트·로그가 새 입고로 오해한다.
            response.status_code = status.HTTP_200_OK
            return ReceivingRead.model_validate(existing)

    if session.get(WineVintage, payload.wine_vintage_id) is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="해당 빈티지를 찾을 수 없습니다.",
        )

    try:
        record = receiving_crud.create_record(
            session,
            wine_vintage_id=payload.wine_vintage_id,
            quantity=payload.quantity,
            staff_id=current_user.id,  # 담당자는 토큰에서만 — body를 신뢰하지 않는다
            memo=payload.memo,
            idempotency_key=key,
        )
    except IntegrityError:
        # 동일 키 두 요청이 선조회를 나란히 통과한 경합. unique 제약이 최종 방어선이고,
        # 여기서 500을 내면 클라이언트가 또 재시도한다.
        session.rollback()
        if key is None:
            raise
        existing = receiving_crud.find_by_idempotency_key(session, key)
        if existing is None:
            raise
        response.status_code = status.HTTP_200_OK
        return ReceivingRead.model_validate(existing)

    return ReceivingRead.model_validate(record)
