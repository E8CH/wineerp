"""최초 관리자 부트스트랩 — 운영자가 로컬/서버에서 직접 실행(자기참조 회피).

사용:  (backend 디렉터리에서)
    uv run python scripts/create_manager.py <email> <password>

DATABASE_URL 이 설정돼 있어야 하며, users 테이블이 마이그레이션돼 있어야 한다.
공개 API로는 self-manager 승격을 열지 않는다(보안). 이후 관리자는 POST /auth/managers 로 생성.
"""
from __future__ import annotations

import sys

from sqlmodel import Session

from app.core.db import get_engine
from app.crud import user as user_crud
from app.models.user import UserRole


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: python scripts/create_manager.py <email> <password>")
        return 2
    email, password = sys.argv[1], sys.argv[2]
    with Session(get_engine()) as session:
        if user_crud.get_user_by_email(session, email):
            print(f"[skip] 이미 존재하는 이메일: {email}")
            return 1
        user = user_crud.create_user(
            session, email=email, password=password, role=UserRole.manager
        )
        print(f"[ok] 관리자 생성됨: {user.email} (id={user.id}, role={user.role})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
