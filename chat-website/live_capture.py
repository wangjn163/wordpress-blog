#!/usr/bin/env python3
"""
自动捕获当前QQ对话并同步
通过监听当前会话实现真正的自动化
"""
import os
import sys
import json
from datetime import datetime, date

# 当前会话消息列表（在运行时动态填充）
current_session_messages = []

def capture_message(role, message):
    """捕获消息"""
    timestamp = datetime.now().strftime("%H:%M")
    
    current_session_messages.append({
        'role': role,
        'message': message,
        'timestamp': timestamp
    })
    
    # 自动保存到状态文件
    state_file = '/root/.openclaw/workspace/chat-website/.live_conversations.json'
    
    # 读取现有消息
    if os.path.exists(state_file):
        with open(state_file, 'r', encoding='utf-8') as f:
            data = json.load(f)
            messages = data.get('messages', [])
    else:
        messages = []
    
    # 添加新消息
    messages.append({
        'role': role,
        'message': message,
        'timestamp': timestamp,
        'captured_at': datetime.now().isoformat()
    })
    
    # 保存
    with open(state_file, 'w', encoding='utf-8') as f:
        json.dump({
            'last_captured': datetime.now().isoformat(),
            'total_messages': len(messages),
            'messages': messages
        }, f, ensure_ascii=False, indent=2)
    
    print(f"✅ 捕获消息: [{timestamp}] {role} - {message[:30]}...")

if __name__ == '__main__':
    # 测试捕获
    if len(sys.argv) > 2:
        role = sys.argv[1]
        message = sys.argv[2]
        capture_message(role, message)
    else:
        print("用法: python3 live_capture.py <role> <message>")
        print("示例: python3 live_capture.py user '你好'")
