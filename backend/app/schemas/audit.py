"""감사 로그 입출력 스키마."""
from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any

from pydantic import BaseModel, ConfigDict


class AuditItem(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    action: str
    actor_email: str
    summary: str
    entity_type: str
    entity_id: uuid.UUID | None = None
    detail: dict[str, Any] = {}
    created_at: datetime


class AuditList(BaseModel):
    data: list[AuditItem]
    count: int
