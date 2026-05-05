# 在仓库根目录构建：docker build -f deploy/Dockerfile .
FROM python:3.11-slim-bookworm

WORKDIR /app

# 部分依赖编译时需要
RUN apt-get update \
    && apt-get install -y --no-install-recommends gcc \
    && rm -rf /var/lib/apt/lists/*

# 保留 jademirror/backend 在仓库中的相对路径，供 jademirror_core.factory 解析实例目录
COPY jademirror /app/jademirror

WORKDIR /app/jademirror/backend

RUN pip install --no-cache-dir -r requirements.txt gunicorn

ENV PYTHONUNBUFFERED=1
ENV PORT=5000

EXPOSE 5000

# 单 worker：SQLite 在多进程下易锁；超时加长以覆盖千问生图
CMD ["sh", "-c", "gunicorn -w 1 -b 0.0.0.0:${PORT:-5000} --timeout 120 --access-logfile - --error-logfile - app:app"]
