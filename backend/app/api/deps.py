"""API 공통 의존성 — DB 세션, 현재 사용자(JWT)."""
from __future__ import annotations

import uuid
from typing import Annotated

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlmodel import Session

from app.adapters.label_inference import get_label_inference
from app.adapters.storage import build_storage
from app.core.config import settings
from app.core.db import get_session
from app.core.security import decode_token
from app.models.user import User, UserRole
from app.services.ports import LabelInferencePort, StoragePort

oauth2_scheme = OAuth2PasswordBearer(tokenUrl=f"{settings.API_V1_PREFIX}/auth/login")

SessionDep = Annotated[Session, Depends(get_session)]
TokenDep = Annotated[str, Depends(oauth2_scheme)]
def get_storage(session: SessionDep) -> StoragePort:
    """StoragePort 주입. DB 어댑터가 세션을 필요로 하므로 여기서 엮는다.

    테스트는 `app.dependency_overrides[get_storage]`로 로컬 어댑터를 넣는다.
    """
    return build_storage(session)


StorageDep = Annotated[StoragePort, Depends(get_storage)]
# 라우트는 팩토리만 안다 — 어댑터 구현을 직접 import하지 않는다(AR4).
LabelInferenceDep = Annotated[LabelInferencePort, Depends(get_label_inference)]

_CREDENTIALS_EXC = HTTPException(
    status_code=status.HTTP_401_UNAUTHORIZED,
    detail="인증이 필요합니다.",
    headers={"WWW-Authenticate": "Bearer"},
)


def get_current_user(session: SessionDep, token: TokenDep) -> User:
    subject = decode_token(token)
    if subject is None:
        raise _CREDENTIALS_EXC
    try:
        user_id = uuid.UUID(subject)
    except ValueError as exc:
        raise _CREDENTIALS_EXC from exc
    user = session.get(User, user_id)
    if user is None or not user.is_active:
        raise _CREDENTIALS_EXC
    return user


CurrentUser = Annotated[User, Depends(get_current_user)]


def require_manager(current_user: CurrentUser) -> User:
    """manager 전용 리소스 가드. staff면 403(권한 부족)."""
    if current_user.role != UserRole.manager:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="관리자 권한이 필요합니다.",
        )
    return current_user


CurrentManager = Annotated[User, Depends(require_manager)]
