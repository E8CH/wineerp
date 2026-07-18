# wineerp backend — Railway가 이 Dockerfile로 빌드/배포한다.
FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# uv 설치 (빠른 의존성 설치)
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

WORKDIR /app

# 의존성 먼저 (레이어 캐시)
COPY pyproject.toml ./
RUN uv pip install --system --no-cache .

COPY . .

# Railway는 $PORT 를 주입한다. 로컬 기본 8000.
ENV PORT=8000
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT}"]
