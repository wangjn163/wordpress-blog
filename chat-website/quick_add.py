#!/usr/bin/env python3
"""
快速添加对话到待同步队列
用法: echo "用户消息" | python3 quick_add.py user
     python3 quick_add.py assistant "回复消息"
"""
import sys
import json
import os
from datetime import datetime

STATE_FILE = '/root/.openclaw/workspace/chat-website/.conversation_state.json'

def add_conversation(role, message, timestamp=None):
    """添加对话到待同步队列"""
    if timestamp is None:
        timestamp = datetime.now().strftime("%H:%M")

    # 加载状态
    if os.path.exists(STATE_FILE):
        with open(STATE_FILE, 'r') as f:
            state = json.load(f)
    else:
        state = {'last_sync': None, 'pending_conversations': []}

    # 添加新对话
    state['pending_conversations'].append({
        'role': role,
        'message': message,
        'timestamp': timestamp
    })

    # 保存状态
    with open(STATE_FILE, 'w', encoding='utf-8') as f:
        json.dump(state, f, indent=2, ensure_ascii=False)

    print(f"✅ 已添加: [{timestamp}] {role}")
    return True

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("用法: python3 quick_add.py <role> [message]")
        print("  role: user 或 assistant")
        print("  message: 对话内容（可选，如果不提供则从stdin读取）")
        sys.exit(1)

    role = sys.argv[1]

    if len(sys.argv) >= 3:
        message = sys.argv[2]
    else:
        # 从stdin读取
        message = sys.stdin.read().strip()

    if not message:
        print("❌ 错误: 消息内容为空")
        sys.exit(1)

    add_conversation(role, message)
    print("\n💡 点击网站刷新按钮即可同步")
