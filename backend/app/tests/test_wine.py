"""Story 2.1 — 2계층 와인 스키마·N:M·NV·시드 (SQLite in-memory)."""
from __future__ import annotations

from collections.abc import Iterator

import pytest
from sqlalchemy.pool import StaticPool
from sqlmodel import Session, SQLModel, create_engine

from app.crud import wine as wine_crud
from app.seed.wines import DEMO_WINES, seed_demo_wines


@pytest.fixture
def session() -> Iterator[Session]:
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    SQLModel.metadata.create_all(engine)
    with Session(engine) as s:
        yield s


def test_seed_creates_ten_products(session):
    created = seed_demo_wines(session)
    assert created == 10
    assert len(DEMO_WINES) == 10
    # 멱등: 재실행 시 추가 생성 없음
    assert seed_demo_wines(session) == 0


def test_nv_vintage_is_null(session):
    seed_demo_wines(session)
    products = wine_crud.find_products_by_barcode(session, "3185370000060")  # Moët NV
    assert len(products) == 1
    vintages = wine_crud.get_vintages_for_product(session, products[0].id)
    assert len(vintages) == 1
    assert vintages[0].vintage is None  # NV = NULL, 인식 실패 아님


def test_barcode_maps_to_multiple_products(session):
    """1 바코드 → 다수 와인 (공유 바코드)."""
    seed_demo_wines(session)
    products = wine_crud.find_products_by_barcode(session, "SHARED-8801234567890")
    names = sorted(p.model_name for p in products)
    assert names == ["Geyserville", "Monte Bello"]


def test_product_has_multiple_barcodes(session):
    """1 와인 → 다수 바코드 (원산지 + 수입사)."""
    seed_demo_wines(session)
    p1 = wine_crud.find_products_by_barcode(session, "3760000000015")
    p2 = wine_crud.find_products_by_barcode(session, "8801111000015")
    assert len(p1) == 1 and len(p2) == 1
    assert p1[0].id == p2[0].id  # 동일 제품(샤토 마고)
    assert p1[0].model_name == "Château Margaux"


def test_multiple_vintages_per_product(session):
    seed_demo_wines(session)
    products = wine_crud.find_products_by_barcode(session, "3760000000015")
    vintages = sorted(
        v.vintage for v in wine_crud.get_vintages_for_product(session, products[0].id)
    )
    assert vintages == [2015, 2018]


def test_unknown_barcode_returns_empty(session):
    seed_demo_wines(session)
    assert wine_crud.find_products_by_barcode(session, "0000000000000") == []
