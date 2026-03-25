#!/usr/bin/env python3
"""
自动同步OpenClaw会话历史到PostgreSQL数据库
使用OpenClaw的sessions_history API获取对话
"""
import sys
import os
import subprocess
import json
import re
from datetime import datetime, date, timedelta

# 添加Flask应用路径
sys.path.insert(0, '/root/.openclaw/workspace/chat-website')

# 导入Flask应用
from app import app, Conversation, db

def get_session_history():
    """使用openclaw命令获取session历史"""
    try:
        # 获取当前会话历史
        result = subprocess.run(
            ['openclaw', 'sessions', 'list'],
            capture_output=True,
            text=True,
            timeout=30
        )
        
        if result.returncode == 0:
            return result.stdout
        else:
            print(f"❌ 获取会话历史失败: {result.stderr}")
            return None
    except Exception as e:
        print(f"❌ 执行命令出错: {e}")
        return None

def parse_conversations_from_output(output_text, target_date=None):
    """从openclaw输出中解析对话"""
    if target_date is None:
        target_date = date.today()
    
    conversations = []
    lines = output_text.split('\n')
    
    current_role = None
    current_message = []
    current_time = None
    
    for line in lines:
        # 尝试匹配时间戳和角色
        # 格式可能是: [08:30] user: message
        time_role_match = re.match(r'\[(\d{2}:\d{2})\]\s*(user|assistant):?\s*(.*)', line)
        
        if time_role_match:
            # 保存上一条对话
            if current_role and current_message:
                message_text = '\n'.join(current_message).strip()
                if message_text:
                    conversations.append({
                        'role': current_role,
                        'message': message_text,
                        'timestamp': current_time
                    })
            
            current_time = time_role_match.group(1)
            role_text = time_role_match.group(2).lower()
            current_role = 'user' if 'user' in role_text else 'assistant'
            current_message = []
            
            # 提取当前行的消息
            message_content = time_role_match.group(3).strip()
            if message_content:
                current_message.append(message_content)
        elif current_role:
            # 继续上一条消息
            current_message.append(line)
    
    # 保存最后一条对话
    if current_role and current_message:
        message_text = '\n'.join(current_message).strip()
        if message_text:
            conversations.append({
                'role': current_role,
                'message': message_text,
                'timestamp': current_time
            })
    
    return conversations

def sync_conversations(target_date=None):
    """同步对话到数据库"""
    if target_date is None:
        target_date = date.today()
    
    # 获取会话历史
    output_text = get_session_history()
    
    if not output_text:
        print("❌ 无法获取会话历史")
        return 0
    
    # 解析对话
    conversations = parse_conversations_from_output(output_text, target_date)
    
    if not conversations:
        print(f"ℹ️  没有解析到对话记录")
        return 0
    
    print(f"📊 解析到 {len(conversations)} 条对话")
    
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
            print(f"ℹ️  所有对话已存在，无需同步 ({target_date})")
        
        return synced_count

if __name__ == '__main__':
    import argparse
    
    parser = argparse.ArgumentParser(description='同步OpenClaw对话到PostgreSQL')
    parser.add_argument('--date', type=str, help='指定日期 (YYYY-MM-DD)')
    
    args = parser.parse_args()
    
    print(f"🔄 开始同步对话... ({datetime.now().strftime('%Y-%m-%d %H:%M:%S')})")
    
    if args.date:
        target_date = datetime.strptime(args.date, '%Y-%m-%d').date()
        count = sync_conversations(target_date)
    else:
        count = sync_conversations()
    
    print(f"✅ 同步完成！新增 {count} 条记录")
