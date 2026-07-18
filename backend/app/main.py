"""FastAPI 진입점. /api/v1 프리픽스, snake_case 와이어(Pydantic 기본), OpenAPI 노출."""
from __future__ import annotations

from fastapi import FastAPI

from app.api.main import api_router
from app.core.config import settings

app = FastAPI(
    title=settings.PROJECT_NAME,
    openapi_url=f"{settings.API_V1_PREFIX}/openapi.json",
)

app.include_router(api_router, prefix=settings.API_V1_PREFIX)


@app.get("/")
def root() -> dict[str, str]:
    return {
        "service": settings.PROJECT_NAME,
        "docs": "/docs",
        "health": f"{settings.API_V1_PREFIX}/health",
    }
