"""StoragePort 팩토리 — env에 따라 R2 또는 로컬 어댑터 선택."""
from __future__ import annotations

from app.core.config import settings
from app.services.ports import StoragePort


def get_storage() -> StoragePort:
    if settings.r2_configured:
        from app.adapters.storage_r2 import R2StorageAdapter

        return R2StorageAdapter(
            account_id=settings.R2_ACCOUNT_ID,  # type: ignore[arg-type]
            access_key_id=settings.R2_ACCESS_KEY_ID,  # type: ignore[arg-type]
            secret_access_key=settings.R2_SECRET_ACCESS_KEY,  # type: ignore[arg-type]
            bucket=settings.R2_BUCKET,  # type: ignore[arg-type]
        )
    from app.adapters.storage_local import LocalStorageAdapter

    return LocalStorageAdapter(settings.IMAGE_STORAGE_DIR)
