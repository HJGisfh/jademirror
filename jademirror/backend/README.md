# JadeMirror Flask Backend

This Flask service proxies DeepSeek and Qwen API requests for the Vue frontend.

独立进程：**Web** 用本目录 `python app.py`（读此处 `.env`，默认 5000）；**Flutter 手机 App** 在同一目录执行 `python app_mobile.py`（读 `../mobile_backend/.env`，默认 5001，数据与配置与 Web 隔离）。共享实现在 `jademirror_core/`。

## 1) Setup

```bash
python -m venv .venv
.venv\\Scripts\\activate
pip install -r requirements.txt
copy .env.example .env
```

Fill API keys in `.env`.

## 2) Run (Web)

```bash
python app.py
```

Service defaults to `http://127.0.0.1:5000`.

## 2b) Run (Flutter 手机 API)

```bash
# Windows
copy ..\mobile_backend\.env.example ..\mobile_backend\.env
# Linux / macOS
# cp ../mobile_backend/.env.example ../mobile_backend/.env
python app_mobile.py
```

默认 `http://127.0.0.1:5001/api`；与 Vite 的 5000 进程互不干扰。

## 3) API

- `GET /api/health`
- `POST /api/deepseek/chat`
- `POST /api/qwen/image`

## 4) Request body examples

`POST /api/deepseek/chat`

```json
{
  "systemPrompt": "你是一件汉代玉佩",
  "messages": [
    { "role": "user", "content": "你看见了什么？" }
  ]
}
```

`POST /api/qwen/image`

```json
{
  "prompt": "汉代螭龙玉佩，青白色，柔和光影"
}
```

## 5) Notes

- Missing API keys will trigger built-in mock responses so the frontend can still demo end-to-end flow.
- For production deployment, disable debug mode and set strict `ALLOWED_ORIGINS`.
