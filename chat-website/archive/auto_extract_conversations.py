#!/usr/bin/env python3
"""
从OpenClaw会话历史中自动提取对话
"""
import subprocess
import json
import re
from datetime import datetime, date

def get_session_conversations():
    """获取当前会话的对话"""
    try:
        # 使用sessions_history工具
        result = subprocess.run(
            ['openclaw', 'sessions', 'list', '--json'],
            capture_output=True,
            text=True,
            timeout=30
        )
        
        if result.returncode == 0:
            # 解析JSON输出
            try:
                sessions = json.loads(result.stdout)
                # 查找当前QQBot会话
                for session in sessions:
                    if 'qqbot' in session.get('key', '').lower():
                        # 获取会话历史
                        history_cmd = ['openclaw', 'sessions', 'history', session['key'], '--limit', '100']
                        history_result = subprocess.run(
                            history_cmd,
                            capture_output=True,
                            text=True,
                            timeout=30
                        )
                        if history_result.returncode == 0:
                            return parse_conversations(history_result.stdout)
            except:
                pass
        
        # 如果上面的方法失败，使用备用方案
        return get_conversations_from_memory()
        
    except Exception as e:
        print(f"❌ 获取对话失败: {e}")
        return []

def get_conversations_from_memory():
    """从memory文件中提取对话（备用方案）"""
    conversations = []
    memory_dir = '/root/.openclaw/workspace/memory'
    
    if not os.path.exists(memory_dir):
        return conversations
    
    # 读取今天的memory文件
    today = date.today()
    memory_file = os.path.join(memory_dir, today.strftime('%Y-%m-%d') + '.md')
    
    if not os.path.exists(memory_file):
        return conversations
    
    with open(memory_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 解析对话格式
    lines = content.split('\n')
    current_role = None
    current_message = []
    current_time = None
    
    for line in lines:
        # 匹配时间戳行
        time_match = re.match(r'\[?(\d{2}:\d{2})\]?\s*(user|assistant):?\s*', line)
        if time_match:
            # 保存上一条对话
            if current_role and current_message:
                conversations.append({
                    'role': current_role,
                    'message': '\n'.join(current_message).strip(),
                    'timestamp': current_time
                })
            
            current_time = time_match.group(1)
            current_role = 'user' if 'user' in time_match.group(2).lower() else 'assistant'
            current_message = []
            
            # 提取消息内容
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

def parse_conversations(output):
    """解析对话输出"""
    conversations = []
    lines = output.split('\n')
    
    current_role = None
    current_message = []
    current_time = None
    
    for line in lines:
        # 尝试匹配格式: [HH:MM] role: message
        time_role_match = re.match(r'\[?(\d{2}:\d{2})\]?\s*(user|assistant):?\s*(.*)', line)
        
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
            
            message_content = time_role_match.group(3).strip()
            if message_content:
                current_message.append(message_content)
        elif current_role:
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

def export_to_json(conversations):
    """导出到JSON文件"""
    output_file = '/root/.openclaw/workspace/chat-website/data/conversations.json'
    
    data = {
        'date': date.today().strftime('%Y-%m-%d'),
        'export_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
        'conversations': conversations
    }
    
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    
    print(f"✅ 自动导出 {len(conversations)} 条对话")
    return len(conversations)

if __name__ == '__main__':
    import os
    
    print(f"🔄 自动提取对话... ({datetime.now().strftime('%Y-%m-%d %H:%M:%S')})")
    
    conversations = get_session_conversations()
    
    if conversations:
        export_to_json(conversations)
        print("✅ 自动导出完成！")
    else:
        print("ℹ️  没有找到对话")
