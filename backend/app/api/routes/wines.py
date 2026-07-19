"""신규 와인 마스터 등록 (FR6).

⚠️ LLM 추론 결과를 그대로 저장하는 경로가 아니다. 직원이 확인·수정한 값만 여기로 온다
(SM-C2 / 아키텍처 안티패턴 "LLM 결과 무확인 자동 저장").
"""
from __future__ import annotations

from fastapi import APIRouter, status

from app.api.deps import CurrentUser, SessionDep
from app.crud import wine as wine_crud
from app.schemas.wine import WineCreate, WineCreated

router = APIRouter(prefix="/wines", tags=["wines"])


@router.post("", response_model=WineCreated, status_code=status.HTTP_201_CREATED)
def create_wine(
    payload: WineCreate,
    session: SessionDep,
    _: CurrentUser,
) -> WineCreated:
    product = wine_crud.create_product(
        session=session,
        producer=payload.producer,
        model_name=payload.model_name,
        region=payload.region,
        country=payload.country,
        grape=payload.grape,
    )
    vintage = wine_crud.add_vintage(
        session,
        wine_product_id=product.id,
        vintage=payload.vintage,  # None = NV
        representative_image_key=payload.representative_image_key,
    )
    if payload.barcode:
        barcode = wine_crud.get_or_create_barcode(session, payload.barcode)
        wine_crud.link_barcode_to_product(
            session, barcode_id=barcode.id, wine_product_id=product.id
        )
    return WineCreated(product_id=product.id, vintage_id=vintage.id)
