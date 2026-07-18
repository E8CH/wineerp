"""API v1 라우터 집약. 기능 라우트는 후속 스토리에서 여기에 등록한다."""
from __future__ import annotations

from fastapi import APIRouter

from app.api.routes import auth, health, images

api_router = APIRouter()
api_router.include_router(health.router)
api_router.include_router(auth.router)
api_router.include_router(images.router)

# 후속 스토리 등록 예정:
#   scan (2.4) · wines (3.x) · receiving (2.6/4.x) · reports (5.x)
