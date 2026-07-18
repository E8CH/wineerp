# wineerp backend

FastAPI + SQLModel + PostgreSQL + Alembic. 와이어 JSON=snake_case, 경로 `/api/v1`, PK=UUID.

## 레이아웃 (아키텍처 정합)
```
app/
├── main.py            FastAPI 진입점
├── core/              config(12-factor)·db(지연 초기화)·security(Story 1.3)
├── api/routes/        기능 라우트 (health; auth/scan/... 후속)
├── models/            SQLModel 엔티티 (필요 시점 스토리에서 추가)
├── crud/              DB 접근 계층
├── services/          Ports (LabelInference·WineCatalog·Storage 인터페이스)
├── adapters/          벤더 구현 (Gemini/OpenAI/LWIN/R2 — 후속)
├── tests/             pytest
└── data/lwin/         LWIN 시드 자리 (Story 2.1)
alembic/               마이그레이션 (DATABASE_URL 주입)
```

## 로컬 실행 (docker 불필요)
```bash
uv run uvicorn app.main:app --reload
uv run pytest -q          # 스모크 (health 200, DB 불필요)
uv run ruff check .       # 린트
```

## DB / 마이그레이션 (Story 1.2+)
`DATABASE_URL` 설정 후:
```bash
uv run alembic revision --autogenerate -m "..."
uv run alembic upgrade head
```
미설정 시에도 앱은 기동되고 health는 200 (DB 의존 기능만 검증 필요).

## 원칙
- 외부 벤더 직접 호출 금지 → `services/ports.py` 경유.
- 입고 기록 하드삭제 금지(soft-delete). 빈티지는 바코드에 인코딩 금지.
- LLM 페이로드에 라벨 이미지 외 데이터(PII·매입가) 금지. 시크릿은 env만.
