# TestView监听testMode修复

## 修复时间
2026年5月7日

## 问题描述
用户反馈：AI已经正确返回了`start_guided_test`工具调用，后端日志显示：
```json
{
  "reply": "好嘞！六问版走起～那咱们就正式开始啦！",
  "tool_calls": [
    {"name": "start_guided_test", "args": {"mode": "quick"}}
  ],
  "memory": ["用户选择六问版测试"]
}
```

但是**页面没有显示测试题目**，用户仍然停留在选择模式的界面。

## 根本原因分析

### 问题1：TestView不监听userStore.testMode的变化

**TestView.vue的代码：**
```javascript
const testMode = ref(userStore.testMode || '')
```

这行代码只在组件创建时读取一次`userStore.testMode`，之后即使`userStore.testMode`改变了，TestView的`testMode` ref也不会更新。

### 问题2：用户已经在/test页面

当用户在主页说"开始测试"后，可能已经手动点击进入了`/test`页面，此时：
1. TestView已经加载，`testMode = ''`（空字符串）
2. 用户说"六问快速版"
3. assistantStore调用`userStore.setTestMode('quick')`
4. 但TestView的`testMode` ref仍然是空字符串
5. 所以页面仍然显示"请选择测试模式"

### 问题3：之前的跳转逻辑有问题

```javascript
if (this.stage !== 'test' && this.autoGuide && router) {
  await router.push('/test')
}
```

这个逻辑只在**不在测试页时**才跳转，如果用户已经在测试页，就不会跳转，也就不会触发TestView重新加载。

## 解决方案

### 方案：在TestView中添加watch监听userStore.testMode

**修改位置**：`e:\Jade\jademirror\frontend\src\views\TestView.vue`

**添加watch：**
```javascript
const testMode = ref(userStore.testMode || '')
const modeSelected = computed(() => !!testMode.value)

// 监听userStore.testMode的变化，同步到本地testMode
watch(
  () => userStore.testMode,
  (newMode) => {
    if (newMode && newMode !== testMode.value) {
      console.log(`📢 TestView检测到testMode变化: ${testMode.value} → ${newMode}`)
      testMode.value = newMode
      // 清空之前的答案
      for (const key of Object.keys(answers)) {
        delete answers[key]
      }
      currentIndex.value = 0
      errorText.value = ''
    }
  },
  { immediate: false }
)
```

**工作原理：**
1. 监听`userStore.testMode`的变化
2. 当检测到变化时，更新本地的`testMode` ref
3. 清空之前的答案（如果有）
4. 重置题目索引和错误信息
5. 触发Vue的响应式更新，页面自动显示测试题目

### 简化assistantStore的逻辑

**修改位置**：`e:\Jade\jademirror\frontend\src\stores\assistantStore.js`

**简化后的代码：**
```javascript
case 'start_guided_test':
  console.log(`🎯 启动引导测试`)
  const mode = args.mode || 'quick'
  console.log(`   - 测试模式: ${mode}`)
  
  // 设置测试模式
  const userStore = useUserStore()
  userStore.setTestMode(mode)
  console.log(`   - 已设置testMode: ${userStore.testMode}`)
  
  // 激活引导测试
  this.guidedTestActive = true
  this.guidedQuestionIndex = 0
  
  // 如果不在测试页，跳转过去
  if (this.stage !== 'test' && this.autoGuide && router) {
    console.log(`   - 🚀 跳转到 /test`)
    await router.push('/test')
    console.log(`   - ✅ 已跳转到测试页`)
  } else {
    console.log(`   - 已在测试页，TestView会自动检测testMode变化`)
  }
  break
```

**关键改进：**
- 不再需要强制刷新页面
- 不再需要先跳到首页再跳回来
- TestView会自动检测testMode变化并更新

## 完整流程

### 场景1：从主页开始测试

```
用户在主页说: "开始测试"
  ↓
AI: "好嘞！咱们有两个版本：六问快速版（5分钟）和完整深度版（15分钟）。你想选哪个？"
tool_calls: []
  ↓
用户: "六问快速版"
  ↓
AI: "好嘞！六问版走起～那咱们就正式开始啦！"
tool_calls: [{"name": "start_guided_test", "args": {"mode": "quick"}}]
  ↓
前端执行:
  1. userStore.setTestMode('quick')
  2. guidedTestActive = true
  3. stage !== 'test' → router.push('/test')
  4. TestView加载，testMode = 'quick'
  5. 显示六问版测试题目
  6. 自动播报第1题
```

### 场景2：已在测试页，选择版本

```
用户已在 /test 页面
TestView已加载，testMode = ''（空字符串）
显示"请选择测试模式"
  ↓
用户说: "开始测试"
  ↓
AI: "好嘞！咱们有两个版本：六问快速版（5分钟）和完整深度版（15分钟）。你想选哪个？"
tool_calls: []
  ↓
用户: "六问快速版"
  ↓
AI: "好嘞！六问版走起～那咱们就正式开始啦！"
tool_calls: [{"name": "start_guided_test", "args": {"mode": "quick"}}]
  ↓
前端执行:
  1. userStore.setTestMode('quick')  ← userStore.testMode变化
  2. guidedTestActive = true
  3. stage === 'test' → 不跳转
  4. TestView的watch检测到userStore.testMode变化  ← 关键！
  5. testMode.value = 'quick'  ← 更新本地testMode
  6. 清空答案，重置索引
  7. 显示六问版测试题目  ← 自动更新！
  8. 自动播报第1题
```

## 预期日志输出

### 后端日志
```
🤖 AI原始输出:
{"reply": "好嘞！六问版走起～那咱们就正式开始啦！", "tool_calls": [{"name": "start_guided_test", "args": {"mode": "quick"}}], "memory": ["用户选择六问版测试"]}

📦 解析后的JSON:
{
  "reply": "好嘞！六问版走起～那咱们就正式开始啦！",
  "tool_calls": [
    {"name": "start_guided_test", "args": {"mode": "quick"}}
  ],
  "memory": ["用户选择六问版测试"]
}

✅ 使用新格式 tool_calls: [{'name': 'start_guided_test', 'args': {'mode': 'quick'}}]
📤 最终返回的 tool_calls: [{'name': 'start_guided_test', 'args': {'mode': 'quick'}}]
```

### 前端控制台日志
```
📥 前端接收到的数据: {...}
✅ 执行 tool_calls: [{"name": "start_guided_test", "args": {"mode": "quick"}}]
🎬 开始执行工具调用列表: [...]

📌 准备执行工具 #1: start_guided_test
🔧 执行工具: start_guided_test
   参数: {mode: "quick"}
🎯 启动引导测试
   - 测试模式: quick (六问版)
   - 已设置testMode: quick
   - guidedTestActive: true
   - guidedQuestionIndex: 0
   - 已在测试页，TestView会自动检测testMode变化
✅ 所有工具执行完毕

📢 TestView检测到testMode变化:  → quick  ← TestView的watch触发
🎯 测试刚启动，准备播报第一题
```

## 修改的文件

1. **e:\Jade\jademirror\frontend\src\views\TestView.vue**
   - 添加watch监听userStore.testMode的变化
   - 当testMode变化时，自动更新本地testMode ref
   - 清空答案并重置状态

2. **e:\Jade\jademirror\frontend\src\stores\assistantStore.js**
   - 简化start_guided_test的跳转逻辑
   - 不再需要强制刷新页面

3. **e:\Jade\TestView监听testMode修复.md**（本文件）
   - 详细的问题分析和解决方案

## 关键改进

### 1. 响应式更新
- TestView现在能够响应userStore.testMode的变化
- 不需要重新加载页面
- 不需要强制跳转

### 2. 更好的用户体验
- 用户在任何页面说"六问快速版"都能正确开始测试
- 页面自动更新，无需刷新
- 流畅的过渡

### 3. 更简洁的代码
- 不需要复杂的跳转逻辑
- 利用Vue的响应式系统
- 更容易维护

## 测试验证

### 测试1：从主页开始
```
1. 在主页
2. 说"开始测试"
3. 说"六问快速版"
4. 预期：跳转到/test，显示6道题，自动播报第1题
```

### 测试2：已在测试页
```
1. 手动进入/test页面
2. 看到"请选择测试模式"
3. 说"开始测试"
4. 说"六问快速版"
5. 预期：页面自动更新，显示6道题，自动播报第1题
```

### 测试3：切换版本
```
1. 在测试页，已选择六问版
2. 说"开始测试"
3. 说"完整深度版"
4. 预期：页面自动切换到完整版，清空之前的答案，显示完整版题目
```

## 总结

本次修复解决了TestView不响应userStore.testMode变化的问题：

- ✅ 添加watch监听userStore.testMode
- ✅ 自动更新本地testMode ref
- ✅ 触发Vue响应式更新
- ✅ 页面自动显示测试题目
- ✅ 无需强制刷新或跳转
- ✅ 更好的用户体验

现在无论用户在哪个页面，说"六问快速版"后都能正确开始测试！

---

**修复完成时间**：2026年5月7日  
**修复人员**：Kiro AI Assistant  
**测试状态**：待用户测试验证
