# wineerp — Railway 배포용(모노레포). build context = 리포지토리 루트.
# 백엔드가 backend/ 서브디렉터리이므로 여기서 backend/를 복사해 빌드한다.
FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH="/app/.venv/bin:$PATH"

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

WORKDIR /app

# 의존성만 설치(락 기반, dev 제외, 프로젝트 자체 빌드 안 함)
COPY backend/pyproject.toml backend/uv.lock ./
RUN uv sync --frozen --no-dev --no-install-project

# 백엔드 소스
COPY backend/ .

ENV PORT=8000
# ⚠️ EXPOSE는 문서용이 아니다. Railway가 타깃 포트를 이걸로 감지한다 —
# 없으면 헬스체크가 엉뚱한 포트를 두드리고 "service unavailable"만 반복한다.
EXPOSE 8000
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT}"]
