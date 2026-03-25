#!/usr/bin/env python3
"""
从 OpenClaw 会话历史文件中自动提取今天的对话
"""
import json
import os
from datetime import datetime, date, timedelta

def parse_session_file(session_file, target_date=None):
    """解析会话历史 JSONL 文件

    Args:
        session_file: 会话文件路径
        target_date: 目标日期（date对象），如果为None则提取所有对话
    """
    conversations = []

    with open(session_file, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue

            try:
                data = json.loads(line)

                # 只处理消息类型
                if data.get('type') == 'message':
                    msg = data.get('message', {})
                    role = msg.get('role', '')
                    content_list = msg.get('content', [])

                    # 提取文本内容
                    for item in content_list:
                        if item.get('type') == 'text':
                            text = item.get('text', '').strip()
                            if text:
                                # 过滤掉纯系统提示，但保留用户实际问题
                                # 如果文本包含"现有用户输入如下"，提取后面的部分
                                if '现有用户输入如下' in text:
                                    parts = text.split('现有用户输入如下')
                                    if len(parts) > 1:
                                        # 提取用户实际输入
                                        user_input = parts[1].strip()
                                        if user_input and not user_input.startswith('【'):
                                            text = user_input

                                # 如果还是系统提示，跳过
                                if text.startswith('Skills store policy') or \
                                   text.startswith('你正在通过') or \
                                   text.startswith('【本次会话上下文】'):
                                    continue

                                # 提取时间戳
                                timestamp = datetime.fromtimestamp(msg.get('timestamp', 0) / 1000)
                                time_str = timestamp.strftime("%H:%M")
                                conv_date = timestamp.date()

                                # 如果指定了目标日期，只提取该日期的对话；否则提取所有
                                if target_date is None or conv_date == target_date:
                                    conversations.append({
                                        'role': role,
                                        'message': text,
                                        'timestamp': time_str,
                                        'date': conv_date.strftime('%Y-%m-%d')  # 添加日期字段
                                    })
                                    break # 只取第一个文本块
            except:
                continue

    return conversations

def get_todays_conversations(target_date=None):
    """获取指定日期的所有对话

    Args:
        target_date: 目标日期（date对象），如果为None则使用今天
    """
    if target_date is None:
        target_date = date.today()

    # 查找最新的会话文件
    sessions_dir = '/root/.openclaw/agents/main/sessions'

    # 找到最新的 JSONL 文件
    jsonl_files = []
    for f in os.listdir(sessions_dir):
        if f.endswith('.jsonl'):
            file_path = os.path.join(sessions_dir, f)
            mtime = os.path.getmtime(file_path)
            jsonl_files.append((mtime, file_path))

    if not jsonl_files:
        print("⚠️  未找到会话历史文件")
        return []

    # 使用最新的文件
    latest_file = sorted(jsonl_files)[-1][1]
    print(f"📂 读取会话文件: {os.path.basename(latest_file)}")

    # 解析文件，提取指定日期的对话
    conversations = parse_session_file(latest_file, target_date=target_date)

    # 去重（基于时间戳和角色）
    seen = set()
    unique_conversations = []
    for conv in conversations:
        key = f"{conv['timestamp']}_{conv['role']}"
        if key not in seen:
            seen.add(key)
            unique_conversations.append(conv)

    print(f"✅ 提取了 {len(unique_conversations)} 条对话（日期: {target_date}）")

    return unique_conversations

def export_to_json(conversations, output_file, export_date=None):
    """导出到JSON文件

    Args:
        conversations: 对话列表
        output_file: 输出文件路径
        export_date: 导出日期（date对象），如果为None则从对话中推断
    """
    if export_date is None and conversations:
        # 从第一条对话中推断日期
        try:
            export_date = datetime.strptime(conversations[0]['date'], '%Y-%m-%d').date()
        except (KeyError, ValueError):
            export_date = date.today()

    data = {
        'date': export_date.strftime('%Y-%m-%d'),
        'export_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
        'conversations': conversations
    }

    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    print(f"✅ 已导出 {len(conversations)} 条对话到 {output_file}（日期: {export_date}）")

if __name__ == '__main__':
    import sys

    # 支持命令行参数指定日期
    target_date = None
    if len(sys.argv) > 1:
        try:
            target_date = datetime.strptime(sys.argv[1], '%Y-%m-%d').date()
            print(f"📅 目标日期: {target_date}")
        except ValueError:
            print(f"⚠️  日期格式错误，请使用 YYYY-MM-DD 格式")
            sys.exit(1)

    output_file = '/root/.openclaw/workspace/chat-website/data/conversations.json'

    print(f"🔄 从会话历史自动提取对话... ({datetime.now().strftime('%Y-%m-%d %H:%M:%S')})")

    conversations = get_todays_conversations(target_date=target_date)

    if conversations:
        export_to_json(conversations, output_file, export_date=target_date)
        print(f"✅ 导出完成！")
    else:
        print(f"ℹ️  没有找到{'今天' if target_date is None else target_date}的对话")
