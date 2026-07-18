# wineerp — 와인 입고/재고관리

현장 직원이 스마트폰으로 바코드·라벨을 찍으면 와인 마스터와 매칭해 모델명·빈티지를 자동으로 띄우고 수량만 입력하면 입고가 끝나는 모바일 우선 재고관리 서비스.

## 구조 (모노레포)

```
wineerp/
├── backend/   FastAPI + SQLModel + PostgreSQL + Alembic  (API, /api/v1)
├── app/       Flutter (Material 3)                        (모바일 앱)
├── scripts/   gen_client.sh|ps1                           (OpenAPI→Dart 클라이언트)
└── docker-compose.yml                                     (로컬 db+backend, 선택)
```

계획 산출물: `_bmad-output/planning-artifacts/`(PRD·아키텍처·에픽·UX·리서치).

## 빠른 시작

### 백엔드 (docker 없이 — uv)
```bash
cd backend
uv run uvicorn app.main:app --reload    # http://localhost:8000
uv run pytest -q                        # 스모크 테스트
# health: http://localhost:8000/api/v1/health
```
docker가 있으면 루트에서 `docker compose up` (db + backend).

### 앱 (Flutter)
```bash
cd app
flutter pub get
flutter run   # 안드로이드 에뮬레이터/기기
# 백엔드 주소 주입: flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

### Dart API 클라이언트 생성
```bash
bash scripts/gen_client.sh      # 또는 pwsh scripts/gen_client.ps1
# 요구: uv, node/npx, Java 11+
```

## 배포 (Railway)
`backend/`가 `Dockerfile`·`railway.json`로 배포된다. PostgreSQL은 Railway 매니지드.
헬스체크 경로 `/api/v1/health`. 환경변수는 `backend/.env.example` 참조(유료 LLM 티어 필수).

## 시크릿
`.env`는 커밋 금지(`.gitignore`). 키 이름만 `backend/.env.example`에 문서화.
⚠️ LLM 키는 반드시 Billing 활성화 유료 계정(무료 Gemini는 고객 데이터 학습·사람 검토).
"# wineerp" 
