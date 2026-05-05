# 在仓库根目录构建：docker build -f deploy/Dockerfile .
# 阶段 1：构建 Vue 静态资源，便于仅用 IP:5000 访问完整网页（同域 /api）
FROM node:20-bookworm-slim AS frontend-build
WORKDIR /src
COPY jademirror/frontend/package.json jademirror/frontend/package-lock.json ./jademirror/frontend/
RUN cd jademirror/frontend && npm ci
COPY jademirror/frontend ./jademirror/frontend
WORKDIR /src/jademirror/frontend
RUN npm run build

# 阶段 2：API + 前端 dist
FROM python:3.11-slim-bookworm

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends gcc \
    && rm -rf /var/lib/apt/lists/*

COPY jademirror /app/jademirror
COPY --from=frontend-build /src/jademirror/frontend/dist /app/jademirror/frontend/dist

WORKDIR /app/jademirror/backend

RUN pip install --no-cache-dir -r requirements.txt gunicorn

ENV PYTHONUNBUFFERED=1
ENV PORT=5000

EXPOSE 5000

CMD ["sh", "-c", "gunicorn -w 1 -b 0.0.0.0:${PORT:-5000} --timeout 120 --access-logfile - --error-logfile - app:app"]
