"""와인 마스터 DB 접근 계층. 매칭(2.4)은 code→barcode→link→products→vintages 경로."""
from __future__ import annotations

import uuid

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


def get_vintages_for_product(
    session: Session, wine_product_id: uuid.UUID
) -> list[WineVintage]:
    return list(
        session.exec(
            select(WineVintage).where(WineVintage.wine_product_id == wine_product_id)
        ).all()
    )
