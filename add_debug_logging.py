#!/usr/bin/env python3
"""
添加调试日志到 application.py
"""

file_path = r'e:\Jade\jademirror\backend\jademirror_core\application.py'

# 读取文件
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 查找并替换（在 assistant_turn 函数中）
old_code = '''    parsed = extract_json_object(output)
    reply = str(parsed.get('reply') or '').strip()
    if not reply:
        reply = f'我听见你说"{user_text}"。我们继续一步步来，我会一直陪着你。'
    next_action = normalize_next_action(parsed.get('next_action'))
    action_payload = parsed.get('action_payload') if isinstance(parsed.get('action_payload'), dict) else {}
    
    # 新格式：tool_calls 数组'''

new_code = '''    parsed = extract_json_object(output)
    
    # 调试：打印AI返回的原始内容和解析结果
    print(f"\\n{'='*60}")
    print(f"用户输入: {user_text}")
    print(f"AI原始返回: {output[:500]}")
    print(f"解析结果: {parsed}")
    print(f"tool_calls字段: {parsed.get('tool_calls')}")
    print(f"next_action字段: {parsed.get('next_action')}")
    print(f"{'='*60}\\n")
    
    reply = str(parsed.get('reply') or '').strip()
    if not reply:
        reply = f'我听见你说"{user_text}"。我们继续一步步来，我会一直陪着你。'
    next_action = normalize_next_action(parsed.get('next_action'))
    action_payload = parsed.get('action_payload') if isinstance(parsed.get('action_payload'), dict) else {}
    
    # 新格式：tool_calls 数组'''

if old_code in content:
    content = content.replace(old_code, new_code)
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("✅ 成功添加调试日志！")
else:
    print("❌ 未找到目标代码，可能已经修改过了")
    print("\n正在搜索 'parsed = extract_json_object(output)'...")
    if 'parsed = extract_json_object(output)' in content:
        print("✅ 找到了，但上下文不匹配")
        # 显示上下文
        idx = content.find('parsed = extract_json_object(output)')
        print(f"\n找到的代码片段:\n{content[idx:idx+500]}")
