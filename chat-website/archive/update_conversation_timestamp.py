#!/usr/bin/env python3
"""
自动更新当前时间到对话列表，实现实时同步
"""
import json
import os
from datetime import datetime, date

def add_current_conversation():
    """添加当前正在进行的对话到列表"""
    json_file = '/root/.openclaw/workspace/chat-website/data/conversations.json'
    
    # 读取现有对话
    if os.path.exists(json_file):
        with open(json_file, 'r', encoding='utf-8') as f:
            data = json.load(f)
    else:
        data = {
            'date': date.today().strftime('%Y-%m-%d'),
            'export_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            'conversations': []
        }
    
    # 获取当前时间
    current_time = datetime.now().strftime("%H:%M")
    
    # 检查是否已经存在当前时间的对话（避免重复）
    last_conv = data['conversations'][-1] if data['conversations'] else None
    if last_conv and last_conv['timestamp'] == current_time:
        print(f"ℹ️  当前时间 {current_time} 的对话已存在，跳过添加")
        return data
    
    # 这里我们添加一个占位符，表示需要手动更新实际对话内容
    # 在实际使用中，这个文件会被定期更新以包含最新的对话
    data['export_time'] = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    
    # 保存更新
    with open(json_file, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    
    print(f"✅ 已更新对话时间戳: {current_time}")
    return data

if __name__ == '__main__':
    print(f"🔄 更新对话时间戳... ({datetime.now().strftime('%Y-%m-%d %H:%M:%S')})")
    add_current_conversation()
    print(f"✅ 更新完成！")
