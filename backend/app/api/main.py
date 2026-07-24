"""API v1 라우터 집약. 기능 라우트는 후속 스토리에서 여기에 등록한다."""
from __future__ import annotations

from fastapi import APIRouter

from app.api.routes import (
    audit,
    auth,
    health,
    images,
    inference,
    inventory,
    receiving,
    receiving_history,
    reports,
    scan,
    wines,
)

api_router = APIRouter()
api_router.include_router(health.router)
api_router.include_router(auth.router)
api_router.include_router(images.router)
api_router.include_router(scan.router)
api_router.include_router(receiving.router)
api_router.include_router(receiving_history.router)
api_router.include_router(inference.router)
api_router.include_router(wines.router)
api_router.include_router(reports.router)
api_router.include_router(inventory.router)
api_router.include_router(audit.router)
