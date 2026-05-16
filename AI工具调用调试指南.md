# AI工具调用调试指南

## 问题描述
AI能够正确理解用户意图并给出合适的回复（如"好嘞！六问版走起～"），但是**没有返回 tool_calls 字段**，导致前端无法执行页面跳转等操作。

## 已添加的调试日志

### 后端日志（application.py）
在 `/api/assistant/turn` 接口中添加了三处关键日志：

1. **AI原始输出**（第1316行附近）
```python
print('=' * 80)
print('🤖 AI原始输出:')
print(output)
print('=' * 80)
```

2. **解析后的JSON**
```python
print('📦 解析后的JSON:')
print(json.dumps(parsed, ensure_ascii=False, indent=2))
print('=' * 80)
```

3. **tool_calls处理逻辑**
```python
if tool_calls and isinstance(tool_calls, list):
    print('✅ 使用新格式 tool_calls:', tool_calls)
else:
    print('⚠️ 未找到 tool_calls，使用旧格式兼容')
    # 转换逻辑...
    print(f'🔄 转换旧格式: next_action={next_action}, action_payload={action_payload}')

print('📤 最终返回的 tool_calls:', tool_calls)
```

### 前端日志（assistantStore.js）
在 `sendTurn` 方法中添加了接收数据的日志：

```javascript
console.log('=' .repeat(80))
console.log('📥 前端接收到的数据:', JSON.stringify(data, null, 2))
console.log('=' .repeat(80))

if (data.tool_calls && data.tool_calls.length > 0) {
  console.log('✅ 执行 tool_calls:', data.tool_calls)
  await this.executeToolCalls(data.tool_calls, router)
} else if (data.next_action) {
  console.log('⚠️ 使用旧格式 next_action:', data.next_action)
  await this.executeSingleTool(data.next_action, data.action_payload || {}, router)
} else {
  console.log('ℹ️ 没有工具调用，纯聊天')
}
```

## 测试步骤

### 1. 启动后端服务
```bash
cd e:\Jade\jademirror\backend
python app.py
```

### 2. 启动前端服务
```bash
cd e:\Jade\jademirror\frontend
npm run dev
```

### 3. 执行测试对话
按照以下顺序测试：

**测试1：开始测试（应该询问版本）**
```
用户: "开始测试"
预期AI回复: "好嘞！咱们有两个版本：六问快速版（5分钟）和完整深度版（15分钟）。你想选哪个？"
预期tool_calls: [{"name": "ask_clarification", "args": {"question": "..."}}]
```

**测试2：选择版本（应该跳转并开始）**
```
用户: "六问快速版"
预期AI回复: "好嘞！六问版走起～那咱们就正式开始啦！"
预期tool_calls: [
  {"name": "navigate", "args": {"route": "/test"}},
  {"name": "start_guided_test", "args": {}}
]
```

**测试3：闲聊（不应该有工具调用）**
```
用户: "为什么古人喜欢玉？"
预期AI回复: 关于玉文化的知识分享
预期tool_calls: []
```

### 4. 查看日志输出

#### 后端终端应该显示：
```
================================================================================
🤖 AI原始输出:
{"reply": "好嘞！六问版走起～那咱们就正式开始啦！", "tool_calls": [...], ...}
================================================================================
📦 解析后的JSON:
{
  "reply": "好嘞！六问版走起～那咱们就正式开始啦！",
  "tool_calls": [
    {"name": "navigate", "args": {"route": "/test"}},
    {"name": "start_guided_test", "args": {}}
  ],
  ...
}
================================================================================
✅ 使用新格式 tool_calls: [{'name': 'navigate', 'args': {'route': '/test'}}, ...]
📤 最终返回的 tool_calls: [{'name': 'navigate', 'args': {'route': '/test'}}, ...]
================================================================================
```

#### 前端浏览器控制台应该显示：
```
================================================================================
📥 前端接收到的数据: {
  "reply": "好嘞！六问版走起～那咱们就正式开始啦！",
  "tool_calls": [
    {"name": "navigate", "args": {"route": "/test"}},
    {"name": "start_guided_test", "args": {}}
  ],
  ...
}
================================================================================
✅ 执行 tool_calls: [{"name": "navigate", "args": {"route": "/test"}}, ...]
```

## 可能的问题和解决方案

### 问题1：AI返回的是纯文本，没有JSON
**症状**：后端日志显示 `🤖 AI原始输出:` 是纯文本而不是JSON

**原因**：
- AI模型没有理解JSON格式要求
- temperature太高导致输出不稳定
- 系统提示词不够明确

**解决方案**：
1. 降低temperature（当前0.6，可以降到0.3-0.4）
2. 在系统提示词中更强调JSON格式
3. 增加更多示例

### 问题2：AI返回JSON但没有tool_calls字段
**症状**：`📦 解析后的JSON` 有reply但没有tool_calls

**原因**：
- AI理解了意图但没有按格式返回工具调用
- 系统提示词中的工具调用说明不够清晰

**解决方案**：
1. 在系统提示词开头就强调必须返回tool_calls
2. 每个示例都包含完整的tool_calls字段
3. 明确说明：即使是闲聊也要返回空数组 `[]`

### 问题3：AI返回tool_calls但格式错误
**症状**：`⚠️ 未找到 tool_calls，使用旧格式兼容`

**原因**：
- tool_calls不是数组类型
- tool_calls内部结构不正确

**解决方案**：
1. 检查 `extract_json_object()` 函数是否正确解析
2. 在系统提示词中明确数组格式要求
3. 添加更多格式验证

### 问题4：后端返回正确但前端没收到
**症状**：后端日志正确，但前端显示 `ℹ️ 没有工具调用，纯聊天`

**原因**：
- 网络传输问题
- 前端解析问题
- API响应格式问题

**解决方案**：
1. 检查浏览器Network标签，查看实际响应
2. 确认 `requestAssistantTurn()` 函数正确处理响应
3. 检查是否有中间件修改了响应

## 下一步行动

1. **运行测试**：按照上述测试步骤执行完整测试流程
2. **收集日志**：复制所有后端终端和前端控制台的日志
3. **分析问题**：根据日志确定问题出在哪个环节
4. **针对性修复**：根据上述解决方案进行修复

## 系统提示词关键部分

当前系统提示词已经包含：
- ✅ 明确的工具调用决策流程
- ✅ 完整的工具列表和参数说明
- ✅ 输出格式要求（JSON）
- ✅ 三个示例（明确意图、选择版本、闲聊）
- ✅ 重要规则说明

如果AI仍然不返回tool_calls，可能需要：
- 🔧 在提示词最开头就强调JSON格式
- 🔧 增加更多边界情况的示例
- 🔧 降低temperature提高稳定性
- 🔧 使用更强的模型（如果可能）

## 预期的正确流程

```
用户: "开始测试"
  ↓
后端: AI理解意图 → 返回 {"reply": "...", "tool_calls": [{"name": "ask_clarification", ...}]}
  ↓
前端: 接收数据 → 执行 ask_clarification → 显示询问消息
  ↓
用户: "六问快速版"
  ↓
后端: AI理解选择 → 返回 {"reply": "...", "tool_calls": [{"name": "navigate", ...}, {"name": "start_guided_test", ...}]}
  ↓
前端: 接收数据 → 执行 navigate → 跳转到/test → 执行 start_guided_test → 开始测试
  ↓
前端: 播报第一题
```

## 联系信息
如果问题持续存在，请提供：
1. 完整的后端终端日志
2. 完整的前端控制台日志
3. 浏览器Network标签中的API响应
4. 具体的测试对话内容
