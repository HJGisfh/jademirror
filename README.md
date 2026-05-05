# JadeMirror 仓库结构

本仓库分为两块，避免 Web 与移动端混在同一目录里：

| 目录 | 内容 |
|------|------|
| **`app/`** | Flutter 手机应用（仅客户端代码，不含 Python 后端）。 |
| **`jademirror/`** | Web 与 API：`frontend/`（Vue + Vite）、`backend/`（Flask + `jademirror_core`）、`mobile_backend/`（手机专用 `.env` 与运行时数据，与 Web 的 `backend/.env` 分离）。 |
| **`deploy/`** | Docker 部署说明与 `Dockerfile` / `docker-compose.yml`。 |

Web 开发、后端与手机端 API 进程说明见 **`jademirror/README.md`** 与 **`jademirror/backend/README.md`**。
