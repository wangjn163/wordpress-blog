#!/usr/bin/env python3
"""
直接同步对话到数据库（绕过登录验证）
"""
import json
from app import app, db, Conversation
from datetime import datetime, date

def sync_conversations(target_date_str=None):
    """同步对话到数据库"""
    if target_date_str:
        target_date = datetime.strptime(target_date_str, '%Y-%m-%d').date()
    else:
        target_date = date.today()

    json_file = '/root/.openclaw/workspace/chat-website/data/conversations.json'

    with open(json_file, 'r', encoding='utf-8') as f:
        data = json.load(f)

    conversations = data.get('conversations', [])
    print(f"📂 读取到 {len(conversations)} 条对话")

    synced_count = 0
    with app.app_context():
        for conv in conversations:
            # 检查是否已存在（基于 timestamp 和 role 去重）
            existing = Conversation.query.filter_by(
                conversation_date=target_date,
                timestamp=conv['timestamp'],
                role=conv['role']
            ).first()

            if not existing:
                new_conv = Conversation(
                    role=conv['role'],
                    message=conv['message'],
                    conversation_date=target_date,
                    timestamp=conv['timestamp']
                )
                db.session.add(new_conv)
                synced_count += 1

        if synced_count > 0:
            db.session.commit()
            print(f"✅ 成功同步 {synced_count} 条对话到 {target_date}")
        else:
            print(f"ℹ️  没有新对话需要同步")

        # 显示当前数据库中的对话总数
        total = Conversation.query.filter_by(conversation_date=target_date).count()
        print(f"📊 数据库中 {target_date} 的对话总数: {total}")

if __name__ == '__main__':
    import sys
    target_date = sys.argv[1] if len(sys.argv) > 1 else None
    sync_conversations(target_date)
