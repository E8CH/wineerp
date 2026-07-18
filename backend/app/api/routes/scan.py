"""스캔 매칭 라우트 (FR5) — 바코드 code → WineProduct 후보 + 빈티지."""
from __future__ import annotations

from fastapi import APIRouter

from app.api.deps import CurrentUser, SessionDep
from app.crud import wine as wine_crud
from app.schemas.scan import ScanRequest, ScanResult, WineProductRead, WineVintageRead

router = APIRouter(prefix="/scan", tags=["scan"])


@router.post("", response_model=ScanResult)
def scan(payload: ScanRequest, session: SessionDep, _: CurrentUser) -> ScanResult:
    products = wine_crud.find_products_by_barcode(session, payload.code)
    result = []
    for p in products:
        vintages = wine_crud.get_vintages_for_product(session, p.id)
        result.append(
            WineProductRead(
                id=p.id,
                producer=p.producer,
                model_name=p.model_name,
                region=p.region,
                country=p.country,
                grape=p.grape,
                lwin7=p.lwin7,
                vintages=[WineVintageRead.model_validate(v) for v in vintages],
            )
        )
    return ScanResult(code=payload.code, products=result)
