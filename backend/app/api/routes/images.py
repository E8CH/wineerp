"""이미지 업로드 (FR4) — EXIF 제거 후 StoragePort에 저장, DB엔 key만."""
from __future__ import annotations

import uuid

from fastapi import APIRouter, HTTPException, UploadFile, status

from app.api.deps import CurrentUser, StorageDep
from app.core.imaging import strip_exif_to_jpeg

router = APIRouter(prefix="/images", tags=["images"])


@router.post("", status_code=status.HTTP_201_CREATED)
async def upload_image(
    file: UploadFile,
    storage: StorageDep,
    _: CurrentUser,  # 인증 필요
) -> dict[str, str]:
    raw = await file.read()
    try:
        cleaned = strip_exif_to_jpeg(raw)
    except Exception as exc:  # noqa: BLE001 — 손상/비이미지 입력
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="이미지를 처리할 수 없습니다.",
        ) from exc
    key = f"labels/{uuid.uuid4().hex}.jpg"
    url = storage.put_object(cleaned, key, "image/jpeg")
    return {"key": key, "url": url}
