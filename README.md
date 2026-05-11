# 🪷 玉灵童子 - AI玉文化管家

> 一个从古玉里蹦出来的小精灵，用AI陪你探索玉文化的奥秘

[![Python](https://img.shields.io/badge/Python-3.8+-blue.svg)](https://www.python.org/)
[![Vue](https://img.shields.io/badge/Vue-3.x-green.svg)](https://vuejs.org/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## ✨ 项目简介

**玉灵童子**是一个全程由AI管家精灵主动引导的玉文化交互平台。用户无需记忆任何命令，通过自然语音即可完成心理测试、古玉匹配、玉器人格对话、专属玉生成、展厅管理等全部流程。

### 核心特性

🎤 **自然语音交互** - 说话就能操作，无需记命令  
🤖 **AI主动引导** - 智能判断意图，自动执行操作  
💬 **玉文化闲聊** - 随时聊玉文化，AI是你的玉文化专家  
🧠 **长期记忆** - 记住你的偏好和情感状态  
❤️ **情感陪伴** - 空闲时主动关怀，分享知识  
🎨 **专属玉生成** - AI生成你的专属玉图像  
🏛️ **个人展厅** - 收藏和管理你的作品  

---

## 🎯 功能演示

### 1. 语音对话
```
你: "你好"
AI: "嘿！我是玉灵童子，从古玉里蹦出来的小精灵。想不想先做个照心测试？"
```

### 2. 主动引导
```
你: "开始测试"
AI: "好嘞！我们开始照心测试。第1题：你更喜欢..."
→ 自动跳转到测试页面，逐题语音引导
```

### 3. 玉文化闲聊
```
你: "为什么古人那么喜欢玉？"
AI: "哈哈这个问题问得好！古人觉得玉有五德——仁、义、智、勇、洁..."
→ 纯聊天，不执行操作
```

### 4. 智能操作
```
你: "生成我的玉"
AI: "我这就帮你凝练专属玉意象，稍等一下哦~"
→ 自动调用图像生成API
```

---

## 🚀 快速开始

### 前置要求

- Python 3.8+
- Node.js 16+
- DeepSeek API Key（AI对话）
- 通义千问 API Key（图像生成）

### 一键启动（Windows）

1. **双击运行** `启动玉灵童子.bat`
2. **等待服务启动**（约10秒）
3. **浏览器自动打开**，开始使用！

### 手动启动

详见 [快速启动指南.md](快速启动指南.md)

---

## 📁 项目结构

```
Jade/
├── jademirror/                    # 主版本（推荐使用）✅
│   ├── frontend/                  # Vue3前端
│   │   ├── src/
│   │   │   ├── stores/           # Pinia状态管理
│   │   │   │   ├── assistantStore.js  # AI管家核心
│   │   │   │   ├── voiceStore.js      # 语音功能
│   │   │   │   └── ...
│   │   │   ├── components/       # Vue组件
│   │   │   └── views/            # 页面视图
│   │   └── package.json
│   └── backend/                   # Flask后端
│       ├── jademirror_core/
│       │   └── application.py    # 核心API
│       ├── app.py                # Web版入口
│       └── requirements.txt
│
├── jademirror_canio/              # 旧版本（参考）
│   └── ...
│
├── app/                           # Flutter移动端
│   └── ...
│
├── 启动玉灵童子.bat               # Windows启动脚本
├── 快速启动指南.md                # 详细启动教程
├── 玉灵童子修复完成报告.md        # 修复说明
└── README.md                      # 本文件
```

---

## 🎨 技术栈

### 前端
- **框架**: Vue 3 + Vite
- **状态管理**: Pinia
- **路由**: Vue Router
- **UI**: 自定义组件
- **语音**: Web Speech API

### 后端
- **框架**: Flask
- **AI**: DeepSeek API
- **图像**: 通义千问 API
- **数据库**: SQLite
- **认证**: JWT Token

### AI能力
- **对话**: DeepSeek Chat
- **图像生成**: Qwen Image
- **语音识别**: 浏览器原生API
- **语音合成**: 浏览器原生API

---

## 🔧 配置说明

### 环境变量

复制 `jademirror/backend/.env.example` 为 `.env`：

```env
# AI对话（必需）
DEEPSEEK_API_KEY=sk-your-key-here

# 图像生成（必需）
QWEN_API_KEY=sk-your-key-here

# 服务配置
PORT=5000
AUTH_REQUIRED=0
ALLOWED_ORIGINS=http://localhost:5173

# Mock模式（测试用）
DEEPSEEK_ALLOW_MOCK=0
```

### API密钥获取

- **DeepSeek**: https://platform.deepseek.com/
- **通义千问**: https://dashscope.aliyun.com/

---

## 📖 使用文档

### 完整流程

1. **照心测试** - 回答10个心理测试问题
2. **古玉匹配** - AI匹配最适合你的古玉
3. **玉器对话** - 与你的专属古玉聊天
4. **专属玉生成** - AI生成你的专属玉图像
5. **展厅收藏** - 保存和管理你的作品
6. **语音导览** - AI带你游览展厅

### AI管家能力

#### 工具调用
- `start_test` - 开始测试
- `generate_jade` - 生成专属玉
- `save_to_gallery` - 保存到展厅
- `start_gallery_tour` - 开始导览
- `navigate` - 页面跳转

#### 自由闲聊
- 玉文化知识问答
- 情感陪伴和安慰
- 主动分享冷知识
- 记住用户偏好

---

## 🐛 故障排除

### 语音不工作
1. 使用Chrome/Edge浏览器
2. 允许麦克风权限
3. 检查麦克风设备

### AI不回复
1. 检查API密钥配置
2. 查看后端日志
3. 访问 http://localhost:5000/api/health

### 图像生成失败
1. 确认通义千问API密钥
2. 检查API额度
3. 查看后端错误日志

详见 [快速启动指南.md](快速启动指南.md) 的常见问题部分。

---

## 📊 版本对比

| 特性 | jademirror（主版本） | jademirror_canio |
|------|---------------------|------------------|
| 语音功能 | ✅ 已修复 | ✅ 可用 |
| AI人设 | 🎭 活泼朋友式 | 😊 温柔正式 |
| 工具调用 | ✅ 完整 | ⚠️ 简化 |
| 推荐使用 | ✅ 是 | ❌ 否 |

---

## 🤝 贡献指南

欢迎提交Issue和Pull Request！

### 开发环境

```bash
# 克隆项目
git clone <repository-url>

# 安装依赖
cd jademirror/backend && pip install -r requirements.txt
cd ../frontend && npm install

# 启动开发服务
# 终端1
cd backend && python app.py

# 终端2
cd frontend && npm run dev
```

---

## 📄 许可证

MIT License

---

## 🙏 致谢

- DeepSeek - AI对话能力
- 通义千问 - 图像生成能力
- Vue.js - 前端框架
- Flask - 后端框架

---

## 📞 联系方式

如有问题或建议，欢迎：
- 提交 Issue
- 发送邮件
- 加入讨论组

---

**让玉灵童子陪你探索玉文化的奥秘！** 🪷✨
