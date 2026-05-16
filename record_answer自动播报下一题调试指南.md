# record_answer 自动播报下一题调试指南

## 问题描述
用户回答问题（如"A"）后，AI正确返回 `record_answer` 工具调用，但前端没有自动播报下一题。

## 解决方案

### 最终方案：直接播报（已实施）
不再依赖AI生成下一题的播报文本，而是直接使用 `legacyBuildQuestionGuide` 函数生成标准格式的题目播报。

**优点**：
- 可靠性高，不依赖网络请求
- 响应速度快，用户体验更好
- 避免AI可能的格式错误

**实现位置**：`assistantStore.js` 的 `sendTurn` 方法中的自动播报逻辑

```javascript
// 使用备用方案直接播报，不依赖AI
const qReply = this.legacyBuildQuestionGuide(nextQ, this.guidedQuestionIndex)
console.log(`   - 📢 直接播报下一题: ${qReply}`)
this.appendMessage('assistant', qReply)
this.speak(qReply)
```

### 备选方案：AI生成播报（已注释）
如果将来需要更自然的AI播报，可以取消注释代码中的AI播报部分。

## 预期流程
1. 用户说"A"
2. 后端返回：`{"reply": "...", "tool_calls": [{"name": "record_answer", "args": {"answer": "A"}}]}`
3. 前端执行 `record_answer` 工具：
   - 记录答案到 userStore
   - `guidedQuestionIndex` 递增（0 → 1）
4. `sendTurn` 检测到 `hasRecordAnswer = true`
5. 直接使用 `legacyBuildQuestionGuide` 生成下一题文本
6. 显示并朗读下一题

## 调试步骤

### 步骤1: 检查后端返回
查看后端日志，确认返回格式：
```
🤖 AI原始输出:{"reply": "...", "tool_calls": [{"name": "record_answer", "args": {"answer": "A"}}], ...}
```

✅ **已确认**: 后端返回格式正确

### 步骤2: 检查前端接收
打开浏览器控制台，查找：
```
📥 前端接收到的数据: {...}
```

**检查点**:
- `data.tool_calls` 是否存在？
- `data.tool_calls[0].name` 是否为 `"record_answer"`？
- `data.tool_calls[0].args.answer` 是否为 `"A"`？

### 步骤3: 检查工具执行
查找控制台日志：
```
🔧 执行工具: record_answer
   参数: {answer: "A"}
```

然后查找：
```
📝 记录测试答案
   - 答案: A
   - guidedTestActive (执行前): true
   - guidedQuestionIndex (执行前): 0
   - ✅ guidedQuestionIndex已递增: 1
```

**检查点**:
- `guidedTestActive` 是否为 `true`？
- `guidedQuestionIndex` 是否正确递增？

### 步骤4: 检查自动播报触发
查找控制台日志：
```
🔍 检查工具调用:
   - hasStartGuidedTest: false
   - hasRecordAnswer: true
   - guidedTestActive: true
   - guidedQuestionIndex: 1
```

**关键检查**:
- `hasRecordAnswer` 是否为 `true`？
- `guidedTestActive` 是否为 `true`？
- `guidedQuestionIndex` 是否已递增到 `1`？

### 步骤5: 检查下一题播报
如果步骤4都正确，应该看到：
```
📝 答案已记录，准备播报下一题
   - guidedQuestionIndex: 1
   - quickTestQuestions.length: 6
   - ✅ 还有下一题，索引: 1
   - 下一题数据: {id: "fq2", ...}
   - 📢 直接播报下一题: 第2题：...
```

## 可能的问题和解决方案

### 问题1: hasRecordAnswer 为 false
**原因**: `data.tool_calls` 中没有 `record_answer`
**解决**: 检查后端返回和前端解析

### 问题2: guidedTestActive 为 false
**原因**: 测试状态被意外重置
**解决**: 检查是否有其他地方设置了 `guidedTestActive = false`

### 问题3: guidedQuestionIndex 没有递增
**原因**: `record_answer` case 没有执行或执行失败
**解决**: 检查 `currentQ` 是否存在，`quickTestQuestions[0]` 是否有效

### 问题4: 播报没有显示
**原因**: `appendMessage` 或 `speak` 函数失败
**解决**: 检查这两个函数的实现和错误日志

## 当前状态
- ✅ 后端返回格式正确
- ✅ 添加了详细的调试日志
- ✅ 实施了直接播报方案（不依赖AI）
- ✅ 保留了AI播报方案作为备选（已注释）

## 测试步骤
1. 启动应用并登录
2. 说"开始测试"
3. 选择"六问快速版"
4. 回答第一题（如"A"）
5. 观察控制台日志和界面显示
6. 确认是否自动播报第二题

## 预期结果
用户回答"A"后，应该立即看到：
- 控制台显示完整的调试日志
- 界面显示第二题的文本
- 语音播报第二题
