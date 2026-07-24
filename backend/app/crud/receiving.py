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
            # 삭제(아카이브)된 모델의 과거 입고는 내역에서 뺀다 — 재고·리포트와 같은
            # 아카이브 필터를 공유해 "재고엔 없는데 내역엔 있는" 괴리를 없앤다.
            # 원장(DB row)은 5년 보존을 위해 그대로 남고, 삭제 사실은 로그 탭에서 본다.
            # SQLite도 IS NULL을 실행하므로 이 필터는 실행 테스트로 변이 검증된다.
            .where(WineProduct.archived_at.is_(None))
            .where(ReceivingRecord.received_at >= start)
            .where(ReceivingRecord.received_at < end)
            .order_by(desc(ReceivingRecord.received_at), ReceivingRecord.id)
        ).all()
    )


def get_record(
    session: Session, record_id: uuid.UUID, *, for_update: bool = False
) -> ReceivingRecord | None:
    """활성 레코드만. 이미 취소(soft-delete)된 것은 수정 대상이 아니다.

    `for_update=True`면 행을 잠근다. ⚠️ 없으면 두 사람이 10병짜리를 동시에 열어
    각각 12·15로 저장했을 때 **두 이력 행이 모두 `before=10`**이 되어 서로 배타적인
    역사를 주장하고, 재고는 조용히 3만큼 틀린다(lost update).
    SQLite는 이 힌트를 무시하지만 운영(PostgreSQL)에서는 직렬화된다.
    """
    stmt = select(ReceivingRecord).where(ReceivingRecord.id == record_id)
    if for_update:
        stmt = stmt.with_for_update()
    rec = session.exec(stmt).first()
    if rec is None or rec.deleted_at is not None:
        return None
    return rec


def normalize_memo(memo: str | None) -> str | None:
    """빈 문자열은 삭제로 본다.

    `""`와 `None`이 둘 다 저장되면 "메모 있음" 판정이 호출부마다 갈린다
    (`is None`인지 `strip()` 검사인지). 경계에서 한 번 정규화한다.
    """
    if memo is None:
        return None
    stripped = memo.strip()
    return stripped or None


def update_record(
    session: Session,
    record: ReceivingRecord,
    *,
    quantity: int,
    changed_by: uuid.UUID,
    reason: str | None = None,
    memo: str | None = None,
    memo_provided: bool = False,
) -> ReceivingRecord:
    """수량·메모 수정 + 이력 기록을 **한 트랜잭션**에서.

    이력 없이 값만 덮어쓰면 무엇이 얼마에서 얼마로 바뀌었는지 사라진다.
    아무것도 바뀌지 않으면 이력 행을 만들지 않는다 — 잡음이 진짜 수정을 묻는다.
    메모만 바꾸는 것도 유효한 수정이며 이력에 남는다(5년 보존 원장).
    """
    new_memo = normalize_memo(memo) if memo_provided else record.memo
    if quantity == record.quantity and new_memo == record.memo:
        return record

    session.add(
        ReceivingAmendment(
            receiving_record_id=record.id,
            before_quantity=record.quantity,
            after_quantity=quantity,
            before_memo=record.memo,
            after_memo=new_memo,
            changed_by=changed_by,
            reason=reason,
        )
    )
    record.quantity = quantity
    record.memo = new_memo
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


def last_amendments_for(
    session: Session, record_ids: list[uuid.UUID]
) -> dict[uuid.UUID, tuple[datetime, str]]:
    """레코드별 **마지막** 수정 정보 (시각, 수정자 이메일).

    ⚠️ 내역 화면이 `staff_email`(최초 입고자)만 보여주면, 다른 직원이 수량을 고쳤을 때
    **원 입고자 이름 옆에 남의 수량**이 뜬다. 수정 권한을 누구에게나 준 것은 의도지만
    (Story 4.2), 그 사실이 화면에 없으면 기록이 조용히 오귀속된다.
    """
    if not record_ids:
        return {}
    rows = session.exec(
        select(ReceivingAmendment, User)
        .join(User, ReceivingAmendment.changed_by == User.id)
        .where(ReceivingAmendment.receiving_record_id.in_(record_ids))
        .order_by(ReceivingAmendment.changed_at)
    ).all()
    # 정렬이 오름차순이므로 뒤에 오는 것이 최종본이다.
    return {a.receiving_record_id: (a.changed_at, u.email) for a, u in rows}
