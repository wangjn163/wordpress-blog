#!/usr/bin/env python3
"""
添加测试对话到今天的列表
"""
import json
from datetime import datetime, date

# 读取当前的对话数据
json_file = '/root/.openclaw/workspace/chat-website/data/conversations.json'
with open(json_file, 'r', encoding='utf-8') as f:
    data = json.load(f)

# 添加一条新的测试对话（当前时间）
now = datetime.now()
new_conversation = {
    'role': 'user',
    'message': f'这是一条测试同步的消息 - 时间: {now.strftime("%H:%M:%S")}',
    'timestamp': now.strftime("%H:%M")
}

# 添加到对话列表
data['conversations'].append(new_conversation)
data['export_time'] = now.strftime('%Y-%m-%d %H:%M:%S')

# 保存
with open(json_file, 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print(f"✅ 已添加测试对话: {new_conversation['message']}")
print(f"当前对话总数: {len(data['conversations'])}")
