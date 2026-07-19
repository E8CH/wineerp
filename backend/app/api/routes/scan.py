"""스캔 매칭 라우트 (FR5) — 바코드 code → WineProduct 후보 + 빈티지."""
from __future__ import annotations

from fastapi import APIRouter

from app.api.deps import CurrentUser, SessionDep
from app.crud import receiving as receiving_crud
from app.crud import wine as wine_crud
from app.schemas.scan import ScanRequest, ScanResult, WineProductRead, WineVintageRead

router = APIRouter(prefix="/scan", tags=["scan"])


@router.post("", response_model=ScanResult)
def scan(payload: ScanRequest, session: SessionDep, _: CurrentUser) -> ScanResult:
    products = wine_crud.find_products_by_barcode(session, payload.code)
    vintages_by_product = {
        p.id: wine_crud.get_vintages_for_product(session, p.id) for p in products
    }
    # 현재고는 빈티지 전체를 한 번에 조회한다(N+1이면 NFR1 2초를 못 지킨다).
    stock = receiving_crud.get_stock_map(
        session, [v.id for vs in vintages_by_product.values() for v in vs]
    )

    result = []
    for p in products:
        vintages = vintages_by_product[p.id]
        result.append(
            WineProductRead(
                id=p.id,
                producer=p.producer,
                model_name=p.model_name,
                region=p.region,
                country=p.country,
                grape=p.grape,
                lwin7=p.lwin7,
                vintages=[
                    WineVintageRead(
                        id=v.id,
                        vintage=v.vintage,
                        lwin11=v.lwin11,
                        representative_image_key=v.representative_image_key,
                        stock=stock.get(v.id, 0),
                    )
                    for v in vintages
                ],
            )
        )
    return ScanResult(code=payload.code, products=result)
