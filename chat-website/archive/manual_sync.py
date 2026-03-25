#!/usr/bin/env python3
"""
手动添加对话到数据库
用于快速记录重要对话
"""
import sys
from datetime import datetime, date

sys.path.insert(0, '/root/.openclaw/workspace/chat-website')

from app import app, Conversation, db

def add_conversation(role, message, timestamp=None):
    """添加一条对话"""
    if timestamp is None:
        timestamp = datetime.now().strftime("%H:%M")
    
    with app.app_context():
        # 检查是否已存在
        existing = Conversation.query.filter_by(
            conversation_date=date.today(),
            timestamp=timestamp,
            role=role
        ).first()
        
        if existing:
            print(f"⚠️  该时间戳的对话已存在: [{timestamp}] {role}")
            return False
        
        new_conv = Conversation(
            role=role,
            message=message,
            conversation_date=date.today(),
            timestamp=timestamp
        )
        db.session.add(new_conv)
        db.session.commit()
        print(f"✅ 添加成功: [{timestamp}] {role} - {message[:50]}...")
        return True

def batch_add_conversations(conversations):
    """批量添加对话
    conversations: list of dict with keys: role, message, timestamp
    """
    count = 0
    for conv in conversations:
        if add_conversation(conv['role'], conv['message'], conv.get('timestamp')):
            count += 1
    return count

if __name__ == '__main__':
    # 示例：手动记录今天的对话
    # 你可以修改这里的内容来记录今天的对话
    
    print("📝 手动添加对话到数据库")
    print("=" * 50)
    
    # 今天的重要对话（示例）
    todays_conversations = [
        {
            'role': 'user',
            'message': '你好',
            'timestamp': '06:36'
        },
        {
            'role': 'assistant',
            'message': '你好！我是OpenClaw的AI助手。很高兴认识你！👋\n\n我注意到这是一个新的会话。让我先了解一下你的情况...',
            'timestamp': '06:36'
        },
        {
            'role': 'user',
            'message': '看下web 服务，没有启动吗，我访问不了',
            'timestamp': '08:47'
        },
        {
            'role': 'assistant',
            'message': '让我检查一下web服务的状态。\n\nWeb服务**正在运行**！✅\n\n- **状态**: 运行中（进程ID: 149016）\n- **服务**: Python Flask应用（app.py）\n- **端口**: 80\n- **响应**: 正常（HTTP 200）',
            'timestamp': '08:47'
        },
        {
            'role': 'user',
            'message': '页面显示白板，什么内容都没有',
            'timestamp': '08:49'
        },
        {
            'role': 'assistant',
            'message': '这是一个Vue单页应用，页面白板是因为JavaScript没有正确执行。\n\n可能原因：\n1. **CDN资源加载失败** - unpkg.com被墙或网络问题\n2. **浏览器控制台有错误** - JS执行失败导致页面空白',
            'timestamp': '08:49'
        }
    ]
    
    count = batch_add_conversations(todays_conversations)
    print("=" * 50)
    print(f"✅ 完成！添加了 {count} 条对话")
