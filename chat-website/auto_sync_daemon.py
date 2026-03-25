#!/usr/bin/env python3
"""
完全自动化的对话同步守护进程
自动捕获对话、导出、同步，无需人工干预
"""
import os
import sys
import json
import time
import subprocess
from datetime import datetime, timedelta

# 配置
WORKSPACE = '/root/.openclaw/workspace/chat-website'
STATE_FILE = os.path.join(WORKSPACE, '.auto_sync_state.json')
LOG_FILE = os.path.join(WORKSPACE, 'auto_sync.log')

def log(message):
    """记录日志"""
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    log_msg = f"[{timestamp}] {message}\n"
    print(log_msg, end='')
    with open(LOG_FILE, 'a') as f:
        f.write(log_msg)

def load_state():
    """加载状态"""
    if os.path.exists(STATE_FILE):
        with open(STATE_FILE, 'r') as f:
            return json.load(f)
    return {
        'last_check': None,
        'last_sync_count': 0,
        'conversation_hashes': []
    }

def save_state(state):
    """保存状态"""
    with open(STATE_FILE, 'w') as f:
        json.dump(state, f, indent=2)

def get_conversation_hash(role, message, timestamp):
    """生成对话的唯一hash"""
    import hashlib
    content = f"{timestamp}|{role}|{message[:100]}"
    return hashlib.md5(content.encode()).hexdigest()

def export_and_sync():
    """导出并同步对话"""
    try:
        # 1. 导出对话
        export_script = os.path.join(WORKSPACE, 'export_conversations.py')
        result = subprocess.run(
            ['python3', export_script],
            capture_output=True,
            text=True,
            timeout=30
        )

        if result.returncode != 0:
            log(f"❌ 导出失败: {result.stderr}")
            return 0

        # 2. 读取导出的对话
        json_file = os.path.join(WORKSPACE, 'data/conversations.json')
        with open(json_file, 'r') as f:
            data = json.load(f)

        conversations = data.get('conversations', [])

        # 3. 同步到数据库
        sync_script = os.path.join(WORKSPACE, 'sync_conversations.py')
        result = subprocess.run(
            ['python3', sync_script],
            capture_output=True,
            text=True,
            timeout=30
        )

        # 解析同步结果
        sync_count = 0
        if '新增' in result.stdout:
            import re
            match = re.search(r'新增 (\d+) 条', result.stdout)
            if match:
                sync_count = int(match.group(1))

        log(f"✅ 同步完成: {sync_count}条新对话")
        return sync_count

    except Exception as e:
        log(f"❌ 同步出错: {e}")
        return 0

def monitor_and_sync():
    """监控并自动同步"""
    log("🚀 自动同步守护进程启动")
    
    while True:
        try:
            state = load_state()
            now = datetime.now()
            
            # 每30分钟检查一次
            if state['last_check']:
                last_check = datetime.fromisoformat(state['last_check'])
                if (now - last_check).total_seconds() < 1800:  # 30分钟
                    time.sleep(60)  # 等待1分钟再检查
                    continue
            
            log("🔄 开始自动检查...")
            
            # 执行导出和同步
            sync_count = export_and_sync()
            
            # 更新状态
            state['last_check'] = now.isoformat()
            state['last_sync_count'] = sync_count
            save_state(state)
            
            log(f"✅ 检查完成，等待下次检查...")
            
            # 等待30分钟
            time.sleep(1800)
            
        except KeyboardInterrupt:
            log("👋 守护进程停止")
            break
        except Exception as e:
            log(f"❌ 守护进程出错: {e}")
            time.sleep(60)  # 出错后等待1分钟再继续

if __name__ == '__main__':
    import argparse
    
    parser = argparse.ArgumentParser(description='自动化对话同步守护进程')
    parser.add_argument('--once', action='store_true', help='只执行一次')
    
    args = parser.parse_args()
    
    if args.once:
        log("🔄 执行一次性同步...")
        export_and_sync()
        log("✅ 完成")
    else:
        monitor_and_sync()
