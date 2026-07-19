"""로컬 파일시스템 StoragePort 어댑터 — dev/테스트용(R2 자격 미설정 시 폴백)."""
from __future__ import annotations

from pathlib import Path


class LocalStorageAdapter:
    def __init__(self, base_dir: str | Path) -> None:
        self.base_dir = Path(base_dir)

    def put_object(self, data: bytes, key: str, content_type: str) -> str:
        path = self.base_dir / key
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        return f"local:///{key}"

    def get_object(self, key: str) -> bytes:
        path = self.base_dir / key
        if not path.is_file():
            raise FileNotFoundError(key)
        return path.read_bytes()
