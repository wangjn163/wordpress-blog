#!/usr/bin/env python3
"""
自动捕获QQ对话并维护导出列表
定期运行，自动将新对话添加到导出脚本中
"""
import os
import json
import re
from datetime import datetime, timedelta

# 存储文件路径
STATE_FILE = '/root/.openclaw/workspace/chat-website/.conversation_state.json'
EXPORT_SCRIPT = '/root/.openclaw/workspace/chat-website/export_conversations.py'

def load_state():
    """加载状态"""
    if os.path.exists(STATE_FILE):
        with open(STATE_FILE, 'r') as f:
            return json.load(f)
    return {'last_sync': None, 'conversations': []}

def save_state(state):
    """保存状态"""
    with open(STATE_FILE, 'w') as f:
        json.dump(state, f, indent=2)

def get_latest_conversations_from_logs():
    """从OpenClaw日志中提取最新的对话"""
    # 这里我们维护一个对话缓存
    state = load_state()
    return state.get('conversations', [])

def add_conversation_to_export(role, message, timestamp):
    """将对话添加到导出脚本"""
    # 读取脚本
    with open(EXPORT_SCRIPT, 'r', encoding='utf-8') as f:
        content = f.read()

    # 转义消息
    escaped_message = message.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n')

    # 构造新条目
    new_entry = f'''        {{
            'role': '{role}',
            'message': '{escaped_message}',
            'timestamp': '{timestamp}'
        }},
'''

    # 在列表结尾添加
    # 查找: 'timestamp': 'XX:XX' }\n    ]
    pattern = r"([ \t]*'timestamp':\s*'[0-9:]+'[\s\S]*?}},)\n(    ])"
    match = re.search(pattern, content)

    if match:
        insert_pos = match.end(1)
        new_content = content[:insert_pos] + '\n' + new_entry + content[insert_pos - len(match.group(2)):]

        with open(EXPORT_SCRIPT, 'w', encoding='utf-8') as f:
            f.write(new_content)

        return True
    return False

def sync_conversations_to_export():
    """同步对话到导出脚本"""
    # 从状态文件读取待同步的对话
    state = load_state()
    conversations = state.get('pending_conversations', [])

    if not conversations:
        return 0

    added_count = 0
    for conv in conversations:
        if add_conversation_to_export(conv['role'], conv['message'], conv['timestamp']):
            added_count += 1

    # 清空待同步列表
    state['pending_conversations'] = []
    state['last_sync'] = datetime.now().isoformat()
    save_state(state)

    return added_count

if __name__ == '__main__':
    print("🔄 同步对话到导出脚本...")
    count = sync_conversations_to_export()
    print(f"✅ 完成！添加了 {count} 条新对话")
