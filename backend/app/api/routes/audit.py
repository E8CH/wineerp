"""활동 로그 조회 — 누가 데이터를 넣고·고치고·지웠는지.

**manager 전용.** 감사 성격의 정보이고, 리포트와 같은 권한 경계를 따른다(서버 403 +
프론트 차단). 연속 리스트라 기간 세그먼트 없이 최근 N건을 최신순으로 준다.
"""
from __future__ import annotations

from fastapi import APIRouter, Query

from app.api.deps import CurrentManager, SessionDep
from app.crud import audit as audit_crud
from app.schemas.audit import AuditItem, AuditList

router = APIRouter(prefix="/audit", tags=["audit"])


@router.get("", response_model=AuditList)
def list_audit(
    session: SessionDep,
    _: CurrentManager,
    limit: int = Query(default=200, ge=1, le=500),
) -> AuditList:
    events = audit_crud.list_events(session, limit=limit)
    items = [AuditItem.model_validate(e) for e in events]
    return AuditList(data=items, count=len(items))
