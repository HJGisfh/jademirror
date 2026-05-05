# 玉镜快速启动

## 前置条件

- Python 3.8+ 环境与 venv 已建好，依赖已安装
- Node.js 18+ 与 npm

## 一键启动（PowerShell）

### 1. 启动后端（终端 1）

```powershell
cd backend
.\.venv\Scripts\activate
python app.py
```

看到以下输出表示启动成功：

```
Running on http://127.0.0.1:5000
```

### 2. 启动前端（新终端）

```powershell
cd frontend
npm run dev
```

看到以下输出表示启动成功：

```
Local: http://localhost:5173
```

### 3. 打开浏览器

跳转到 `http://localhost:5173`

## 完整体验流程

1. **首页** → 点击"开始照心"
2. **心理测试** → 选择 5 道题，提交匹配
3. **匹配结果** → 查看推荐的古玉
4. **对话页** → 输入问题与玉器交流（无 API Key 时为演示回复）
5. **生成页** → 
   - 可选：开启摄像头检测情绪（推荐手动选择）
   - 点击"生成专属玉"（无 API Key 时为占位 SVG）
   - 统一 3D 器型展示；不同玉通过纹理与颜色区分，鼠标拖拽可旋转朝向
   - 触碰玉体触发约 6 秒旋律，长按 800ms 触发延展旋律
6. **保存→展厅** → 保存作品并在展厅查看

## 语音功能（Edge 推荐）

- 对话页支持“语音输入”：点击“语音输入”后说话，识别文本会自动填入输入框。
- 对话页支持“按住说话”：按住按钮开始聆听，松开后自动结束并回填识别文本。
- AI 回复支持“自动播报”：可在对话页切换自动播报，也可手动点击“重播玉音”。
- 聆听中会显示动态波形反馈，便于确认录音状态。
- 首次使用语音时，浏览器会请求麦克风权限，请选择“允许”。

## 配置 API Key（可选）

若要使用实际的 DeepSeek 和 Qwen API（而非演示数据）：

### 后端 `.env` 配置

编辑 `backend/.env`：

```env
PORT=5000
DEEPSEEK_API_KEY=your-deepseek-key
QWEN_API_KEY=your-qwen-key
```

保存后重启 Flask。

### 获取 API Key

- **DeepSeek**：https://platform.deepseek.com/api_keys
- **Qwen (阿里云百炼)**：https://bailian.console.aliyun.com/

## 常见命令

| 命令 | 说明 |
|------|------|
| `npm run build` | 构建前端生产包到 `frontend/dist/` |
| `npm run preview` | 本地预览生产构建结果 |
| `pip install -r requirements.txt` | 安装后端依赖（首次或更新后）|

## 故障排查

| 问题 | 解决方案 |
|------|----------|
| 前端无法连接后端 API | 确认后端已启动，检查 Vite 代理配置 |
| 摄像头权限被拒 | 允许浏览器访问摄像头，或手动选择情绪 |
| 生成图像为 SVG 占位图 | 正常（未配置 Qwen Key）；或检查网络连接 |
| 音效无声 | 确认浏览器允许自动播放；或改用手动点击 |
| 语音输入不可用 | 优先使用 Edge；确认已允许麦克风权限，并使用 https 或 localhost 访问 |
| AI 无语音播报 | 检查系统音量与页面静音状态，点击“重播玉音”手动触发 |

## 下一步

- 详见 [DEPLOY.md](./DEPLOY.md) 了解部署流程
- 详见 [Jademirror.md](./Jademirror.md) 了解项目架构与创意设计
