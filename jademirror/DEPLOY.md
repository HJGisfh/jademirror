# JadeMirror 部署与联调指南

## 0. 项目结构

```
Jademirror/
├── frontend/              # Vue3 + Vite 前端
│   ├── src/
│   ├── public/
│   ├── package.json
│   ├── vite.config.js
│   ├── .env.development  # 开发环境变量
│   ├── .env.production   # 生产环境变量
│   └── README.md
├── backend/               # Flask 代理服务
│   ├── app.py
│   ├── requirements.txt
│   ├── .env.example
│   ├── .venv/            # Python 虚拟环境
│   └── README.md
├── Jademirror.md         # 项目概述
├── frontend-tasks.md
├── backend-task.md
└── DEPLOY.md
```

## 1. 本地开发环境

### 1.1 后端设置

```bash
cd backend
.venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env
```

编辑 `.env` 填写 API Key(可选，无 Key 时将使用演示数据)：

```env
PORT=5000
DEEPSEEK_API_KEY=your-key-here
QWEN_API_KEY=your-key-here
```

### 1.2 前端设置

```bash
cd frontend
npm install
```

`.env.development` 已预配置代理到 `http://127.0.0.1:5000`。

## 2. 本地运行

### 方式一：分离终端（推荐开发用）

**终端 1 - 后端：**

```bash
cd backend
.venv\Scripts\activate
python app.py
```

输出应显示：`Running on http://127.0.0.1:5000`

**终端 2 - 前端：**

```bash
cd frontend
npm run dev
```

输出应显示：`Local: http://localhost:5173`

然后在浏览器中打开 `http://localhost:5173`，前端会自动代理 `/api` 请求到后端。

### 方式二：一键启动脚本

在项目根目录创建 `run.ps1`：

```powershell
$backend = @'
cd backend
.\.venv\Scripts\activate
python app.py
'@

$frontend = @'
cd frontend
npm run dev
'@

# 启动后端
Start-Process powershell -ArgumentList "-NoExit", "-Command", $backend

# 等待后端启动
Start-Sleep -Seconds 2

# 启动前端
Start-Process powershell -ArgumentList "-NoExit", "-Command", $frontend

Write-Host "Backend 运行于 http://127.0.0.1:5000"
Write-Host "Frontend 运行于 http://localhost:5173"
```

然后运行：

```powershell
.\run.ps1
```

## 3. API 接口说明

### 后端地址

- 开发：`http://127.0.0.1:5000`（自动由前端 Vite 代理）
- 生产：由部署平台决定

### 健康检查

```bash
curl http://127.0.0.1:5000/api/health
```

响应示例：

```json
{
  "status": "ok",
  "service": "jademirror-flask-proxy",
  "deepseek_configured": false,
  "qwen_configured": false
}
```

### DeepSeek 对话接口

**请求：** `POST /api/deepseek/chat`

```json
{
  "systemPrompt": "你是一件汉代玉佩。",
  "messages": [
    { "role": "user", "content": "你看见了什么？" }
  ]
}
```

**响应（无 Key 时为演示数据）：**

```json
{
  "content": "我听见你提到\"你看见了什么？\"。若心有波澜...",
  "mock": true
}
```

### Qwen 图像生成接口

**请求：** `POST /api/qwen/image`

```json
{
  "prompt": "汉代螭龙玉佩，青白色，温润如脂，古玉风格"
}
```

**响应（无 Key 时为 SVG 占位图）：**

```json
{
  "image_url": "data:image/svg+xml;charset=utf-8,%3Csvg...",
  "mock": true
}
```

## 4. 前端关键页面流程

1. **首页** (`/`) - Three.js 3D 玉璧 + 开始照心按钮
2. **心理测试** (`/test`) - 5 道题选择 → 计算匹配度
3. **匹配结果** (`/result`) - 展示匹配的古玉 + 理由
4. **对话页** (`/chat`) - 与玉器对话（调用 DeepSeek）
5. **生成页** (`/generate`) - 表情识别 + 图像生成（调用 Qwen）
6. **展厅** (`/gallery`) - LocalStorage 作品筛选与展示

## 5. 生产部署

### 5.1 前端部署（Vercel / Netlify）

1. 构建静态资源：

```bash
cd frontend
npm run build
```

输出到 `frontend/dist/`

2. 部署 `dist/` 文件夹到 Vercel/Netlify
3. 设置环境变量（如需代理到生产后端）：

```
VITE_API_BASE_URL=/api
```

4. 配置 Vercel `vercel.json` 或 Netlify `_redirects` 将 `/api/*` 转发到真实后端 URL

### 5.2 后端部署（Railway / Render / 阿里云函数）

**以 Railway 为例：**

1. 连接 GitHub repo
2. 选择 Python 运行时
3. 设置启动命令：

```
python app.py
```

4. 设置环境变量（在 Railway 面板）：

```
PORT=5000
DEEPSEEK_API_KEY=sk-xxx
QWEN_API_KEY=xxx
ALLOWED_ORIGINS=https://your-frontend-domain.com
```

5. 部署完成后获得公网 URL（如 `https://xxx-prod.railway.app`）

### 5.3 前端配置生产后端

前端部署平台的构建命令前，改 Vercel/Netlify 的环境变量：

```
VITE_API_BASE_URL=https://xxx-prod.railway.app/api
```

或在部署平台的重写规则中配置 `/api` 反向代理。

## 6. 常见问题

### Q: 前端无法连接后端

**检查清单：**

1. 后端是否启动？`curl http://127.0.0.1:5000/api/health`
2. Vite 代理配置是否正确？确认 `vite.config.js` 中 `server.proxy` 指向正确的后端地址
3. CORS 是否放通？后端 `.env` 中 `ALLOWED_ORIGINS` 是否包含前端 URL

### Q: 无法加载表情识别模型

Face-api.js 需要模型文件在 `frontend/public/models/` 下。若缺失，表情识别会自动降级到手动选择情绪。

### Q: 生成图像返回演示 SVG

后端未配置 Qwen API Key，或网络无法连接阿里云。检查 `.env` 中 `QWEN_API_KEY` 是否正确。

### Q: 对话回复内容为演示文本

同上，检查 `DEEPSEEK_API_KEY`。

## 7. 本地调试技巧

### 查看前端请求日志

在浏览器开发者工具 → Network 标签，过滤 `/api` 请求，查看请求/响应内容。

### 查看后端日志

Flask 在终端输出所有请求，包括状态码和耗时。

### 模拟表情识别

在 Generate 页面的表情识别组件中，选择"手动选择情绪"的按钮，无需摄像头即可模拟不同情绪。

### 测试长按音效

在生成的玉图上长按鼠标 800ms，会触发 Web Audio API 合成的动态音色。

## 8. 性能优化建议

- **前端**：
  - Three.js 场景：仅在 HomeView 中初始化，切换页面时销毁
  - Face-api.js：条件检测，无摄像头权限时跳过加载

- **后端**：
  - 请求超时 45 秒（可调）
  - 簡单速率限制：每分钟 40 请求/IP
  - 重试机制：API 失败时最多重试 2 次

## 9. 安全提示

- 不向前端暴露 API Key，使用后端代理
- 生产环境：禁用 Flask debug 模式，改为 gunicorn/uwsgi
- 使用 HTTPS，设置安全的 CORS 策略
- Rate limit 可根据实际情况调整
