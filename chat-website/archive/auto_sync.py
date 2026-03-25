#!/usr/bin/env python3
"""
自动同步OpenClaw对话到PostgreSQL数据库
从memory目录中提取今天的对话并同步
"""
import sys
import os
import json
import re
from datetime import datetime, date, timedelta

# 添加Flask应用路径
sys.path.insert(0, '/root/.openclaw/workspace/chat-website')

# 导入Flask应用
from app import app, Conversation, db

def extract_conversations_from_memory(target_date=None):
    """从memory文件中提取对话"""
    if target_date is None:
        target_date = date.today()
    
    date_str = target_date.strftime('%Y-%m-%d')
    memory_file = f'/root/.openclaw/workspace/memory/{date_str}.md'
    
    if not os.path.exists(memory_file):
        print(f"ℹ️  {date_str} 的memory文件不存在")
        return []
    
    conversations = []
    with open(memory_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 解析对话格式（根据实际格式调整）
    # 假设格式为: [HH:MM] role: message
    lines = content.split('\n')
    current_role = None
    current_message = []
    current_time = None
    
    for line in lines:
        # 匹配时间戳行，如: [08:30] 或 08:30
        time_match = re.match(r'\[?(\d{2}:\d{2})\]?\s*(user|assistant)?:?\s*', line)
        if time_match:
            # 保存上一条对话
            if current_role and current_message:
                conversations.append({
                    'role': current_role,
                    'message': '\n'.join(current_message).strip(),
                    'timestamp': current_time
                })
            
            current_time = time_match.group(1)
            role_text = time_match.group(2)
            current_role = 'user' if role_text == 'user' else 'assistant'
            current_message = []
            # 提取时间戳后的消息内容
            message_part = line[time_match.end():].strip()
            if message_part:
                current_message.append(message_part)
        elif current_role:
            current_message.append(line)
    
    # 保存最后一条对话
    if current_role and current_message:
        conversations.append({
            'role': current_role,
            'message': '\n'.join(current_message).strip(),
            'timestamp': current_time
        })
    
    return conversations

def sync_conversations(target_date=None):
    """同步对话到数据库"""
    if target_date is None:
        target_date = date.today()
    
    conversations = extract_conversations_from_memory(target_date)
    
    if not conversations:
        print(f"ℹ️  {target_date} 没有找到对话记录")
        return 0
    
    with app.app_context():
        synced_count = 0
        
        for conv in conversations:
            # 检查是否已存在
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
            print(f"✅ 同步了 {synced_count} 条新对话到数据库 ({target_date})")
        else:
            print(f"ℹ️  没有新对话需要同步 ({target_date})")
        
        return synced_count

def sync_today():
    """同步今天的对话"""
    return sync_conversations(date.today())

def sync_yesterday():
    """同步昨天的对话"""
    return sync_conversations(date.today() - timedelta(days=1))

if __name__ == '__main__':
    import argparse
    
    parser = argparse.ArgumentParser(description='同步OpenClaw对话到PostgreSQL')
    parser.add_argument('--date', type=str, help='指定日期 (YYYY-MM-DD)')
    parser.add_argument('--today', action='store_true', help='同步今天的对话')
    parser.add_argument('--yesterday', action='store_true', help='同步昨天的对话')
    
    args = parser.parse_args()
    
    print(f"🔄 开始同步对话... ({datetime.now().strftime('%Y-%m-%d %H:%M:%S')})")
    
    if args.date:
        target_date = datetime.strptime(args.date, '%Y-%m-%d').date()
        count = sync_conversations(target_date)
    elif args.yesterday:
        count = sync_yesterday()
    else:
        count = sync_today()
    
    print(f"✅ 同步完成！新增 {count} 条记录")
