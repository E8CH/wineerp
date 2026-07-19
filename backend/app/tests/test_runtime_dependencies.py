"""프로덕션 빌드가 깨지는 의존성 실수를 로컬에서 잡는다.

배경(2026-07-19): `httpx`가 dev 그룹에만 선언돼 있었는데 `app/adapters/label_inference.py`가
런타임에 import했다. 로컬은 dev 의존성이 설치돼 있어 **130개 테스트가 전부 통과**했고,
프로덕션 이미지는 `uv sync --no-dev`로 빌드되어 컨테이너가 부팅하자마자
`ModuleNotFoundError`로 죽었다. 배포해 보기 전에는 드러나지 않는 종류의 결함이다.

이 테스트는 앱 코드(테스트 제외)가 import하는 서드파티 모듈이 **dev 그룹에만** 있는
경우를 잡는다. 전체 의존성 위생(직접 import는 전부 명시)까지 요구하지는 않는다 —
프로덕션을 부팅 불가로 만드는 경우만 막는 것이 목적이다.
"""
from __future__ import annotations

import ast
import pathlib
import sys
import tomllib
from importlib.metadata import packages_distributions

BACKEND_ROOT = pathlib.Path(__file__).resolve().parents[2]
APP_DIR = BACKEND_ROOT / "app"

# 표준 라이브러리·자체 패키지는 의존성 검사 대상이 아니다.
_LOCAL_ROOTS = {"app"}


def _declared() -> tuple[set[str], set[str]]:
    data = tomllib.loads((BACKEND_ROOT / "pyproject.toml").read_text(encoding="utf-8"))

    def _names(specs: list[str]) -> set[str]:
        out = set()
        for spec in specs:
            name = spec.split("[")[0]
            for sep in (">=", "==", "<=", "~=", ">", "<", "!="):
                name = name.split(sep)[0]
            out.add(name.strip().lower().replace("_", "-"))
        return out

    runtime = _names(data["project"]["dependencies"])
    dev = _names(data.get("dependency-groups", {}).get("dev", []))
    return runtime, dev


def _imported_top_level_modules() -> set[str]:
    modules: set[str] = set()
    for path in APP_DIR.rglob("*.py"):
        if "tests" in path.parts:
            continue
        tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                for alias in node.names:
                    modules.add(alias.name.split(".")[0])
            elif isinstance(node, ast.ImportFrom):
                if node.level == 0 and node.module:
                    modules.add(node.module.split(".")[0])
    return {
        m
        for m in modules
        if m not in _LOCAL_ROOTS and m not in sys.stdlib_module_names
    }


def test_app_imports_are_not_dev_only_dependencies():
    """앱이 import하는 모듈이 dev 그룹에만 있으면 프로덕션이 부팅하지 못한다."""
    runtime, dev = _declared()
    provided_by = packages_distributions()

    offenders = []
    for module in sorted(_imported_top_level_modules()):
        dists = {d.lower().replace("_", "-") for d in provided_by.get(module, [])}
        if not dists:
            continue  # 설치 경로를 못 찾으면 판단하지 않는다(오탐 방지)
        if dists & runtime:
            continue  # 런타임 의존성이 제공 — 정상
        if dists & dev:
            offenders.append(f"{module} (제공: {sorted(dists)}) — dev 그룹에만 선언됨")

    assert not offenders, (
        "다음 모듈은 앱 런타임에서 import되지만 dev 의존성에만 있습니다. "
        "`uv sync --no-dev`로 빌드되는 프로덕션 이미지가 부팅하지 못합니다:\n  "
        + "\n  ".join(offenders)
    )
