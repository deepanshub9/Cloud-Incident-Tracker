# syntax=docker/dockerfile:1

FROM python:3.12-slim AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /build
COPY requirements.txt .

RUN python -m venv /opt/venv \
    && /opt/venv/bin/pip install --upgrade pip \
    && /opt/venv/bin/pip install --no-cache-dir -r requirements.txt


FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH" \
    PORT=8080 \
    DB_PATH=/app/data/incidents.db

RUN groupadd --system appgroup \
    && useradd --system --gid appgroup --create-home --uid 10001 appuser

WORKDIR /app
COPY --from=builder /opt/venv /opt/venv
COPY app /app/app

RUN mkdir -p /app/data \
    && chown -R 10001:10001 /app

USER 10001:10001
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=20s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/health')"

CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "app.main:app"]
