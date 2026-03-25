#!/usr/bin/env python3
"""
实时获取OpenClaw会话对话并导出
"""
import subprocess
import json
import re
from datetime import datetime, date

def get_current_session_conversations():
    """从OpenClaw获取当前会话的对话"""
    try:
        # 使用正确的命令格式
        result = subprocess.run(
            ['openclaw', 'sessions', 'history', '--limit', '200', '--json'],
            capture_output=True,
            text=True,
            timeout=30
        )
        
        if result.returncode == 0:
            return parse_conversations_json(result.stdout)
        else:
            print(f"❌ 获取会话失败: {result.stderr}")
            return []
    except Exception as e:
        print(f"❌ 执行出错: {e}")
        return []

def parse_conversations_json(json_str):
    """解析JSON格式的对话输出"""
    conversations = []
    
    try:
        data = json.loads(json_str)
        # 根据实际的JSON结构解析
        # 这里需要根据openclaw返回的实际格式调整
        messages = data.get('messages', []) if isinstance(data, dict) else []
        
        for msg in messages:
            role = msg.get('role', 'user')
            content = msg.get('content', '')
            timestamp = msg.get('timestamp', datetime.now().strftime("%H:%M"))
            
            if content:
                conversations.append({
                    'role': role,
                    'message': content,
                    'timestamp': timestamp
                })
    except Exception as e:
        print(f"❌ 解析JSON失败: {e}")
        # 回退到文本解析
        return parse_conversations(json_str)
    
    return conversations

def parse_conversations(output):
    """解析对话输出"""
    conversations = []
    lines = output.split('\n')
    
    for line in lines:
        # 尝试匹配对话格式
        # 格式可能是: user 或 assistant 开头，后面是消息内容
        if line.strip().startswith('user:') or line.strip().startswith('assistant:'):
            parts = line.strip().split(':', 1)
            if len(parts) >= 2:
                role = parts[0].strip()
                message = parts[1].strip()
                
                # 提取时间戳（如果有的话）
                time_match = re.search(r'\[(\d{2}:\d{2})\]', message)
                if time_match:
                    timestamp = time_match.group(1)
                    # 移除时间戳从消息中
                    message = re.sub(r'\[\d{2}:\d{2}\]\s*', '', message)
                else:
                    timestamp = datetime.now().strftime("%H:%M")
                
                if message:  # 只添加非空消息
                    conversations.append({
                        'role': 'user' if 'user' in role.lower() else 'assistant',
                        'message': message,
                        'timestamp': timestamp
                    })
    
    return conversations

def export_to_json(conversations, output_file):
    """导出到JSON文件"""
    data = {
        'date': date.today().strftime('%Y-%m-%d'),
        'export_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
        'conversations': conversations
    }
    
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    
    print(f"✅ 已导出 {len(conversations)} 条对话到 {output_file}")

if __name__ == '__main__':
    output_file = '/root/.openclaw/workspace/chat-website/data/conversations.json'
    
    print(f"🔄 获取当前会话对话... ({datetime.now().strftime('%Y-%m-%d %H:%M:%S')})")
    
    conversations = get_current_session_conversations()
    
    if conversations:
        export_to_json(conversations, output_file)
        print(f"✅ 导出完成！")
    else:
        print(f"ℹ️  没有获取到对话")
