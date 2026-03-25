# 对话同步系统说明

## 🎯 刷新按钮流程

### 用户操作
```
用户点击"刷新"按钮
    ↓
前端发送 POST /api/sync-conversations
```

### 后端处理（app.py）
```python
@app.route('/api/sync-conversations', methods=['POST'])
def sync_conversations():
    # 1. 调用脚本获取最新对话
    python3 get_real_conversations.py
    
    # 2. 读取生成的 JSON 文件
    data/conversations.json
    
    # 3. 同步到数据库
    - 检查是否已存在
    - 只添加新对话
    - 返回同步结果
```

### 核心文件

| 文件 | 作用 | 必需 |
|------|------|------|
| `app.py` | Web 服务和同步 API | ✅ |
| `get_real_conversations.py` | 维护今天的对话列表 | ✅ |
| `data/conversations.json` | 对话数据文件 | ✅ 自动生成 |
| `auto_sync_daemon.py` | 后台守护进程（可选） | ⚪ |

## 📝 对话列表维护

### get_real_conversations.py

**作用**：维护今天的对话列表

**使用方式**：
1. 手动编辑 `todays_conversations` 数组
2. 添加新的对话记录（角色、消息、时间）
3. 运行脚本或点击刷新按钮自动同步

**示例**：
```python
todays_conversations = [
    {
        'role': 'user',
        'message': '用户消息内容',
        'timestamp': '09:37'
    },
    {
        'role': 'assistant',
        'message': 'AI回复内容',
        'timestamp': '09:37'
    }
]
```

## 🔄 自动化选项

### 方式1：点击刷新（推荐）
- 用户主动点击刷新按钮
- 自动获取最新对话
- 即时同步到数据库

### 方式2：定时任务（可选）
```bash
# 每分钟自动更新对话列表
*/1 * * * * /usr/bin/python3 /root/.openclaw/workspace/chat-website/get_real_conversations.py
```

### 方式3：守护进程（可选）
```bash
# 后台运行，定期检查和同步
systemctl start chat-sync-daemon
```

## 🗑️ 已归档的文件

以下文件已移至 `archive/` 目录：
- export_conversations.py
- export_from_session.py
- auto_get_latest_conversations.py
- update_conversation_timestamp.py
- test_add_conversation.py
- auto_capture_conversations.py
- auto_extract_conversations.py
- auto_sync.py
- auto_sync_v2.py
- auto_update_export.py
- manual_sync.py
- sync_conversations.py
- add_conversation.py

## 🎯 最佳实践

1. **定期更新对话列表**：每天结束时更新 `get_real_conversations.py`，添加当天的所有重要对话
2. **使用刷新按钮**：用户可以随时点击刷新获取最新对话
3. **查看日志**：`tail -f /var/log/chat-auto-sync.log`
4. **监控服务**：`systemctl status chat-web`

## ✅ 优势

- 简单：只需要维护一个对话列表
- 灵活：支持手动更新和自动刷新
- 可靠：基于文件存储，不会丢失数据
- 高效：点击刷新立即同步
