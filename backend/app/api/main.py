"""API v1 라우터 집약. 기능 라우트는 후속 스토리에서 여기에 등록한다."""
from __future__ import annotations

from fastapi import APIRouter

from app.api.routes import health

api_router = APIRouter()
api_router.include_router(health.router)

# 후속 스토리 등록 예정:
#   auth (1.3/1.4) · scan (2.x) · wines (3.x) · receiving (2.6/4.x) · reports (5.x)
