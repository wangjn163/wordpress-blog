#!/usr/bin/env python3
"""
定时同步对话到PostgreSQL
这个脚本应该被cron定期调用，将OpenClaw的对话同步到数据库
"""
import sys
import os
from datetime import datetime, date

# 添加Flask应用路径
sys.path.insert(0, '/root/.openclaw/workspace/chat-website')

# 导入Flask应用
from app import app, Conversation, db

def sync_conversations_from_json():
    """从JSON文件同步对话到PostgreSQL"""
    json_file = '/root/.openclaw/workspace/chat-website/data/conversations.json'
    
    if not os.path.exists(json_file):
        print("ℹ️  JSON文件不存在，无需同步")
        return 0
    
    with app.app_context():
        # 读取JSON文件
        import json
        with open(json_file, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        conversations = data.get('conversations', [])
        synced_count = 0
        
        for conv in conversations:
            # 检查是否已存在（通过timestamp和role判断）
            existing = Conversation.query.filter_by(
                timestamp=conv['timestamp'],
                role=conv['role']
            ).first()
            
            if not existing:
                # 创建新对话记录
                new_conv = Conversation(
                    role=conv['role'],
                    message=conv['message'],
                    conversation_date=date.today(),
                    timestamp=conv['timestamp']
                )
                db.session.add(new_conv)
                synced_count += 1
        
        if synced_count > 0:
            db.session.commit()
            print(f"✅ 同步了 {synced_count} 条新对话到PostgreSQL")
            
            # 备份JSON文件
            os.rename(json_file, json_file + f'.synced_{datetime.now().strftime("%Y%m%d_%H%M%S")}')
        else:
            print("ℹ️  没有新对话需要同步")
        
        return synced_count

if __name__ == '__main__':
    print(f"🔄 开始同步对话... ({datetime.now().strftime('%Y-%m-%d %H:%M:%S')})")
    count = sync_conversations_from_json()
    print(f"✅ 同步完成！新增 {count} 条记录")