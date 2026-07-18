"""보안 유틸 — 비밀번호 해시(bcrypt 직접 사용) + JWT 발급/검증.

passlib는 미유지보수 + bcrypt 4.x 비호환이라 bcrypt 라이브러리를 직접 사용한다.
bcrypt는 최대 72바이트만 사용하므로 인코딩 후 절단한다(표준 관행).
"""
from __future__ import annotations

from datetime import UTC, datetime, timedelta

import bcrypt
import jwt

from app.core.config import settings

_MAX_BCRYPT_BYTES = 72
_JWT_ALGORITHM = "HS256"


def _encode(password: str) -> bytes:
    return password.encode("utf-8")[:_MAX_BCRYPT_BYTES]


def get_password_hash(password: str) -> str:
    """평문 비밀번호 → bcrypt 해시. 평문은 절대 저장하지 않는다(NFR4)."""
    return bcrypt.hashpw(_encode(password), bcrypt.gensalt()).decode("utf-8")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """평문과 저장된 해시를 대조."""
    try:
        return bcrypt.checkpw(_encode(plain_password), hashed_password.encode("utf-8"))
    except ValueError:
        return False


def create_access_token(subject: str, expires_minutes: int | None = None) -> str:
    """subject(보통 user id)로 JWT 발급. exp = now + 설정 만료시간."""
    minutes = expires_minutes or settings.ACCESS_TOKEN_EXPIRE_MINUTES
    expire = datetime.now(UTC) + timedelta(minutes=minutes)
    payload = {"sub": str(subject), "exp": expire}
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=_JWT_ALGORITHM)


def decode_token(token: str) -> str | None:
    """JWT 검증 후 subject 반환. 무효/만료면 None."""
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[_JWT_ALGORITHM])
    except jwt.PyJWTError:
        return None
    return payload.get("sub")
