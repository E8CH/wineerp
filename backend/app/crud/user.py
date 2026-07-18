"""User DB 접근 계층. 라우트는 이 crud를 통해서만 users 테이블에 접근한다."""
from __future__ import annotations

from sqlmodel import Session, select

from app.core.security import get_password_hash
from app.models.user import User, UserRole


def get_user_by_email(session: Session, email: str) -> User | None:
    return session.exec(select(User).where(User.email == email)).first()


def create_user(
    session: Session,
    *,
    email: str,
    password: str,
    role: UserRole = UserRole.staff,
) -> User:
    """평문 비밀번호를 해시해 User 생성. 평문은 저장하지 않는다."""
    user = User(email=email, hashed_password=get_password_hash(password), role=role)
    session.add(user)
    session.commit()
    session.refresh(user)
    return user
