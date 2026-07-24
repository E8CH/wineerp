"""와인 마스터(모델) 등록·카탈로그·수정·삭제.

⚠️ LLM 추론 결과를 그대로 저장하는 경로가 아니다. 직원이 확인·수정한 값만 여기로 온다
(SM-C2 / 아키텍처 안티패턴 "LLM 결과 무확인 자동 저장").

삭제(DELETE)는 아카이브다(Story 7.x) — 제품을 카탈로그·재고·리포트·스캔에서 빼고 바코드
링크만 하드 제거하되, 입고기록(원장, 5년 보존)은 남긴다. 수정·삭제는 manager 전용
(모델명 변경은 모든 과거 기록의 표기를 바꾸고, 삭제는 재고에서 통째로 빼는 일이다).
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, HTTPException, status

from app.api.deps import CurrentManager, CurrentUser, SessionDep
from app.crud import audit as audit_crud
from app.crud import receiving as receiving_crud
from app.crud import wine as wine_crud
from app.models.audit import AuditAction
from app.models.receiving import ReceivingSource
from app.models.wine import WineProduct, WineVintage
from app.schemas.wine import (
    ProductCatalogItem,
    VintageStock,
    WineCreate,
    WineCreated,
    WineUpdate,
)

router = APIRouter(prefix="/wines", tags=["wines"])


def _catalog_item(
    product: WineProduct,
    vintages: list[WineVintage],
    stock: dict[uuid.UUID, int],
) -> ProductCatalogItem:
    """제품 + 빈티지들 + 재고맵 → 카탈로그 카드 1장. 대표 사진은 사진이 있는 첫 빈티지에서."""
    rep_image = next(
        (v.representative_image_key for v in vintages if v.representative_image_key),
        None,
    )
    return ProductCatalogItem(
        product_id=product.id,
        producer=product.producer,
        model_name=product.model_name,
        region=product.region,
        country=product.country,
        grape=product.grape,
        representative_image_key=rep_image,
        total_stock=sum(stock.get(v.id, 0) for v in vintages),
        created_at=product.created_at,
        vintages=[
            VintageStock(
                vintage_id=v.id,
                vintage=v.vintage,
                stock=stock.get(v.id, 0),
                representative_image_key=v.representative_image_key,
            )
            for v in vintages
        ],
    )


@router.get("", response_model=list[ProductCatalogItem])
def list_wines(session: SessionDep, _: CurrentUser) -> list[ProductCatalogItem]:
    """등록된 모델 카탈로그. 재고 탭과 **같은 아카이브 필터**를 공유하되 제품 단위로 묶는다.

    직원도 열람 가능(재고와 같은 운영 정보). 수정·삭제만 manager 전용이다.
    """
    rows = wine_crud.list_inventory_rows(session)  # (제품, 빈티지) — 아카이브 제외됨
    stock = receiving_crud.get_stock_map(session, [v.id for _p, v in rows])

    # 제품 단위로 묶는다. list_inventory_rows는 producer→model_name 정렬이라 순서 보존.
    grouped: dict[uuid.UUID, tuple[WineProduct, list[WineVintage]]] = {}
    for product, vintage in rows:
        entry = grouped.setdefault(product.id, (product, []))
        entry[1].append(vintage)
    return [_catalog_item(p, vs, stock) for p, vs in grouped.values()]


@router.get("/{product_id}", response_model=ProductCatalogItem)
def get_wine(
    product_id: uuid.UUID, session: SessionDep, _: CurrentUser
) -> ProductCatalogItem:
    product = wine_crud.get_active_product(session, product_id)
    if product is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="모델을 찾을 수 없습니다."
        )
    vintages = wine_crud.get_vintages_for_product(session, product.id)
    stock = receiving_crud.get_stock_map(session, [v.id for v in vintages])
    return _catalog_item(product, vintages, stock)


@router.patch("/{product_id}", response_model=ProductCatalogItem)
def update_wine(
    product_id: uuid.UUID,
    payload: WineUpdate,
    session: SessionDep,
    current_user: CurrentManager,
) -> ProductCatalogItem:
    """모델 메타 수정(manager). 입고내역·재고는 조인으로 읽어 자동 반영된다."""
    product = wine_crud.get_active_product(session, product_id)
    if product is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="모델을 찾을 수 없습니다."
        )
    # update_product가 제자리 변경하므로 수정 전 값을 먼저 스냅샷한다(before/after 로그용).
    before = {
        "producer": product.producer,
        "model_name": product.model_name,
        "region": product.region,
        "country": product.country,
        "grape": product.grape,
    }
    product = wine_crud.update_product(
        session,
        product,
        producer=payload.producer,
        model_name=payload.model_name,
        region=payload.region,
        country=payload.country,
        grape=payload.grape,
    )
    after = {
        "producer": product.producer,
        "model_name": product.model_name,
        "region": product.region,
        "country": product.country,
        "grape": product.grape,
    }
    audit_crud.record_event(
        session,
        action=AuditAction.wine_update,
        actor=current_user,
        summary=f"{product.producer} {product.model_name} 모델 정보 수정",
        entity_type="wine",
        entity_id=product.id,
        detail={"before": before, "after": after},
    )
    vintages = wine_crud.get_vintages_for_product(session, product.id)
    stock = receiving_crud.get_stock_map(session, [v.id for v in vintages])
    return _catalog_item(product, vintages, stock)


@router.delete("/{product_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_wine(
    product_id: uuid.UUID, session: SessionDep, current_user: CurrentManager
) -> None:
    """모델 삭제 = 아카이브(manager). 입고기록 원장은 보존, 바코드 링크만 제거해 재등록 가능."""
    product = wine_crud.get_active_product(session, product_id)
    if product is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="모델을 찾을 수 없습니다."
        )
    # 요약을 아카이브 전에 만든다 — archive_product 후에도 값은 남지만, 삭제 시점의
    # 표기를 스냅샷으로 못 박아 둔다(감사 로그는 "그때 무엇이었나"를 보존한다).
    summary = f"{product.producer} {product.model_name} 모델 삭제"
    detail = {
        "producer": product.producer,
        "model_name": product.model_name,
        "region": product.region,
        "country": product.country,
        "grape": product.grape,
    }
    wine_crud.archive_product(session, product)
    audit_crud.record_event(
        session,
        action=AuditAction.wine_archive,
        actor=current_user,
        summary=summary,
        entity_type="wine",
        entity_id=product_id,
        detail=detail,
    )


@router.post("", response_model=WineCreated, status_code=status.HTTP_201_CREATED)
def create_wine(
    payload: WineCreate,
    session: SessionDep,
    current_user: CurrentUser,
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

    audit_crud.record_event(
        session,
        action=AuditAction.wine_create,
        actor=current_user,
        summary=f"{product.producer} {product.model_name} 모델 등록",
        entity_type="wine",
        entity_id=product.id,
        detail={
            "producer": product.producer,
            "model_name": product.model_name,
            "vintage": vintage.vintage,
            "region": product.region,
            "country": product.country,
            "grape": product.grape,
        },
    )

    record_id = None
    if payload.initial_quantity is not None:
        # 초기 세팅의 재고 기준선(FR13). `source`로 입고 이벤트와 구분되지만
        # 같은 테이블에 있어 재고 집계는 여전히 한 곳에서만 일어난다.
        record = receiving_crud.create_record(
            session,
            wine_vintage_id=vintage.id,
            quantity=payload.initial_quantity,
            staff_id=current_user.id,
            source=ReceivingSource.initial_setup,
        )
        record_id = record.id
        # 초기 재고 설정도 별도 이벤트로 남긴다 — "등록"과 "몇 병으로 시작했나"는
        # 다른 사실이고, 초기 세팅분은 이후 입고와 구분해 추적돼야 한다(Story 3.3).
        label = audit_crud.format_wine_label(product, vintage)
        audit_crud.record_event(
            session,
            action=AuditAction.wine_initial_setup,
            actor=current_user,
            summary=f"{label} · 초기재고 {payload.initial_quantity}병 설정",
            entity_type="receiving",
            entity_id=record_id,
            detail={"quantity": payload.initial_quantity, "label": label},
        )

    return WineCreated(
        product_id=product.id,
        vintage_id=vintage.id,
        receiving_record_id=record_id,
    )
