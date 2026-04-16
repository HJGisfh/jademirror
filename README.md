# 玉镜项目完成总结

## 项目概述

**玉镜（JadeMirror）** 是一套 AI 时代的玉文化交互体验系统。用户通过心理测试与古玉相遇，可与玉器的 AI 人格对话，基于情绪与偏好生成专属玉器图像，通过长按触发动态音效，所有作品保存在个人展厅。

## 技术栈

| 层级 | 技术 | 说明 |
|------|------|------|
| **前端** | Vue 3 + Vite | 单页应用，Pinia 状态管理，vue-router 路由 |
| **3D 渲染** | Three.js | 旋转玉璧主页与光晕效果 |
| **情绪识别** | Face-api.js | 摄像头实时表情检测，可降级到手动选择 |
| **音效合成** | Web Audio API | 长按玉图触发动态合成音色 |
| **后端代理** | Flask + CORS | DeepSeek & Qwen API 转发、速率限制、重试机制 |
| **数据存储** | LocalStorage | 已生成作品本地存储 |

## 完成功能清单

### ✅ 前端主体

- [x] Vue 3 应用框架 + Pinia 三层状态管理
- [x] Vue Router 6 页面路由与导航
- [x] 古风全局样式与 UI 组件库
- [x] Three.js 3D 旋转玉璧（首页）
- [x] 心理测试五道题与欧氏距离匹配算法
- [x] 10 件代表性古玉数据库（JSON）
- [x] 匹配结果页面展示与理由生成
- [x] DeepSeek 对话界面（支持多轮对话）
- [x] Face-api.js 表情识别组件（带本地情绪手选降级）
- [x] Qwen 图像生成页面 + 动态 Prompt 构造
- [x] Web Audio 触摸音效（情绪联动参数）
- [x] LocalStorage 个人展厅 + 作品管理

### ✅ 后端服务

- [x] Flask 应用框架 + CORS 跨域配置
- [x] `/api/health` 健康检查端点
- [x] `/api/deepseek/chat` 对话转发接口 + 系统 Prompt 管理
- [x] `/api/qwen/image` 图像生成转发接口 + 异步任务轮询
- [x] 无 API Key 时自动返回演示数据（保障本地演示）
- [x] 请求超时 45s、最多重试 2 次
- [x] 简单速率限制（每 IP 每分钟 40 请求）
- [x] 环境变量管理（.env.example 模板）

### ✅ 构建与配置

- [x] Vite 项目配置 + 路由别名 (@/)
- [x] Vite 开发代理配置（`/api` → 127.0.0.1:5000）
- [x] 生产环境构建配置 + .env 隔离
- [x] 前端各类工具函数（匹配、Prompt、图片转换、Web Audio）
- [x] 依赖清单完整（vue, vue-router, pinia, three, axios, face-api.js 等）

### ✅ 文档与启动

- [x] QUICKSTART.md（快速启动指南）
- [x] SETUP.md（首次环境搭建）
- [x] DEPLOY.md（部署与联调详解）
- [x] 后端 README.md + API 说明
- [x] 前端 README.md + 路由文档
- [x] .gitignore（项目级）

## 文件结构

```
Jademirror/
├── frontend/
│   ├── src/
│   │   ├── App.vue                  # 应用 shell（导航+路由）
│   │   ├── main.js                  # 入口（Pinia+Router）
│   │   ├── style.css                # 全局古风样式
│   │   ├── router/
│   │   │   └── index.js             # 6 页路由定义
│   │   ├── stores/
│   │   │   ├── index.js             # Pinia 初始化
│   │   │   ├── userStore.js         # 用户测试结果、作品管理
│   │   │   ├── apiStore.js          # 对话、生图请求状态
│   │   │   └── audioStore.js        # Web Audio 上下文、动态音效
│   │   ├── views/
│   │   │   ├── HomeView.vue         # 3D 玉璧 + 介绍
│   │   │   ├── TestView.vue         # 心理测试
│   │   │   ├── ResultView.vue       # 匹配结果卡片
│   │   │   ├── ChatView.vue         # 对话页
│   │   │   ├── GenerateView.vue     # 生成 + 表情 + 音效
│   │   │   └── GalleryView.vue      # 展厅
│   │   ├── components/
│   │   │   ├── JadeMirrorScene.vue  # Three.js 场景
│   │   │   ├── QuestionCard.vue     # 单题卡片
│   │   │   ├── ChatBubble.vue       # 聊天气泡
│   │   │   └── EmotionCapture.vue   # 表情识别组件
│   │   ├── api/
│   │   │   ├── http.js              # Axios 实例
│   │   │   ├── jadeApi.js           # API 调用函数
│   │   │   └── jadeLibrary.js       # 古玉库加载
│   │   ├── utils/
│   │   │   ├── matching.js          # 匹配算法
│   │   │   ├── prompt.js            # Prompt 构造
│   │   │   └── image.js             # 图片转换、占位图
│   │   ├── data/
│   │   │   └── questions.js         # 测试题与情绪映射
│   │   └── assets/                  # Vue 组件资源
│   ├── public/
│   │   ├── data/
│   │   │   └── jades.json           # 10 件古玉库
│   │   ├── assets/
│   │   │   ├── jade-base.svg        # 玉器占位图
│   │   │   ├── jade-alt.svg
│   │   │   └── jade-warm.svg
│   │   └── models/                  # Face-api.js 模型位置
│   │       └── README.md
│   ├── dist/                        # 生产输出
│   ├── package.json
│   ├── vite.config.js
│   ├── .env.development
│   ├── .env.production
│   └── README.md
│
├── backend/
│   ├── app.py                       # Flask 应用主体
│   ├── .venv/                       # Python 虚拟环境
│   ├── .env.example                 # 环境变量模板
│   ├── requirements.txt             # 依赖列表
│   └── README.md
│
├── Jademirror.md                    # 项目策划方案
├── QUICKSTART.md                    # 快速启动（1-2 分钟）
├── SETUP.md                         # 首次环境安装指南
├── DEPLOY.md                        # 详细部署与联调
├── .gitignore
└── README.md (本文件)
```

## 核心流程

```
用户访问首页
    ↓
   点击"开始照心"
    ↓
心理测试（5 道题）
    ↓
计算匹配° 欧氏距离
    ↓
展示匹配的古玉 + 匹配理由
    ↓
选择进入：对话页 / 生成页
    ├→ 对话页：与玉器 AI 对话
    │   （DeepSeek API，支持多轮）
    │
    └→ 生成页：
        ├ 表情识别（Face-api.js）或手动选择情绪
        ├ 基于偏好 + 情绪生成 Prompt
        ├ 调用 Qwen 生成玉器图像
        ├ 显示生成结果
        └ 长按玉图触发 Web Audio 动态音效
            ↓
       保存至展厅（LocalStorage）
            ↓
    个人展厅：查看所有作品
```

## 本地运行

### 前置条件

- Python 3.8+ + venv 已配置，依赖已安装
- Node.js 18+ + npm

### 快速启动

**终端 1 - 后端：**

```bash
cd backend
.venv\Scripts\activate
python app.py
```

**终端 2 - 前端：**

```bash
cd frontend
npm run dev
```

打开浏览器 `http://localhost:5173`

详见 [QUICKSTART.md](./QUICKSTART.md)

## 生产部署

1. **前端**：Build → 上传 `dist/` 到 Vercel/Netlify
2. **后端**：部署到 Railway/Render，配置环境变量
3. **CORS**：在后端 `.env` 中配置前端地址

详见 [DEPLOY.md](./DEPLOY.md)

## 主要特性

✨ **多模态交互**
- 3D 玉璧视觉
- 图文心理测试
- 实时表情识别
- 触摸音效反馈

🎯 **智能匹配**
- 欧氏距离算法
- 多维度偏好分析
- 动态匹配理由生成

💬 **AI 人格对话**
- 古玉人格设定
- 多轮对话记录
- 第一人称情感表达

🎨 **动态生成**
- 情绪驱动的 Prompt 构造
- Qwen 图像生成
- 演示数据自动降级

🎵 **体感反馈**
- Web Audio 动态合成
- 情绪参数联动
- 800ms 长按触发

📱 **本地存储**
- 作品持久化
- 展厅网格浏览
- 作品详情查看

## 开发贡献指南

### 添加新页面

1. 在 `src/views/` 创建 `.vue` 文件
2. 在 `src/router/index.js` 中添加路由
3. 更新 `App.vue` 中的 `titleMap`

### 修改匹配算法

编辑 `src/utils/matching.js`：
- `DIMENSION_RULES` 控制维度权重
- `RELATED_TRAITS` 定义关联性
- `buildReason()` 生成匹配理由

### 新增古玉

编辑 `public/data/jades.json`：
- 添加玉器对象
- 设定 `traits`（匹配维度）
- 设定 `audioParams`（音效参数）
- 设定 `personality`（AI 人格 Prompt）

### 调整前端样式

全局样式在 `src/style.css`，CSS 变量定义在 `:root`：
- `--ink-*`：文字色系
- `--jade-*`：玉器色系
- `--radius-*`：圆角
- `--card-*`：卡片样式

## 性能指标

- **前端包体**：~1.5 MB (gzip ~272 KB)
- **首屏加载**：~2-3 秒（启用 Service Worker 可优化）
- **对话延迟**：取决于 DeepSeek API（通常 1-3 秒）
- **图像生成**：取决于 Qwen API（通常 15-45 秒）
- **表情识别**：~1.7 秒间隔检测一次

## 已知限制

1. **Face-api.js 模型缺失**：需手动下载放入 `public/models/`
2. **表情识别依赖摄像头**：默认降级到手动选择
3. **无云存储**：作品仅保存到 LocalStorage（单浏览器）
4. **无用户认证**：生产环境需补充登录机制

## 后续增强方向

- [ ] 云存储与跨设备同步（Firebase/Supabase）
- [ ] 用户认证系统（微信、支付宝 OAuth）
- [ ] 作品分享与社区评赞
- [ ] 多语言支持（英文、日文）
- [ ] 移动端 App（Vue Native 或 React Native）
- [ ] 古玉库扩充（超过 100 件）
- [ ] 高级 AI 对话与学习
- [ ] 有声朗读功能

## 相关资源

- Vue 3 文档：https://vuejs.org/
- Three.js 文档：https://threejs.org/docs/
- DeepSeek API：https://platform.deepseek.com/
- Qwen Image：https://dashscope.aliyun.com/

## 许可

本项目为学生创意项目，仅供学习与展示使用。

---

**项目完成时间**：2026 年 4 月
**最后更新**：2026 年 4 月 16 日
