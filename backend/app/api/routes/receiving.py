"""입고 확정 라우트 (FR7)."""
from __future__ import annotations

import uuid

from fastapi import APIRouter, HTTPException, Response, status
from sqlalchemy.exc import IntegrityError

from app.api.deps import CurrentManager, CurrentUser, SessionDep
from app.crud import receiving as receiving_crud
from app.models.wine import WineVintage
from app.schemas.receiving import ReceivingCreate, ReceivingRead, ReceivingUpdate

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
            memo=receiving_crud.normalize_memo(payload.memo),
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


@router.patch("/{record_id}", response_model=ReceivingRead)
def update_receiving(
    record_id: uuid.UUID,
    payload: ReceivingUpdate,
    session: SessionDep,
    current_user: CurrentUser,
) -> ReceivingRead:
    """수량 정정(FR8). 수정 이력은 `receiving_amendments`에 행으로 남는다."""
    record = receiving_crud.get_record(session, record_id)
    if record is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="입고 기록을 찾을 수 없습니다.",
        )
    updated = receiving_crud.update_record(
        session,
        record,
        quantity=payload.quantity,
        changed_by=current_user.id,
        reason=payload.reason,
        memo=payload.memo,
        # 필드가 요청에 실제로 담겼을 때만 메모를 건드린다 — 미지정과 삭제를 구분한다.
        memo_provided="memo" in payload.model_fields_set,
    )
    return ReceivingRead.model_validate(updated)


@router.delete("/{record_id}", response_model=ReceivingRead)
def cancel_receiving(
    record_id: uuid.UUID,
    session: SessionDep,
    _: CurrentManager,
) -> ReceivingRead:
    """입고 취소 — soft-delete만(AR6).

    ⚠️ **manager 전용.** 수정은 되돌릴 수 있지만 취소는 재고에서 통째로 빼는 일이고
    이 범위에 복구 UI가 없다. 되돌리기 비용이 다르면 권한도 달라야 한다.
    """
    record = receiving_crud.get_record(session, record_id)
    if record is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="입고 기록을 찾을 수 없습니다.",
        )
    return ReceivingRead.model_validate(receiving_crud.soft_delete(session, record))
