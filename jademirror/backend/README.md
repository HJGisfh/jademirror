# JadeMirror Flask Backend

This Flask service proxies DeepSeek and Qwen API requests for the Vue frontend.

独立进程：**Web** 用本目录 `python app.py`（读此处 `.env`，默认 5000）；**Flutter 手机 App** 使用仓库 `app/backend/` 的后端（默认 5001，数据与配置与本目录隔离）。共享实现在 `jademirror_core/`。

## 1) Setup

```bash
python -m venv .venv
.venv\\Scripts\\activate
pip install -r requirements.txt
copy .env.example .env
```

Fill API keys in `.env`.

## 2) Run

```bash
python app.py
```

Service defaults to `http://127.0.0.1:5000`.

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
