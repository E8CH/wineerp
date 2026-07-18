"""와인 시드 실행 — 운영자/개발자가 DB에 시연 데이터 적재.

사용:  (backend 디렉터리에서, DATABASE_URL 설정·마이그레이션 완료 후)
    uv run python scripts/seed_wines.py

data/lwin/*.csv 가 있으면 함께 로딩(LWIN 내부 표준키).
"""
from __future__ import annotations

from pathlib import Path

from sqlmodel import Session

from app.core.db import get_engine
from app.seed.wines import load_lwin_csv, seed_demo_wines

LWIN_DIR = Path(__file__).resolve().parent.parent / "data" / "lwin"


def main() -> int:
    with Session(get_engine()) as session:
        created = seed_demo_wines(session)
        print(f"[ok] 시연 와인 시드: {created}종 생성")
        total = 0
        if LWIN_DIR.exists():
            for csv_path in sorted(LWIN_DIR.glob("*.csv")):
                n = load_lwin_csv(session, csv_path)
                total += n
                print(f"[ok] LWIN 로딩 {csv_path.name}: {n}건")
        if total == 0:
            print("[info] LWIN CSV 없음(data/lwin) — 시연 데이터만 시드됨")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
