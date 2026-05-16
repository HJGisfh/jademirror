# 🤖 玉灵童子 AI工具调用系统说明

## 📋 概述

玉灵童子使用智能工具调用系统，AI可以根据用户的自然语言输入，自主决定是否需要调用工具来执行操作。

---

## 🛠️ 工具列表

### 1. navigate - 页面跳转
**描述**: 跳转到指定页面

**参数**:
```javascript
{
  route: string // 目标路由
}
```

**可用路由**:
- `/home` - 首页
- `/test` - 测试页
- `/result` - 结果页
- `/chat` - 对话页
- `/generate` - 生成页
- `/gallery` - 展厅

**使用场景**:
- 用户说"去测试"
- 用户说"去展厅看看"
- 用户说"回首页"

**示例**:
```json
{
  "reply": "好嘞！带你去测试页~",
  "tool_calls": [
    {"name": "navigate", "args": {"route": "/test"}}
  ]
}
```

---

### 2. start_guided_test - 开始测试
**描述**: 开始语音引导的照心测试，AI会逐题播报问题

**参数**: 无

**使用场景**:
- 用户说"开始测试"
- 用户说"做测试"
- 用户说"测一测"

**示例**:
```json
{
  "reply": "哇，这就来了！超期待带你找到你的本命古玉！走，咱们开始测试~",
  "tool_calls": [
    {"name": "start_guided_test", "args": {}},
    {"name": "navigate", "args": {"route": "/test"}}
  ]
}
```

---

### 3. finish_test - 完成测试
**描述**: 完成测试，计算匹配结果并展示匹配的古玉

**参数**: 无

**使用场景**:
- 测试题目全部回答完毕
- 用户说"完成测试"
- 用户说"看结果"

**示例**:
```json
{
  "reply": "好的！我这就帮你计算匹配结果~",
  "tool_calls": [
    {"name": "finish_test", "args": {}}
  ]
}
```

---

### 4. generate_jade - 生成专属玉
**描述**: 根据测试结果和用户情绪生成专属玉图像

**前置条件**: 必须先完成测试

**参数**: 无

**使用场景**:
- 用户说"生成玉"
- 用户说"生成我的玉"
- 用户说"生成图片"

**示例**:
```json
{
  "reply": "我这就帮你凝练专属玉意象，稍等一下哦~",
  "tool_calls": [
    {"name": "generate_jade", "args": {}}
  ]
}
```

---

### 5. save_to_gallery - 保存到展厅
**描述**: 保存当前生成的专属玉到个人展厅

**前置条件**: 必须先生成图片

**参数**: 无

**使用场景**:
- 用户说"保存"
- 用户说"保存到展厅"
- 用户说"收藏"

**示例**:
```json
{
  "reply": "好的！帮你保存到展厅啦~",
  "tool_calls": [
    {"name": "save_to_gallery", "args": {}}
  ]
}
```

---

### 6. start_gallery_tour - 开始展厅导览
**描述**: 开始展厅语音导览，AI会逐件介绍用户收藏的作品

**参数**: 无

**使用场景**:
- 用户说"导览"
- 用户说"介绍展厅"
- 用户说"讲解作品"

**示例**:
```json
{
  "reply": "好嘞！我带你逐件欣赏你的收藏~",
  "tool_calls": [
    {"name": "start_gallery_tour", "args": {}}
  ]
}
```

---

### 7. delete_gallery_work - 删除作品
**描述**: 删除展厅中的某件作品

**参数**:
```javascript
{
  index: number // 作品序号（从1开始）
}
```

**使用场景**:
- 用户说"删除第2件"
- 用户说"删除第一个作品"

**示例**:
```json
{
  "reply": "好的，帮你删除第2件作品~",
  "tool_calls": [
    {"name": "delete_gallery_work", "args": {"index": 2}}
  ]
}
```

---

### 8. open_gallery_work - 查看作品
**描述**: 详细介绍展厅中的某件作品

**参数**:
```javascript
{
  index: number // 作品序号（从1开始）
}
```

**使用场景**:
- 用户说"看第1件"
- 用户说"介绍第3个"

**示例**:
```json
{
  "reply": "来，我给你详细介绍第1件作品~",
  "tool_calls": [
    {"name": "open_gallery_work", "args": {"index": 1}}
  ]
}
```

---

### 9. ask_clarification - 询问澄清
**描述**: 向用户询问更多信息以明确意图

**参数**:
```javascript
{
  question: string // 要问用户的问题
}
```

**使用场景**:
- 用户的请求模糊不清
- 需要更多信息才能决定

**示例**:
```json
{
  "reply": "你是想开始照心测试吗？还是想了解测试的内容？",
  "tool_calls": [
    {"name": "ask_clarification", "args": {"question": "你是想开始照心测试吗？"}}
  ]
}
```

---

### 10. none - 纯聊天
**描述**: 不执行任何工具，纯文本回复

**参数**: 无

**使用场景**:
- 用户在闲聊
- 用户问问题
- 用户聊玉文化

**示例**:
```json
{
  "reply": "哈哈这个问题问得好！古人觉得玉有五德——仁、义、智、勇、洁...",
  "tool_calls": []
}
```

---

## 🎯 AI决策流程

### 第1步：理解用户意图

```
用户输入 → AI分析 → 判断意图
```

**明确意图**:
- "开始测试" → 明确，调用 start_guided_test
- "生成我的玉" → 明确，调用 generate_jade
- "去展厅" → 明确，调用 navigate

**不明确意图**:
- "测试" → 不明确，调用 ask_clarification
- "看看" → 不明确，调用 ask_clarification

**闲聊意图**:
- "为什么古人喜欢玉" → 闲聊，调用 none
- "今天心情不好" → 闲聊，调用 none

### 第2步：检查前置条件

```
意图明确 → 检查条件 → 决定是否执行
```

**示例**:
```
用户: "生成玉"
AI检查: 是否完成测试？
- 是 → 调用 generate_jade
- 否 → 提示"需要先完成测试"，调用 ask_clarification
```

### 第3步：返回工具调用

```
决定执行 → 构造tool_calls → 返回给前端
```

**单个工具**:
```json
{
  "reply": "好的！",
  "tool_calls": [
    {"name": "generate_jade", "args": {}}
  ]
}
```

**多个工具**:
```json
{
  "reply": "好嘞！带你去测试~",
  "tool_calls": [
    {"name": "navigate", "args": {"route": "/test"}},
    {"name": "start_guided_test", "args": {}}
  ]
}
```

**无工具**:
```json
{
  "reply": "哈哈这个问题问得好！...",
  "tool_calls": []
}
```

---

## 📝 使用示例

### 示例1：开始测试（明确意图）

**用户输入**: "开始测试"

**AI分析**:
- 意图：开始测试
- 当前页面：home
- 可用工具：start_guided_test, navigate
- 决策：调用工具

**AI响应**:
```json
{
  "reply": "哇，这就来了！超期待带你找到你的本命古玉！走，咱们开始测试~",
  "tool_calls": [
    {"name": "navigate", "args": {"route": "/test"}},
    {"name": "start_guided_test", "args": {}}
  ]
}
```

**执行结果**:
1. 跳转到测试页
2. 开始语音引导测试
3. AI播报第一题

---

### 示例2：模糊请求（不明确意图）

**用户输入**: "测试"

**AI分析**:
- 意图：不明确（想开始测试？还是想了解测试？）
- 决策：询问澄清

**AI响应**:
```json
{
  "reply": "你是想开始照心测试吗？还是想先了解一下测试的内容？",
  "tool_calls": [
    {"name": "ask_clarification", "args": {"question": "你是想开始照心测试吗？"}}
  ]
}
```

**执行结果**:
- AI询问用户
- 等待用户明确回复

---

### 示例3：玉文化闲聊（闲聊意图）

**用户输入**: "为什么古人那么喜欢玉？"

**AI分析**:
- 意图：闲聊，询问玉文化知识
- 决策：纯聊天，不调用工具

**AI响应**:
```json
{
  "reply": "哈哈这个问题问得好！古人觉得玉有五德——仁、义、智、勇、洁。你看玉温润有光泽，就像君子的品德。而且玉很硬但不伤人，敲起来声音清脆悦耳，超有灵性的！",
  "tool_calls": []
}
```

**执行结果**:
- 纯文本回复
- 不执行任何操作

---

### 示例4：前置条件不满足

**用户输入**: "生成我的玉"

**AI分析**:
- 意图：生成专属玉
- 检查：是否完成测试？
- 结果：未完成测试

**AI响应**:
```json
{
  "reply": "诶，你还没做照心测试呢！得先测试一下，我才能知道哪块古玉最适合你，然后生成专属玉哦~要不咱们先做测试？",
  "tool_calls": [
    {"name": "ask_clarification", "args": {"question": "要不咱们先做测试？"}}
  ]
}
```

**执行结果**:
- 提示用户需要先完成测试
- 询问是否开始测试

---

## 🔧 技术实现

### 前端发送请求

```javascript
const data = await requestAssistantTurn({
  text: "开始测试",
  stage: "home",
  context: {
    instructions: "...",
    tool_definitions: {...},
    available_tools: ["navigate", "start_guided_test", ...],
    test: {...},
    jade: {...},
    ...
  }
})
```

### 后端AI处理

```python
# AI接收context，理解用户意图
# AI根据tool_definitions选择合适的工具
# AI返回响应

{
  "reply": "...",
  "tool_calls": [...]
}
```

### 前端执行工具

```javascript
// 执行tool_calls
for (const call of data.tool_calls) {
  await executeSingleTool(call.name, call.args, router)
}
```

---

## ⚠️ 注意事项

1. **工具顺序**: 多个工具按顺序执行
2. **前置条件**: 某些工具需要满足前置条件
3. **页面状态**: 不同页面有不同的可用工具
4. **用户确认**: 不明确时使用 ask_clarification
5. **纯聊天**: 闲聊时不调用任何工具

---

## 📊 工具可用性矩阵

| 工具 | home | test | result | chat | generate | gallery |
|------|------|------|--------|------|----------|---------|
| navigate | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| start_guided_test | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| finish_test | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| generate_jade | ❌ | ❌ | ✅ | ✅ | ✅ | ❌ |
| save_to_gallery | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ |
| start_gallery_tour | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| delete_gallery_work | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| open_gallery_work | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| ask_clarification | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| none | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

---

**更新时间**: 2026-05-07  
**版本**: v2.0 - 新增工具调用系统
