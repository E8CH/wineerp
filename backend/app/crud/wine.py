"""와인 마스터 DB 접근 계층. 매칭(2.4)은 code→barcode→link→products→vintages 경로."""
from __future__ import annotations

import uuid

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
        session.exec(select(WineProduct).where(WineProduct.id.in_(product_ids))).all()
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
