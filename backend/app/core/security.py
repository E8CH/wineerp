"""보안 유틸 — 비밀번호 해시(bcrypt 직접 사용). JWT 발급/검증은 Story 1.3에서 추가.

passlib는 미유지보수 + bcrypt 4.x 비호환이라 bcrypt 라이브러리를 직접 사용한다.
bcrypt는 최대 72바이트만 사용하므로 인코딩 후 절단한다(표준 관행).
"""
from __future__ import annotations

import bcrypt

_MAX_BCRYPT_BYTES = 72


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
