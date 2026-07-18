"""SQLModel 엔티티 등록 지점.

여기서 import된 모델은 SQLModel.metadata에 등록되어 Alembic autogenerate가 인식한다.
스키마는 필요 시점 스토리에서 추가:
  user (Story 1.2) · wine_product/wine_vintage/barcode (Story 2.1) · receiving_record (Story 2.6)
"""
from app.models.user import User, UserRole

__all__ = ["User", "UserRole"]
