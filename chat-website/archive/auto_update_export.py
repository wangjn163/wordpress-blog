#!/usr/bin/env python3
"""
自动更新导出脚本，将最新对话添加到列表中
"""
import re
from datetime import datetime

def update_export_script_with_conversation(role, message, timestamp):
    """将新对话添加到导出脚本中"""

    script_file = '/root/.openclaw/workspace/chat-website/export_conversations.py'

    # 读取脚本内容
    with open(script_file, 'r', encoding='utf-8') as f:
        content = f.read()

    # 格式化消息（转义特殊字符）
    escaped_message = message.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n')

    # 构造新的对话条目
    new_entry = f'''        {{
            'role': '{role}',
            'message': '{escaped_message}',
            'timestamp': '{timestamp}'
        }},
'''

    # 找到 todays_conversations 列表的结尾
    # 在最后一个条目后插入新对话
    pattern = r"([ \t]*{{[\s\S]*?'timestamp':\s*'[0-9:]+'[\s\S]*?}},)\n(    ]\n)"
    match = re.search(pattern, content)

    if match:
        # 在最后一个条目后插入
        insert_pos = match.end(1)
        new_content = content[:insert_pos] + '\n' + new_entry + content[insert_pos - len(match.group(2)):]

        # 写回文件
        with open(script_file, 'w', encoding='utf-8') as f:
            f.write(new_content)

        print(f"✅ 已添加新对话到导出脚本: [{timestamp}] {role}")
        return True
    else:
        print("❌ 无法找到插入位置")
        return False

if __name__ == '__main__':
    import sys

    if len(sys.argv) < 4:
        print("用法: python3 auto_update_export.py <role> <message> <timestamp>")
        print("示例: python3 auto_update_export.py user '你好' '09:30'")
        sys.exit(1)

    role = sys.argv[1]
    message = sys.argv[2]
    timestamp = sys.argv[3]

    update_export_script_with_conversation(role, message, timestamp)
