"""인증 라우트 — 가입/로그인/현재 사용자 (FR1)."""
from __future__ import annotations

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm

from app.api.deps import CurrentManager, CurrentUser, SessionDep
from app.core.security import create_access_token, verify_password
from app.crud import user as user_crud
from app.models.user import UserRole
from app.schemas.user import Token, UserCreate, UserRead

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/signup", response_model=UserRead, status_code=status.HTTP_201_CREATED)
def signup(payload: UserCreate, session: SessionDep) -> UserRead:
    if user_crud.get_user_by_email(session, payload.email):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="이미 가입된 이메일입니다.",
        )
    user = user_crud.create_user(session, email=payload.email, password=payload.password)
    return UserRead.model_validate(user)


@router.post("/login", response_model=Token)
def login(
    form_data: Annotated[OAuth2PasswordRequestForm, Depends()],
    session: SessionDep,
) -> Token:
    user = user_crud.get_user_by_email(session, form_data.username)
    # 사용자 열거 방지: 이메일/비밀번호 오류를 동일 401로 처리
    if user is None or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="이메일 또는 비밀번호가 올바르지 않습니다.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return Token(access_token=create_access_token(str(user.id)))


@router.get("/me", response_model=UserRead)
def read_me(current_user: CurrentUser) -> UserRead:
    return UserRead.model_validate(current_user)


@router.post("/managers", response_model=UserRead, status_code=status.HTTP_201_CREATED)
def create_manager(
    payload: UserCreate,
    session: SessionDep,
    _: CurrentManager,  # manager만 호출 가능 (staff → 403)
) -> UserRead:
    if user_crud.get_user_by_email(session, payload.email):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="이미 가입된 이메일입니다.",
        )
    user = user_crud.create_user(
        session, email=payload.email, password=payload.password, role=UserRole.manager
    )
    return UserRead.model_validate(user)
