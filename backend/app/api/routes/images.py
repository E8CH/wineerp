"""이미지 업로드 (FR4) — EXIF 제거 후 StoragePort에 저장, DB엔 key만."""
from __future__ import annotations

import hashlib
import uuid

from fastapi import APIRouter, HTTPException, Response, UploadFile, status

from app.api.deps import CurrentUser, StorageDep
from app.core.imaging import strip_exif_to_jpeg

router = APIRouter(prefix="/images", tags=["images"])


def validate_image_key(key: str) -> None:
    """경로 이탈 거절.

    ⚠️ HTTP 경로로는 사실상 도달하지 않는다 — ASGI/클라이언트가 `..`를 라우팅 전에
    정규화하기 때문이다(테스트로 확인). 그래서 **함수로 분리해 단위로 검증**한다.
    HTTP로 못 뚫린다는 이유로 가드를 빼면, key가 다른 경로(배치·관리 스크립트)로
    들어올 때 로컬 파일 어댑터에서 디렉터리 밖을 읽게 된다.
    """
    if ".." in key or key.startswith("/") or "\\" in key or key.startswith("~"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="잘못된 이미지 경로입니다."
        )


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


@router.get("/{key:path}")
def get_image(
    key: str,
    storage: StorageDep,
    _: CurrentUser,  # ⚠️ 인증 필수 — 없으면 key를 아는 누구나 고객사 재고 사진을 본다
) -> Response:
    """라벨 사진 조회 (FR4).

    key는 `labels/xxx.jpg` 형태라 `/`를 포함하므로 path 파라미터로 받는다.
    그만큼 경로 이탈을 직접 막아야 한다 — 로컬 어댑터를 쓸 때 실제로 위험하다.
    """
    validate_image_key(key)
    try:
        data = storage.get_object(key)
    except FileNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="이미지를 찾을 수 없습니다."
        ) from exc

    content_type = "image/jpeg"
    getter = getattr(storage, "get_content_type", None)
    if getter is not None:
        try:
            content_type = getter(key)
        except FileNotFoundError:
            pass

    # 같은 병을 반복 스캔하므로 캐시를 허용한다. 사진은 key마다 불변에 가깝다.
    etag = f'"{hashlib.sha256(data).hexdigest()[:32]}"'
    return Response(
        content=data,
        media_type=content_type,
        headers={"Cache-Control": "private, max-age=86400", "ETag": etag},
    )
