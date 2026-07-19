"""StoragePort 선택 — R2 → DB 순 (Story 6.1).

⚠️ 로컬 파일 어댑터는 **운영 기본값에서 뺐다**. Railway 컨테이너는 배포마다 교체되므로
로컬 디스크에 쌓인 라벨 사진이 전부 사라지고, DB의 `representative_image_key`만 남아
깨진 참조가 된다. 자격증명이 없을 때의 폴백은 이제 DB다.
(로컬 어댑터는 테스트·개발에서 명시적으로 주입해 쓴다.)
"""
from __future__ import annotations

from sqlmodel import Session

from app.core.config import settings
from app.services.ports import StoragePort


def build_storage(session: Session) -> StoragePort:
    if settings.r2_configured:
        from app.adapters.storage_r2 import R2StorageAdapter

        return R2StorageAdapter(
            account_id=settings.R2_ACCOUNT_ID,  # type: ignore[arg-type]
            access_key_id=settings.R2_ACCESS_KEY_ID,  # type: ignore[arg-type]
            secret_access_key=settings.R2_SECRET_ACCESS_KEY,  # type: ignore[arg-type]
            bucket=settings.R2_BUCKET,  # type: ignore[arg-type]
        )

    from app.adapters.storage_db import DbStorageAdapter

    return DbStorageAdapter(session)
