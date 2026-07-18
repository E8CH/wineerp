#!/usr/bin/env bash
# OpenAPI → Dart 클라이언트 생성 (AC3).
# 1) 백엔드 앱에서 openapi.json 추출(서버 기동 불필요) 2) dart-dio 클라이언트 생성.
# 요구: uv, node/npx, Java 11+ (openapi-generator-cli).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "→ [1/2] OpenAPI 스키마 추출 (backend)"
cd "$ROOT/backend"
# cwd=backend 이므로 상대경로 ../openapi.json 로 저장(윈도우/유닉스 경로 변환 회피)
uv run python -c "import json,pathlib; from app.main import app; pathlib.Path('../openapi.json').write_text(json.dumps(app.openapi(), ensure_ascii=False, indent=2), encoding='utf-8')"

echo "→ [2/2] Dart 클라이언트 생성 → app/lib/data/api"
cd "$ROOT"
npx --yes @openapitools/openapi-generator-cli generate \
  -i openapi.json \
  -g dart-dio \
  -o app/lib/data/api \
  --additional-properties=pubName=wineerp_api,nullableFields=true

echo "✓ 완료: app/lib/data/api (dart-dio). 생성 코드는 analysis_options.yaml에서 분석 제외됨."
