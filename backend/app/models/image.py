"""라벨 사진 저장 (FR4).

⚠️ 아키텍처 안티패턴에 "이미지 base64 DB 저장"이 있으나 여기서는 **base64가 아니라
`LargeBinary`(bytea)**로 넣는다. 그 항목이 경계한 33% 용량 낭비가 없다.

DB에 두는 이유: 사진은 **와인 1종당 1장**(`WineVintage.representative_image_key`)이라
마스터 1,000종 × ~300KB ≈ 300MB로 유계다. 벤더·자격증명·실패 모드가 늘지 않고
백업에 사진이 함께 담긴다(5년 보존 원장에 유리).

⚠️ 이 판단이 무너지는 조건: **입고 건별** 사진을 저장하기 시작하면(하루 100건 × 5년
= 18만 장) DB는 부적절해진다. 그때는 `StoragePort` 뒤에서 R2 어댑터로 교체한다.
"""
from __future__ import annotations

from datetime import UTC, datetime

from sqlalchemy import Column, DateTime, LargeBinary
from sqlmodel import Field, SQLModel


def _utcnow() -> datetime:
    return datetime.now(UTC)


class StoredImage(SQLModel, table=True):
    __tablename__ = "stored_images"

    key: str = Field(primary_key=True, max_length=512)
    content_type: str = Field(default="image/jpeg", nullable=False)
    data: bytes = Field(sa_column=Column(LargeBinary, nullable=False))
    size: int = Field(nullable=False)
    created_at: datetime = Field(
        default_factory=_utcnow,
        sa_column=Column(DateTime(timezone=True), nullable=False),
    )
