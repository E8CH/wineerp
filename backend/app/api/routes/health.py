"""헬스체크 — DB에 의존하지 않고 앱 기동 여부만 확인(AC2)."""
from __future__ import annotations

from fastapi import APIRouter

from app.core.config import settings

router = APIRouter(tags=["utils"])


@router.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "project": settings.PROJECT_NAME, "environment": settings.ENVIRONMENT}
