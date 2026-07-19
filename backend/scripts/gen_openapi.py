"""openapi.json 재생성 (AR7).

낡은 스펙은 없는 것보다 나쁘다 — 이전 스펙은 paths 2개·schemas 0개인 채로 남아
`/scan`·`/receiving`이 통째로 빠져 있었고, 그것으로 생성된 Dart 클라이언트는
"인증 불필요"라고 잘못 문서화하고 있었다.

사용: `cd backend && uv run python scripts/gen_openapi.py`
라우트를 추가·변경한 스토리는 이 스크립트를 돌리고 결과를 커밋한다.
"""
from __future__ import annotations

import json
import pathlib
import sys

# `uv run python scripts/gen_openapi.py`로 직접 실행할 때 backend/를 import 경로에 넣는다.
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))

from app.main import app  # noqa: E402

OUT = pathlib.Path(__file__).resolve().parents[2] / "openapi.json"


def main() -> None:
    spec = app.openapi()
    OUT.write_text(json.dumps(spec, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    # Windows 콘솔(cp949)에서 깨지지 않도록 ASCII만 출력한다.
    print(f"{OUT}: paths {len(spec['paths'])}, "
          f"schemas {len(spec.get('components', {}).get('schemas', {}))}")


if __name__ == "__main__":
    main()
