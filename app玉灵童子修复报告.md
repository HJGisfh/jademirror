# App 玉灵童子修复报告

## 修复时间
2026-05-07

## 修复目标
将 jademirror（Web版）中已修复的玉灵童子逻辑完全同步到 app（Flutter版）中，确保两个版本功能一致。

## 主要修改

### 1. 支持 tool_calls 格式（与 jademirror 对齐）

**文件**: `app/lib/providers/companion_provider.dart`

**修改内容**:
- ✅ 在 `sendTurn()` 方法中添加了对 `tool_calls` 格式的支持
- ✅ 保留了对旧 `next_action` 格式的向后兼容
- ✅ 添加了 `_executeTool()` 方法来执行单个工具调用
- ✅ 在 `_runIdleNudge()` 方法中也添加了 `tool_calls` 支持

**代码逻辑**:
```dart
// 🔥 NEW: Support tool_calls format (jademirror compatible)
if (map['tool_calls'] is List && (map['tool_calls'] as List).isNotEmpty) {
  final toolCalls = (map['tool_calls'] as List).cast<Map<String, dynamic>>();
  for (final call in toolCalls) {
    final toolName = (call['name'] as String?)?.trim() ?? '';
    final toolArgs = call['args'] is Map
        ? (call['args'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    await _executeTool(toolName, toolArgs);
  }
} 
// 🔄 BACKWARD COMPATIBILITY: Support old next_action format
else if (map['next_action'] != null) {
  // ... 旧格式处理
}
```

**支持的工具**:
- `navigate` - 页面跳转
- `start_guided_test` / `start_test` - 开始测试
- `finish_test` - 完成测试
- `generate_jade` - 生成玉图像
- `save_to_gallery` - 保存到展厅
- `start_gallery_tour` - 开始展厅导览
- `delete_gallery_work` - 删除作品
- `open_gallery_work` - 查看作品
- `record_answer` - 记录答案
- `ask_clarification` - 询问澄清
- `none` - 纯聊天

### 2. 优化欢迎消息（与 jademirror 对齐）

**文件**: `app/lib/providers/companion_provider.dart`

**修改内容**:
- ✅ 更新欢迎语，强调"AI管家"角色
- ✅ 每次登录都会播报欢迎语（与 Web 版一致）

**修改前**:
```dart
const text = '我是玉灵童子。我会一直听你说话...';
```

**修改后**:
```dart
const text = '我是玉灵童子，你的AI管家。我会一直听你说话...';
```

### 3. 添加语音识别纠错功能（与 jademirror 对齐）

**文件**: `app/lib/widgets/voice_command_bar.dart`

**修改内容**:
- ✅ 添加了 `_correctTranscript()` 方法
- ✅ 修复常见误识别：域→玉、鱼→玉
- ✅ 在 `_finalizeUtterance()` 中应用纠错

**纠错规则**:
```dart
final phraseCorrections = {
  '与域对话': '与玉对话',
  '玉域对话': '与玉对话',
  '遇域对话': '与玉对话',
  '与鱼对话': '与玉对话',
  '生成域': '生成玉',
  '生成鱼': '生成玉',
  '匹配域': '匹配玉',
  '匹配鱼': '匹配玉',
  '古域': '古玉',
  '古鱼': '古玉',
  '域灵童子': '玉灵童子',
  '鱼灵童子': '玉灵童子',
  '域器': '玉器',
  '鱼器': '玉器',
};
```

## 技术细节

### 后端兼容性
- App 使用与 jademirror 相同的后端服务器
- 后端地址: `http://150.109.235.111:5000/api`
- 后端已支持 `tool_calls` 格式（在 `jademirror/backend/jademirror_core/application.py` 中实现）

### 数据流程
1. 用户语音输入 → 语音识别
2. 识别结果 → 纠错处理
3. 纠错后文本 → 发送到后端 `/assistant/turn`
4. 后端返回 `{reply, tool_calls}` 或 `{reply, next_action}`
5. 前端执行工具调用 → 更新UI状态

### 工具执行流程
```
AI返回tool_calls数组
  ↓
遍历每个tool_call
  ↓
根据tool名称执行对应操作
  ↓
通过onNavigate回调通知UI层
  ↓
UI层响应（跳转页面、更新状态等）
```

## 与 jademirror 的对齐情况

| 功能 | jademirror (Web) | app (Flutter) | 状态 |
|------|------------------|---------------|------|
| tool_calls 格式支持 | ✅ | ✅ | 已对齐 |
| 向后兼容 next_action | ✅ | ✅ | 已对齐 |
| 语音识别纠错 | ✅ | ✅ | 已对齐 |
| AI管家角色定位 | ✅ | ✅ | 已对齐 |
| 欢迎消息播报 | ✅ | ✅ | 已对齐 |
| 工具调用执行 | ✅ | ✅ | 已对齐 |
| 空闲主动关怀 | ✅ | ✅ | 已对齐 |

## 测试建议

### 1. 基础对话测试
- [ ] 说"你好"，检查是否正常回复
- [ ] 说"与玉对话"，检查是否跳转到对话页
- [ ] 说"开始测试"，检查是否启动测试流程

### 2. 语音纠错测试
- [ ] 说"与域对话"，检查是否纠正为"与玉对话"
- [ ] 说"生成域"，检查是否纠正为"生成玉"
- [ ] 说"古域"，检查是否纠正为"古玉"

### 3. 工具调用测试
- [ ] 测试 navigate 工具（页面跳转）
- [ ] 测试 start_guided_test 工具（启动测试）
- [ ] 测试 finish_test 工具（完成测试）
- [ ] 测试 generate_jade 工具（生成图像）

### 4. 兼容性测试
- [ ] 测试新格式 tool_calls 是否正常工作
- [ ] 测试旧格式 next_action 是否仍然兼容
- [ ] 测试空闲主动关怀是否正常触发

## 注意事项

1. **后端依赖**: App 的玉灵童子功能依赖后端 API，确保后端服务正常运行
2. **网络连接**: 需要网络连接才能使用 AI 功能
3. **语音权限**: 需要麦克风权限才能使用语音输入
4. **TTS 权限**: 需要 TTS 权限才能播报语音

## 下一步优化建议

1. **增强工具定义**: 在 app 中也添加完整的工具定义和说明（类似 jademirror 的 toolDefinitions）
2. **调试日志**: 添加更详细的调试日志，方便排查问题
3. **错误处理**: 增强错误处理和用户提示
4. **离线模式**: 考虑添加离线模式，在无网络时提供基础功能

## 总结

✅ **已完成**: App 中的玉灵童子逻辑已与 jademirror 完全对齐
✅ **向后兼容**: 保留了对旧格式的支持，不会破坏现有功能
✅ **功能增强**: 添加了语音识别纠错，提升用户体验
✅ **代码质量**: 代码结构清晰，易于维护和扩展

现在 app 和 jademirror 使用相同的后端逻辑和数据格式，确保了两个平台的一致性。
