"""와인 마스터 DB 접근 계층. 매칭(2.4)은 code→barcode→link→products→vintages 경로."""
from __future__ import annotations

import uuid
from datetime import UTC, datetime

from sqlalchemy import desc, nullslast
from sqlmodel import Session, select

from app.models.wine import (
    Barcode,
    BarcodeWineProductLink,
    WineProduct,
    WineVintage,
)


def create_product(session: Session, **kwargs) -> WineProduct:
    product = WineProduct(**kwargs)
    session.add(product)
    session.commit()
    session.refresh(product)
    return product


def add_vintage(
    session: Session,
    *,
    wine_product_id: uuid.UUID,
    vintage: int | None = None,
    lwin11: str | None = None,
    representative_image_key: str | None = None,
) -> WineVintage:
    v = WineVintage(
        wine_product_id=wine_product_id,
        vintage=vintage,
        lwin11=lwin11,
        representative_image_key=representative_image_key,
    )
    session.add(v)
    session.commit()
    session.refresh(v)
    return v


def get_or_create_barcode(session: Session, code: str) -> Barcode:
    existing = session.exec(select(Barcode).where(Barcode.code == code)).first()
    if existing:
        return existing
    bc = Barcode(code=code)
    session.add(bc)
    session.commit()
    session.refresh(bc)
    return bc


def link_barcode_to_product(
    session: Session, *, barcode_id: uuid.UUID, wine_product_id: uuid.UUID
) -> None:
    existing = session.get(BarcodeWineProductLink, (barcode_id, wine_product_id))
    if existing:
        return
    session.add(
        BarcodeWineProductLink(barcode_id=barcode_id, wine_product_id=wine_product_id)
    )
    session.commit()


def find_products_by_barcode(session: Session, code: str) -> list[WineProduct]:
    barcode = session.exec(select(Barcode).where(Barcode.code == code)).first()
    if barcode is None:
        return []
    links = session.exec(
        select(BarcodeWineProductLink).where(
            BarcodeWineProductLink.barcode_id == barcode.id
        )
    ).all()
    product_ids = [link.wine_product_id for link in links]
    if not product_ids:
        return []
    return list(
        session.exec(
            select(WineProduct)
            .where(WineProduct.id.in_(product_ids))
            # 아카이브(삭제)된 제품은 스캔 매칭에서 제외한다. 삭제 시 바코드 링크를
            # 지우므로 보통은 링크 자체가 없어 여기 오지 않지만, 이 필터가 최후의 방어선이다.
            .where(WineProduct.archived_at.is_(None))
        ).all()
    )


def vintages_for_product_stmt(wine_product_id: uuid.UUID):
    """후보 목록 조회 구문. 정렬 계약이 여기 한 곳에 산다.

    ⚠️ 테스트가 이 함수를 직접 컴파일해 방언별 SQL을 검사한다. 정렬을
    `get_vintages_for_product` 안에 인라인해 두면, 실행 테스트는 SQLite에서만 돌기 때문에
    `nullslast` 회귀를 구조적으로 잡을 수 없다(SQLite는 DESC에서 NULL이 원래 마지막).

    - `nullslast`: PostgreSQL은 DESC에서 NULL을 먼저 둔다. 빠뜨리면 운영에서만 NV가
      목록 맨 위로 올라온다.
    - `id` 타이브레이커: 동점(같은 연도 2건, NV 2건)의 순서가 임의가 되는 것을 막는다.
      같은 연도·다른 용량/수입사는 N:M 바코드 모델이 존재하는 바로 그 이유이고, 거의 같은
      두 행이 순서를 바꿔 뜨면 직원이 틀린 재고 단위로 입고한다.

    순서는 UX 계약이다(첫 항목이 가장 눌릴 확률이 높음) — 프론트에서 재정렬하지 말 것.
    """
    return (
        select(WineVintage)
        .where(WineVintage.wine_product_id == wine_product_id)
        .order_by(nullslast(desc(WineVintage.vintage)), WineVintage.id)
    )


def get_vintages_for_product(
    session: Session, wine_product_id: uuid.UUID
) -> list[WineVintage]:
    return list(session.exec(vintages_for_product_stmt(wine_product_id)).all())


def inventory_rows_stmt():
    """재고 목록 조회 구문 (Story 6.2). 정렬 계약이 여기 한 곳에 산다.

    ⚠️ scan 경로(`vintages_for_product_stmt`)와 같은 이유로 구문을 함수로 **추출**한다.
    실행 테스트는 SQLite에서만 도는데 SQLite는 DESC에서 NULL이 원래 마지막이라
    `nullslast`가 no-op이다 — 인라인하면 `nullslast`를 지워도 초록불이라 운영(Postgres)
    에서만 NV가 목록 맨 위로 올라오는 회귀를 구조적으로 못 잡는다. 이 함수를 직접
    컴파일하는 Postgres 단언(test)이 그 공백을 메운다.

    정렬: 생산자→모델명 알파벳순으로 묶고, 같은 와인 안에서는 최신 빈티지 우선
    (`nullslast`로 NV는 맨 끝). `id` 타이브레이커가 없으면 같은 연도 2행의 순서가
    방언마다 달라져 스크롤 위치가 흔들린다.
    """
    return (
        select(WineProduct, WineVintage)
        .join(WineVintage, WineVintage.wine_product_id == WineProduct.id)
        # 아카이브(삭제)된 제품은 재고·카탈로그에서 제외한다. SQLite도 IS NULL을 그대로
        # 실행하므로 이 필터는 실행 테스트로 변이 검증된다(아카이브 후 목록에서 사라지는지).
        .where(WineProduct.archived_at.is_(None))
        .order_by(
            WineProduct.producer,
            WineProduct.model_name,
            nullslast(desc(WineVintage.vintage)),
            WineVintage.id,
        )
    )


def list_inventory_rows(session: Session) -> list[tuple[WineProduct, WineVintage]]:
    """재고 목록용 (제품, 빈티지) 전체 (Story 6.2).

    빈티지 = 가격결정·재고 단위(AR2)이므로 행은 빈티지 단위다. 제품·빈티지를
    **한 번의 조인**으로 가져온다 — 행마다 제품을 다시 조회하면 카탈로그가 커질수록
    N+1로 느려진다(NFR1). 현재고는 호출부가 `get_stock_map`으로 한 번에 합산한다.

    카탈로그(모델 목록) 라우트도 이 함수를 재사용해 **같은 아카이브 필터**를 공유한다 —
    재고는 빈티지 단위 행으로, 카탈로그는 제품 단위로 묶어 보여줄 뿐 원천이 같다.
    """
    return list(session.exec(inventory_rows_stmt()).all())


def get_active_product(
    session: Session, product_id: uuid.UUID
) -> WineProduct | None:
    """활성(미아카이브) 제품만. 아카이브(삭제)된 제품은 상세·수정 대상이 아니다."""
    product = session.get(WineProduct, product_id)
    if product is None or product.archived_at is not None:
        return None
    return product


def update_product(
    session: Session,
    product: WineProduct,
    *,
    producer: str,
    model_name: str,
    region: str | None,
    country: str | None,
    grape: str | None,
) -> WineProduct:
    """제품(모델) 메타 수정. 입고내역·재고는 이 제품을 조인으로 읽으므로 **자동 전파**된다
    (모델명을 복사해 두는 곳이 없다). 그래서 여기서 값만 바꾸면 모든 화면에 반영된다."""
    product.producer = producer
    product.model_name = model_name
    product.region = region
    product.country = country
    product.grape = grape
    session.add(product)
    session.commit()
    session.refresh(product)
    return product


def archive_product(session: Session, product: WineProduct) -> WineProduct:
    """모델 "삭제" = 아카이브 + 바코드 링크 제거.

    ⚠️ 입고기록(원장)은 하드삭제하지 않는다(국세기본법 5년 보존, AR6). archived_at만
    채워 카탈로그·재고·리포트·스캔에서 빠지게 하고, 내역엔 과거 기록이 남는다.
    바코드 링크는 **하드 제거**한다 — 남겨 두면 그 바코드를 다시 스캔했을 때 아카이브된
    옛 제품이 계속 매칭돼, 재등록 시 바코드 하나가 옛/새 제품 둘에 걸리는 충돌이 난다.
    링크를 지우면 바코드가 풀려 같은 모델을 충돌 없이 새로 등록할 수 있다.
    """
    product.archived_at = datetime.now(UTC)
    session.add(product)
    links = session.exec(
        select(BarcodeWineProductLink).where(
            BarcodeWineProductLink.wine_product_id == product.id
        )
    ).all()
    for link in links:
        # 바코드↔제품 링크는 원장이 아니다(5년 보존 대상 아님). 지워야 바코드가 풀려 같은
        # 모델을 충돌 없이 재등록할 수 있다. 입고기록은 건드리지 않는다 —
        # test_archive_preserves_receiving_ledger가 실행으로 못 박는다.
        session.delete(link)  # hard-delete-ok: 바코드 링크(원장 아님)
    session.commit()
    session.refresh(product)
    return product
