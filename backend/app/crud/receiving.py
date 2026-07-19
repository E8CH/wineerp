"""입고 기록 DB 접근 계층 (FR7).

⚠️ 재고를 세는 곳은 여기 한 곳이다. 화면·리포트가 각자 합산하면 soft-delete 필터를
빠뜨린 사본이 번진다. 출고·판매가 생기면 현재고 정의가 바뀌는데, 그때 고칠 지점도 여기다.
"""
from __future__ import annotations

import uuid
from collections.abc import Iterable
from datetime import UTC, datetime

from sqlalchemy import desc, func
from sqlmodel import Session, select

from app.models.amendment import ReceivingAmendment
from app.models.receiving import ReceivingRecord, ReceivingSource
from app.models.user import User
from app.models.wine import WineProduct, WineVintage

# SQLite의 바인드 파라미터 상한(32,766)이 더 낮으므로 그쪽에 맞춘다.
_MAX_BIND_PARAMS = 30_000


def find_by_idempotency_key(
    session: Session, key: uuid.UUID
) -> ReceivingRecord | None:
    """이미 처리된 요청인지 확인. soft-delete된 것도 찾는다 —
    취소된 입고를 재시도가 되살리면 안 되고, 그건 '새 입고'도 아니다."""
    return session.exec(
        select(ReceivingRecord).where(ReceivingRecord.idempotency_key == key)
    ).first()


def create_record(
    session: Session,
    *,
    wine_vintage_id: uuid.UUID,
    quantity: int,
    staff_id: uuid.UUID,
    memo: str | None = None,
    idempotency_key: uuid.UUID | None = None,
    source: ReceivingSource = ReceivingSource.receiving,
) -> ReceivingRecord:
    """입고 1건 생성. `received_at`은 모델 기본값(서버 UTC)이 채운다 — 인자로 받지 않는다."""
    record = ReceivingRecord(
        wine_vintage_id=wine_vintage_id,
        quantity=quantity,
        staff_id=staff_id,
        memo=memo,
        idempotency_key=idempotency_key,
        source=source,
    )
    session.add(record)
    session.commit()
    session.refresh(record)
    return record


def get_stock_map(
    session: Session, vintage_ids: Iterable[uuid.UUID]
) -> dict[uuid.UUID, int]:
    """빈티지별 현재고. 단일 GROUP BY 쿼리(N+1 금지, NFR1 2초).

    현재고 = 입고 수량 합계. 출고·판매는 범위 밖(Non-Goal)이라 아직 뺄 것이 없다.
    기록이 없는 빈티지도 0으로 채워 반환한다 — 키가 빠지면 호출부마다 null 처리를
    재발명하게 된다.
    """
    ids = list(dict.fromkeys(vintage_ids))  # 중복 제거 — 바인드 파라미터를 낭비하지 않는다
    # ⚠️ 0으로 미리 채우는 것이 "기록 없는 빈티지" 처리의 전부다.
    # GROUP BY는 행이 있는 그룹만 돌려주므로 SUM에 COALESCE를 걸어도 소용없다
    # (그래서 걸지 않았다). 이 pre-seed를 지우면 키가 사라지고 호출부마다
    # null 처리를 재발명하게 된다.
    stock = dict.fromkeys(ids, 0)
    if not ids:
        return stock

    # SQLite 32,766 / PostgreSQL 65,535 바인드 파라미터 상한. 스캔 경로는 몇 건뿐이지만
    # 이 함수는 범용이고, 첫 재고 리포트가 상한을 그대로 밟는다.
    for start in range(0, len(ids), _MAX_BIND_PARAMS):
        chunk = ids[start : start + _MAX_BIND_PARAMS]
        rows = session.exec(
            select(
                ReceivingRecord.wine_vintage_id,
                func.sum(ReceivingRecord.quantity),
            )
            .where(ReceivingRecord.wine_vintage_id.in_(chunk))
            .where(ReceivingRecord.deleted_at.is_(None))  # soft-delete 제외
            .group_by(ReceivingRecord.wine_vintage_id)
        ).all()
        for vintage_id, total in rows:
            stock[vintage_id] = int(total)
    return stock


def list_records(
    session: Session, *, start: datetime, end: datetime
) -> list[tuple]:
    """기간 내 입고 내역. 와인·담당자를 **한 번의 조인**으로 가져온다.

    행마다 와인/사용자를 따로 조회하면 하루 100건에서 300 왕복이 된다.
    경계는 호출부가 `core.timeframe.period_bounds`로 KST 기준 계산해 넘긴다.
    """
    return list(
        session.exec(
            select(ReceivingRecord, WineVintage, WineProduct, User)
            .join(WineVintage, ReceivingRecord.wine_vintage_id == WineVintage.id)
            .join(WineProduct, WineVintage.wine_product_id == WineProduct.id)
            .join(User, ReceivingRecord.staff_id == User.id)
            .where(ReceivingRecord.deleted_at.is_(None))  # soft-delete 제외(AR6)
            .where(ReceivingRecord.received_at >= start)
            .where(ReceivingRecord.received_at < end)
            .order_by(desc(ReceivingRecord.received_at), ReceivingRecord.id)
        ).all()
    )


def get_record(session: Session, record_id: uuid.UUID) -> ReceivingRecord | None:
    """활성 레코드만. 이미 취소(soft-delete)된 것은 수정 대상이 아니다."""
    rec = session.get(ReceivingRecord, record_id)
    if rec is None or rec.deleted_at is not None:
        return None
    return rec


def update_quantity(
    session: Session,
    record: ReceivingRecord,
    *,
    quantity: int,
    changed_by: uuid.UUID,
    reason: str | None = None,
) -> ReceivingRecord:
    """수량 수정 + 이력 기록을 **한 트랜잭션**에서.

    이력 없이 수량만 덮어쓰면 무엇이 얼마에서 얼마로 바뀌었는지 사라진다.
    변경이 없으면 이력 행을 만들지 않는다 — 잡음을 남기지 않는다.
    """
    if quantity == record.quantity:
        return record

    session.add(
        ReceivingAmendment(
            receiving_record_id=record.id,
            before_quantity=record.quantity,
            after_quantity=quantity,
            changed_by=changed_by,
            reason=reason,
        )
    )
    record.quantity = quantity
    session.add(record)
    session.commit()
    session.refresh(record)
    return record


def soft_delete(session: Session, record: ReceivingRecord) -> ReceivingRecord:
    """취소는 `deleted_at`만 채운다. 하드삭제 함수는 만들지 않는다(AR6, 5년 보존)."""
    record.deleted_at = datetime.now(UTC)
    session.add(record)
    session.commit()
    session.refresh(record)
    return record


def list_amendments(
    session: Session, record_id: uuid.UUID
) -> list[ReceivingAmendment]:
    return list(
        session.exec(
            select(ReceivingAmendment)
            .where(ReceivingAmendment.receiving_record_id == record_id)
            .order_by(ReceivingAmendment.changed_at)
        ).all()
    )
