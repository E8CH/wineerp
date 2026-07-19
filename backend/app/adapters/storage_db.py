"""DB StoragePort 어댑터 — 사진이 재배포를 견디게 한다 (Story 6.1).

로컬 파일 어댑터는 Railway 컨테이너가 교체될 때마다 사진을 잃는다. R2 없이도
영속성을 얻기 위해 `stored_images`에 바이트를 넣는다. 규모 근거와 한계는
`app/models/image.py` 참조.
"""
from __future__ import annotations

from sqlmodel import Session

from app.models.image import StoredImage


class DbStorageAdapter:
    def __init__(self, session: Session) -> None:
        self._session = session

    def put_object(self, data: bytes, key: str, content_type: str) -> str:
        # 같은 key 재업로드는 덮어쓴다(라벨 다시 찍기).
        existing = self._session.get(StoredImage, key)
        if existing is not None:
            existing.data = data
            existing.content_type = content_type
            existing.size = len(data)
            self._session.add(existing)
        else:
            self._session.add(
                StoredImage(
                    key=key, data=data, content_type=content_type, size=len(data)
                )
            )
        self._session.commit()
        return f"db:///{key}"

    def get_object(self, key: str) -> bytes:
        row = self._session.get(StoredImage, key)
        if row is None:
            raise FileNotFoundError(key)
        return row.data

    def get_content_type(self, key: str) -> str:
        row = self._session.get(StoredImage, key)
        if row is None:
            raise FileNotFoundError(key)
        return row.content_type
