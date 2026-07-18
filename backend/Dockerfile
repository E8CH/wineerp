# wineerp backend — build context = backend/ (로컬 docker-compose 용).
# Railway 배포는 리포지토리 루트의 Dockerfile을 사용한다(모노레포).
FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH="/app/.venv/bin:$PATH"

# uv (빠른 의존성 설치)
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

WORKDIR /app

# 의존성만 설치(프로젝트 자체는 빌드하지 않음 — 앱이라 패키지 빌드 불필요)
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev --no-install-project

COPY . .

ENV PORT=8000
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT}"]
