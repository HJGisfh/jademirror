#!/usr/bin/env python3
"""
临时调试脚本：打印AI返回的原始内容
"""
import sys
sys.path.insert(0, r'e:\Jade\jademirror\backend')

from jademirror_core.application import extract_json_object

# 模拟AI返回的内容
test_outputs = [
    # 测试1：AI返回新格式
    '{"reply": "好嘞！六问版走起～", "tool_calls": [{"name": "navigate", "args": {"route": "/test"}}, {"name": "start_guided_test", "args": {}}], "memory": [], "emotion": "excited"}',
    
    # 测试2：AI返回旧格式
    '{"reply": "好嘞！六问版走起～", "next_action": "start_test", "action_payload": {}, "memory": [], "emotion": "excited"}',
    
    # 测试3：AI只返回文本
    '好嘞！六问版走起～那咱们就正式开始啦！',
]

print("=" * 60)
print("测试 extract_json_object 函数")
print("=" * 60)

for i, output in enumerate(test_outputs, 1):
    print(f"\n测试 {i}:")
    print(f"输入: {output[:80]}...")
    parsed = extract_json_object(output)
    print(f"解析结果: {parsed}")
    print(f"tool_calls: {parsed.get('tool_calls')}")
    print(f"next_action: {parsed.get('next_action')}")
    print("-" * 60)
