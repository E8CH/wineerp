"""감사 로그 DB 접근 계층.

기록(`record_event`)은 변경을 일으킨 라우트가 호출한다 — 행위자(current_user)와 의미
있는 요약이 라우트에 있기 때문이다. ⚠️ 원자성 한계를 솔직히 적어 둔다: 변경 CRUD가
먼저 커밋되고 이 함수가 별도로 커밋하므로, 이 커밋이 실패하면 변경은 남고 로그만 빠진다.
이 앱 규모에선 로그 유실을 감수하되 변경을 막지는 않는 쪽을 택했다(로그 실패로 입고가
롤백되면 더 나쁘다). 진짜 원자성이 필요해지면 같은 세션·같은 트랜잭션으로 옮긴다.
"""
from __future__ import annotations

import uuid
from typing import Any

from sqlalchemy import desc
from sqlmodel import Session, select

from app.models.audit import AuditAction, AuditLog
from app.models.user import User
from app.models.wine import WineProduct, WineVintage


def format_wine_label(product: WineProduct, vintage: WineVintage | None) -> str:
    """"생산자 모델명 빈티지" 한 줄 라벨. 빈티지 없으면(NV) 연도 없이."""
    year = str(vintage.vintage) if vintage and vintage.vintage is not None else "NV"
    return f"{product.producer} {product.model_name} {year}".strip()


def record_event(
    session: Session,
    *,
    action: AuditAction,
    actor: User,
    summary: str,
    entity_type: str,
    entity_id: uuid.UUID | None = None,
    detail: dict[str, Any] | None = None,
) -> AuditLog:
    """활동 로그 1건 기록. 행위자 이메일·요약은 시점 스냅샷으로 비정규화 저장한다."""
    event = AuditLog(
        action=action,
        actor_id=actor.id,
        actor_email=actor.email,  # 스냅샷 — 나중에 개명·삭제돼도 로그는 그대로
        summary=summary,
        entity_type=entity_type,
        entity_id=entity_id,
        detail=detail or {},
    )
    session.add(event)
    session.commit()
    session.refresh(event)
    return event


def list_events(session: Session, *, limit: int = 200) -> list[AuditLog]:
    """최근 활동 로그 — 최신순. 연속 리스트라 기간 세그먼트 없이 최근 N건을 준다.

    `created_at DESC, id DESC` — 같은 시각(초기 세팅+등록이 밀리초 차)에도 순서가
    안정적이어야 스크롤 중 항목이 뒤바뀌지 않는다.
    """
    return list(
        session.exec(
            select(AuditLog)
            .order_by(desc(AuditLog.created_at), desc(AuditLog.id))
            .limit(limit)
        ).all()
    )
