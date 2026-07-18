"""시연용 와인 마스터 시드 + LWIN CSV 로더.

- 시연 10종(바코드·빈티지·lwin 예시 포함). N:M·NV 케이스를 의도적으로 포함.
- 실제 LWIN CSV(Liv-ex, 폼 뒤)는 미보유 → `data/lwin/*.csv` 존재 시에만 로딩.
  lwin7/lwin11을 내부 표준키로 보관해 카탈로그 벤더 교체 시에도 안정 매핑.
"""
from __future__ import annotations

import csv
from pathlib import Path

from sqlmodel import Session, select

from app.crud import wine as wine_crud
from app.models.wine import WineProduct

# 시연 10종. vintages 각 항목 = (vintage|None, lwin11|None). barcodes = 연결할 코드들.
# ⚠️ N:M 예시: "SHARED-8801234567890" 바코드는 서로 다른 두 제품에 연결(1 바코드→다수 와인).
# ⚠️ 복수 바코드 예시: 샤토 마고는 원산지·수입사 코드 2개(1 와인→다수 바코드).
# ⚠️ NV 예시: 샴페인은 vintage=None.
DEMO_WINES: list[dict] = [
    {
        "producer": "Château Margaux", "model_name": "Château Margaux",
        "region": "Margaux", "country": "France", "grape": "Cabernet Sauvignon",
        "lwin7": "1011531",
        "vintages": [(2015, "1011531201500750"), (2018, "1011531201800750")],
        "barcodes": ["3760000000015", "8801111000015"],  # 원산지 + 수입사(복수 바코드)
    },
    {
        "producer": "Domaine de la Romanée-Conti", "model_name": "La Tâche",
        "region": "Burgundy", "country": "France", "grape": "Pinot Noir",
        "lwin7": "1017447",
        "vintages": [(2017, None), (2019, None)],
        "barcodes": ["3760000000022"],
    },
    {
        "producer": "Antinori", "model_name": "Tignanello",
        "region": "Tuscany", "country": "Italy", "grape": "Sangiovese",
        "lwin7": "1002345",
        "vintages": [(2019, None), (2020, None)],
        "barcodes": ["8001234000039"],
    },
    {
        "producer": "Penfolds", "model_name": "Grange",
        "region": "South Australia", "country": "Australia", "grape": "Shiraz",
        "lwin7": "1003456",
        "vintages": [(2016, None)],
        "barcodes": ["9312345000046"],
    },
    {
        "producer": "Vega Sicilia", "model_name": "Único",
        "region": "Ribera del Duero", "country": "Spain", "grape": "Tempranillo",
        "lwin7": "1004567",
        "vintages": [(2012, None)],
        "barcodes": ["8412345000053"],
    },
    {
        "producer": "Moët & Chandon", "model_name": "Impérial Brut",
        "region": "Champagne", "country": "France", "grape": "Blend",
        "lwin7": "1005678",
        "vintages": [(None, None)],  # NV — 인식 실패가 아니라 1급 상태
        "barcodes": ["3185370000060"],
    },
    {
        "producer": "Cloudy Bay", "model_name": "Sauvignon Blanc",
        "region": "Marlborough", "country": "New Zealand", "grape": "Sauvignon Blanc",
        "lwin7": "1006789",
        "vintages": [(2022, None), (2023, None)],
        "barcodes": ["9414000000077"],
    },
    {
        "producer": "Ridge", "model_name": "Monte Bello",
        "region": "Santa Cruz Mountains", "country": "USA", "grape": "Cabernet Sauvignon",
        "lwin7": "1007890",
        "vintages": [(2018, None)],
        "barcodes": ["SHARED-8801234567890"],  # 공유 바코드(수입사 부실 케이스)
    },
    {
        "producer": "Ridge", "model_name": "Geyserville",
        "region": "Sonoma", "country": "USA", "grape": "Zinfandel",
        "lwin7": "1007891",
        "vintages": [(2019, None)],
        "barcodes": ["SHARED-8801234567890"],  # 위와 동일 바코드 → 1 바코드 : 2 와인
    },
    {
        "producer": "Errazuriz", "model_name": "Don Maximiano",
        "region": "Aconcagua", "country": "Chile", "grape": "Cabernet Sauvignon",
        "lwin7": "1008902",
        "vintages": [(2019, None), (2021, None)],
        "barcodes": ["7804320000091"],
    },
]


def seed_demo_wines(session: Session) -> int:
    """시연 와인을 시드하고 생성된 WineProduct 수를 반환(멱등: 이미 있으면 스킵)."""
    created = 0
    for entry in DEMO_WINES:
        exists = session.exec(
            select(WineProduct).where(
                WineProduct.producer == entry["producer"],
                WineProduct.model_name == entry["model_name"],
            )
        ).first()
        if exists:
            continue
        product = wine_crud.create_product(
            session,
            producer=entry["producer"],
            model_name=entry["model_name"],
            region=entry.get("region"),
            country=entry.get("country"),
            grape=entry.get("grape"),
            lwin7=entry.get("lwin7"),
        )
        for vintage, lwin11 in entry["vintages"]:
            wine_crud.add_vintage(
                session, wine_product_id=product.id, vintage=vintage, lwin11=lwin11
            )
        for code in entry["barcodes"]:
            barcode = wine_crud.get_or_create_barcode(session, code)
            wine_crud.link_barcode_to_product(
                session, barcode_id=barcode.id, wine_product_id=product.id
            )
        created += 1
    return created


def load_lwin_csv(session: Session, csv_path: Path) -> int:
    """LWIN CSV가 존재하면 WineProduct(lwin7)로 로딩. 없으면 0.

    기대 컬럼(유연): LWIN, DISPLAY_NAME/PRODUCER, REGION, COUNTRY. 스키마 확정은 실제 CSV 확보 후.
    """
    if not csv_path.exists():
        return 0
    loaded = 0
    with csv_path.open(encoding="utf-8-sig", newline="") as fh:
        reader = csv.DictReader(fh)
        for row in reader:
            lwin7 = (row.get("LWIN") or row.get("lwin") or "").strip()[:7]
            name = (row.get("DISPLAY_NAME") or row.get("WINE") or "").strip()
            producer = (row.get("PRODUCER") or name).strip()
            if not lwin7 or not name:
                continue
            exists = session.exec(
                select(WineProduct).where(WineProduct.lwin7 == lwin7)
            ).first()
            if exists:
                continue
            wine_crud.create_product(
                session,
                producer=producer or name,
                model_name=name,
                region=(row.get("REGION") or None),
                country=(row.get("COUNTRY") or None),
                lwin7=lwin7,
            )
            loaded += 1
    return loaded
