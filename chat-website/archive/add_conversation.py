#!/usr/bin/env python3
"""
快速添加对话到导出脚本
用法: python3 add_conversation.py <role> <message> [timestamp]

示例:
  python3 add_conversation.py user "你好" "09:30"
  python3 add_conversation.py assistant "好的，我来帮你"
"""
import sys
import re
from datetime import datetime

def add_conversation_to_script(role, message, timestamp=None):
    """将对话添加到导出脚本"""

    if timestamp is None:
        timestamp = datetime.now().strftime("%H:%M")

    script_file = '/root/.openclaw/workspace/chat-website/export_conversations.py'

    # 读取脚本
    with open(script_file, 'r', encoding='utf-8') as f:
        content = f.read()

    # 转义消息中的特殊字符
    escaped_message = message.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\r', '')

    # 构造新的对话条目
    new_entry = f'''        {{
            'role': '{role}',
            'message': '{escaped_message}',
            'timestamp': '{timestamp}'
        }},
'''

    # 找到最后一个对话条目后的位置（在 ] 之前）
    # 查找模式：最后一行的 'timestamp': 'XX:XX' }\n    ]
    pattern = r"([ \t]*'timestamp':\s*'[0-9:]+'[\s\S]*?}},)\n(    ])"
    match = re.search(pattern, content)

    if match:
        # 在最后一行后插入新对话
        insert_pos = match.end(1)
        new_content = content[:insert_pos] + '\n' + new_entry + content[insert_pos - len(match.group(2)):]

        # 写回文件
        with open(script_file, 'w', encoding='utf-8') as f:
            f.write(new_content)

        print(f"✅ 已添加对话到导出脚本")
        print(f"   角色: {role}")
        print(f"   时间: {timestamp}")
        print(f"   消息: {message[:50]}...")
        print(f"\n💡 提示: 现在可以点击网页刷新按钮同步数据")
        return True
    else:
        print("❌ 错误: 无法找到插入位置")
        print(f"   请检查文件格式: {script_file}")
        return False

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print(__doc__)
        print("\n错误: 参数不足")
        print("\n当前用法:")
        print("  python3 add_conversation.py <role> <message> [timestamp]")
        print("\n参数说明:")
        print("  role      - user 或 assistant")
        print("  message   - 对话内容（用引号包围）")
        print("  timestamp - 可选，格式 HH:MM，默认为当前时间")
        print("\n示例:")
        print('  python3 add_conversation.py user "你好，世界"')
        print('  python3 add_conversation.py assistant "好的，我来帮你" "09:30"')
        sys.exit(1)

    role = sys.argv[1]
    message = sys.argv[2]
    timestamp = sys.argv[3] if len(sys.argv) > 3 else None

    # 验证角色
    if role not in ['user', 'assistant']:
        print("❌ 错误: role 必须是 'user' 或 'assistant'")
        sys.exit(1)

    add_conversation_to_script(role, message, timestamp)
