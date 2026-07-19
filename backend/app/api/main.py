"""API v1 라우터 집약. 기능 라우트는 후속 스토리에서 여기에 등록한다."""
from __future__ import annotations

from fastapi import APIRouter

from app.api.routes import (
    auth,
    health,
    images,
    inference,
    receiving,
    receiving_history,
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

# 후속 스토리 등록 예정:
#   초기 세팅 (3.3) · receiving 조회·수정 (4.x) · reports (5.x)
