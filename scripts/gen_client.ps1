# OpenAPI → Dart 클라이언트 생성 (AC3) — Windows PowerShell.
# 요구: uv, node/npx, Java 11+.
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot

Write-Host "-> [1/2] OpenAPI 스키마 추출 (backend)"
Push-Location "$Root\backend"
uv run python -c "import json,pathlib; from app.main import app; pathlib.Path(r'$Root\openapi.json').write_text(json.dumps(app.openapi(), ensure_ascii=False, indent=2), encoding='utf-8')"
Pop-Location

Write-Host "-> [2/2] Dart 클라이언트 생성 -> app/lib/data/api"
Push-Location $Root
npx --yes '@openapitools/openapi-generator-cli' generate `
  -i openapi.json -g dart-dio -o app/lib/data/api `
  --additional-properties=pubName=wineerp_api,nullableFields=true
Pop-Location

Write-Host "완료: app/lib/data/api"
