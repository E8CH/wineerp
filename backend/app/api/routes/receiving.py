"""입고 확정 라우트 (FR7)."""
from __future__ import annotations

import uuid

from fastapi import APIRouter, HTTPException, Response, status
from sqlalchemy.exc import IntegrityError

from app.api.deps import CurrentManager, CurrentUser, SessionDep
from app.crud import audit as audit_crud
from app.crud import receiving as receiving_crud
from app.models.audit import AuditAction
from app.models.wine import WineProduct, WineVintage
from app.schemas.receiving import ReceivingCreate, ReceivingRead, ReceivingUpdate

router = APIRouter(prefix="/receiving", tags=["receiving"])


def _wine_context(
    session: SessionDep, vintage_id, /
) -> tuple[WineVintage | None, WineProduct | None]:
    """감사 요약에 쓸 (빈티지, 제품). 삭제·미존재면 None을 채워 안전하게 라벨을 만든다."""
    vintage = session.get(WineVintage, vintage_id)
    product = (
        session.get(WineProduct, vintage.wine_product_id) if vintage else None
    )
    return vintage, product


def _label(vintage: WineVintage | None, product: WineProduct | None) -> str:
    if product is None:
        return "(삭제된 모델)"
    return audit_crud.format_wine_label(product, vintage)


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

    vintage, product = _wine_context(session, payload.wine_vintage_id)
    if vintage is None:
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

    # 새 입고만 로그에 남긴다 — 멱등 재생(위 200 반환)은 '생성'이 아니므로 제외한다.
    label = _label(vintage, product)
    audit_crud.record_event(
        session,
        action=AuditAction.receiving_create,
        actor=current_user,
        summary=f"{label} · {record.quantity}병 입고",
        entity_type="receiving",
        entity_id=record.id,
        detail={"quantity": record.quantity, "memo": record.memo, "label": label},
    )
    return ReceivingRead.model_validate(record)


@router.patch("/{record_id}", response_model=ReceivingRead)
def update_receiving(
    record_id: uuid.UUID,
    payload: ReceivingUpdate,
    session: SessionDep,
    current_user: CurrentUser,
) -> ReceivingRead:
    """수량 정정(FR8). 수정 이력은 `receiving_amendments`에 행으로 남는다."""
    # 잠금을 걸고 읽는다 — 동시 수정 시 두 이력이 같은 before를 주장하는 것을 막는다.
    record = receiving_crud.get_record(session, record_id, for_update=True)
    if record is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="입고 기록을 찾을 수 없습니다.",
        )
    # 변경 판정을 위해 수정 전 값을 먼저 스냅샷한다(update_record가 제자리 변경한다).
    before_quantity, before_memo = record.quantity, record.memo
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
    # 실제로 바뀐 경우에만 로그를 남긴다 — update_record가 no-op일 때 이력 행을 안 만드는
    # 것과 같은 기준. 무변경까지 로그하면 잡음이 진짜 수정을 묻는다.
    changed = (
        updated.quantity != before_quantity or updated.memo != before_memo
    )
    if changed:
        vintage, product = _wine_context(session, updated.wine_vintage_id)
        label = _label(vintage, product)
        audit_crud.record_event(
            session,
            action=AuditAction.receiving_amend,
            actor=current_user,
            summary=f"{label} · 수량 {before_quantity}→{updated.quantity}병 수정",
            entity_type="receiving",
            entity_id=updated.id,
            detail={
                "before_quantity": before_quantity,
                "after_quantity": updated.quantity,
                "before_memo": before_memo,
                "after_memo": updated.memo,
                "reason": payload.reason,
                "label": label,
            },
        )
    return ReceivingRead.model_validate(updated)


@router.delete("/{record_id}", response_model=ReceivingRead)
def cancel_receiving(
    record_id: uuid.UUID,
    session: SessionDep,
    current_user: CurrentManager,
) -> ReceivingRead:
    """입고 취소 — soft-delete만(AR6).

    ⚠️ **manager 전용.** 수정은 되돌릴 수 있지만 취소는 재고에서 통째로 빼는 일이고
    이 범위에 복구 UI가 없다. 되돌리기 비용이 다르면 권한도 달라야 한다.
    """
    record = receiving_crud.get_record(session, record_id, for_update=True)
    if record is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="입고 기록을 찾을 수 없습니다.",
        )
    vintage, product = _wine_context(session, record.wine_vintage_id)
    label = _label(vintage, product)
    quantity = record.quantity
    cancelled = receiving_crud.soft_delete(session, record)
    audit_crud.record_event(
        session,
        action=AuditAction.receiving_cancel,
        actor=current_user,
        summary=f"{label} · {quantity}병 입고 취소",
        entity_type="receiving",
        entity_id=cancelled.id,
        detail={"quantity": quantity, "label": label},
    )
    return ReceivingRead.model_validate(cancelled)
