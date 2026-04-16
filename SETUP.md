# 项目初始化与环境搭建

本文档用于首次项目设置。若已有 venv 和依赖，可跳至 [QUICKSTART.md](./QUICKSTART.md)。

## 系统要求

- Windows 10+ / macOS / Linux
- Python 3.8+
- Node.js 18+
- Git（可选，仅用于版本控制）

## 后端环境搭建

### 1. 创建 Python 虚拟环境

```bash
cd backend
python -m venv .venv
```

### 2. 激活虚拟环境

**Windows:**

```bash
.venv\Scripts\activate
```

**macOS/Linux:**

```bash
source .venv/bin/activate
```

### 3. 安装依赖

```bash
pip install -r requirements.txt
```

### 4. 配置环境变量

复制 `.env.example` 到 `.env`：

```bash
copy .env.example .env
```

编辑 `.env` 并填写 API Key（可选）：

```env
PORT=5000
ALLOWED_ORIGINS=http://localhost:5173

DEEPSEEK_API_KEY=sk-xxx  # 可选
QWEN_API_KEY=xxx          # 可选
```

若不填写，后端会自动返回演示数据，前端流程仍可完整跑通。

## 前端环境搭建

### 1. 安装依赖

```bash
cd frontend
npm install
```

等待完成，建议 10-30 分钟。

### 2. 验证安装

```bash
npm run build
```

应该看到编译成功，输出到 `dist/` 目录。

## 验证环境

### 后端检查

```bash
cd backend
.venv\Scripts\activate
python -c "import flask; print(f'Flask {flask.__version__}')"
python -c "import requests; print(f'Requests {requests.__version__}')"
```

### 前端检查

```bash
cd frontend
npm list vue vue-router pinia three axios
```

应该显示所有包的版本号。

## 快速启动

参见 [QUICKSTART.md](./QUICKSTART.md)

## 常见问题

### Python 版本不对

检查 Python 版本：

```bash
python --version
```

若低于 3.8，请升级 Python。

### pip 安装缓慢

配置 pip 镜像（可选）：

```bash
pip config set global.index-url https://mirrors.aliyun.com/pypi/simple/
```

然后重试：

```bash
pip install -r requirements.txt
```

### npm 安装缓慢

配置 npm 镜像：

```bash
npm config set registry https://registry.npmmirror.com
```

然后重试：

```bash
npm install
```

### Windows 虚拟环境激活失败

若看到 `PowerShell 不允许执行脚本` 错误，运行：

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

然后重试激活。
