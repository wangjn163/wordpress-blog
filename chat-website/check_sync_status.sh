#!/bin/bash
# 检查自动同步系统状态

echo "🔍 自动同步系统状态检查"
echo "================================"

# 1. 检查守护进程
echo -e "\n📊 守护进程状态:"
systemctl status chat-sync-daemon --no-pager | grep -E "Active|Main PID"

# 2. 检查定时任务
echo -e "\n⏰ 定时任务:"
crontab -l | grep -E "export|sync"

# 3. 检查数据库对话数量
echo -e "\n💾 数据库对话统计:"
cd /root/.openclaw/workspace/chat-website
python3 -c "
from app import app, db, Conversation
from datetime import date
with app.app_context():
    today = date.today()
    count = Conversation.query.filter_by(conversation_date=today).count()
    print(f'  今天({today}): {count}条对话')
    
    # 检查最近同步时间
    import os
    state_file = '.auto_sync_state.json'
    if os.path.exists(state_file):
        import json
        with open(state_file) as f:
            state = json.load(f)
        last_check = state.get('last_check', '未检查')
        last_sync = state.get('last_sync_count', 0)
        print(f'  最后检查: {last_check}')
        print(f'  最后同步: {last_sync}条新对话')
"

# 4. 检查日志
echo -e "\n📝 最近日志:"
tail -5 /root/.openclaw/workspace/chat-website/auto_sync.log

echo -e "\n✅ 检查完成"
