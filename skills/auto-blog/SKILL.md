---
name: auto-blog
description: 自动博客生成技能。每天定时生成AI资讯博客并发布到WordPress，支持Tavily和百度双源搜索。可手动触发或配置定时任务。
homepage: http://42.193.14.72:8081
metadata:
  openclaw:
    emoji: '📰'
    requires: { 
      env: ['TAVILY_API_KEY', 'BAIDU_API_KEY'],
      exec: ['node', 'python3', 'docker']
    }
    primaryEnv: 'TAVILY_API_KEY'
  security:
    credentials_usage: |
      This skill requires Tavily and Baidu search API keys for content generation.
      WordPress database credentials are used for publishing.
      All credentials are only sent to their respective API endpoints.
    allowed_domains:
      - api.tavily.com
      - qianfan.baidubce.com
---

# 自动博客生成 (Auto Blog)

每天自动生成AI资讯博客并发布到WordPress，集成Tavily和百度双源搜索。

## Setup

1. 配置必要的API密钥：
```bash
export TAVILY_API_KEY="your_tavily_key"
export BAIDU_API_KEY="your_baidu_key"
```

2. 确保WordPress数据库可访问

## 凭证加载

```bash
# Load API credentials
TAVILY_KEY="${TAVILY_API_KEY:-$(cat ~/.config/tavily/api_key 2>/dev/null)}"
BAIDU_KEY="${BAIDU_API_KEY:-$(cat ~/.config/baidu/api_key 2>/dev/null)}"

if [ -z "$TAVILY_KEY" ] || [ -z "$BAIDU_KEY" ]; then
  echo "缺少API凭证，请先配置"
  exit 1
fi
```

## 核心功能

### 1. 手动生成博客

```bash
# 立即生成并发布今天的博客
bash /root/.openclaw/workspace/skills/auto-blog/scripts/generate-blog.sh
```

### 2. 配置定时任务

```bash
# 设置每天上午9点自动生成
crontab -l > /tmp/current_cron
echo "0 9 * * * /root/.openclaw/workspace/skills/auto-blog/scripts/generate-blog.sh >> /var/log/blog-auto-generate.log 2>&1" >> /tmp/current_cron
crontab /tmp/current_cron
```

### 3. 查看定时任务状态

```bash
# 查看cron任务
crontab -l | grep blog

# 查看日志
tail -50 /var/log/blog-auto-generate.log
```

## 工作流程

### 步骤1：多源搜索

```bash
# Tavily搜索（国际视角）
/root/.nvm/versions/node/v22.22.1/bin/node /root/.openclaw/workspace/skills/tavily-search/scripts/search.mjs \
  "AI人工智能 大模型 最新" --topic general -n 5 > /tmp/tavily_result.txt

# 百度搜索（国内视角）
python3 /root/.openclaw/workspace/skills/baidu-search/scripts/search.py \
  '{"query": "AI人工智能 最新动态", "count": 5}' > /tmp/baidu_result.json
```

### 步骤2：提取关键信息

```bash
# 提取Tavily答案
TAVILY_ANSWER=$(sed -n '/## Answer/,/## Sources/p' /tmp/tavily_result.txt | tail -n +2 | head -n -1)

# 提取百度结果
BAIDU_ANSWER=$(cat /tmp/baidu_result.json | jq -r '.[0:2] | .[] | "<strong>\(.title)</strong><br>\(.content[:500])"')
```

### 步骤3：生成博客内容

```python
# 使用Python生成HTML内容（确保UTF-8编码）
import subprocess
from datetime import datetime

today = datetime.now().strftime('%Y年%m月%d日')
date_short = datetime.now().strftime('%Y-%m-%d')
time_now = datetime.now().strftime('%H:%M:%S')

content = f'''<article>
  <h2>从多模态革命到智能体时代</h2>
  <p>今天是{today},欢迎来到今天的 AI 每日资讯！本期汇集了Tavily和百度双搜索源的AI最新动态。</p>

  <h3>🔥 最新AI动态（Tavily搜索源）</h3>
  <p>{tavily_answer}</p>

  <h3>🇨🇳 国内AI动态（百度搜索源）</h3>
  <p>{baidu_answer}</p>

  <h3>🛠️ AI工具推荐（基于搜索结果）</h3>
  <p>{tools_content}</p>

  <p style='color: #666; font-size:0.9em; margin-top:30px;'>
    📅 {date_short} {time_now} | 🤖 由CrazyClaw自动生成 | 🔍 Tavily+百度双源搜索 | 📍 重庆
  </p>
</article>'''
```

### 步骤4：发布到WordPress

```bash
# 使用WordPress发布工具
bash /root/.openclaw/workspace/tools/wp-publish-v2.sh "$TITLE" "$CONTENT"
```

## 用户意图识别

当用户说以下内容时，触发此技能：

- "生成今天的博客"
- "发布AI资讯"
- "更新博客"
- "手动触发博客生成"
- "检查博客生成状态"

## 使用示例

### 示例1：手动生成
用户说：> "帮我生成今天的博客"

Agent应：
1. 立即执行生成脚本
2. 显示生成结果
3. 提供博客链接

### 示例2：检查状态
用户说：> "博客生成正常吗？"

Agent应：
1. 查看最新日志
2. 检查cron任务
3. 显示最新博客信息

### 示例3：配置定时任务
用户说：> "设置每天10点生成博客"

Agent应：
1. 更新crontab
2. 验证配置
3. 确认生效

## 日志管理

```bash
# 查看今天日志
grep "$(date +%Y-%m-%d)" /var/log/blog-auto-generate.log

# 查看错误
grep "ERROR\|失败" /var/log/blog-auto-generate.log | tail -20

# 查看成功记录
grep "成功" /var/log/blog-auto-generate.log | tail -20
```

## 故障排查

### 问题1：Tavily搜索失败
```bash
# 检查API密钥
echo $TAVILY_API_KEY

# 手动测试
node /root/.openclaw/workspace/skills/tavily-search/scripts/search.mjs "AI" --topic general -n 1
```

### 问题2：百度搜索失败
```bash
# 检查API密钥
echo $BAIDU_API_KEY

# 手动测试
python3 /root/.openclaw/workspace/skills/baidu-search/scripts/search.py '{"query": "AI", "count": 1}'
```

### 问题3：WordPress发布失败
```bash
# 检查数据库连接
docker exec wordpress-db mariadb -u wordpress_user -p"$DB_PASSWORD" wordpress -e "SELECT 1"

# 手动发布测试
bash /root/.openclaw/workspace/tools/wp-publish-v2.sh "测试标题" "<p>测试内容</p>"
```

## 维护任务

### 自动清理旧博客
脚本默认保留最近7天的博客，自动删除7天前的博客。

```bash
# 手动清理7天前的博客
docker exec wordpress-db mariadb -u wordpress_user -p"$DB_PASSWORD" wordpress -e \
  "DELETE FROM wp_posts WHERE post_type='post' AND DATE(post_date) < DATE_SUB(CURDATE(), INTERVAL 7 DAY);"

# 查看当前博客数量
docker exec wordpress-db mariadb -u wordpress_user -p"$DB_PASSWORD" wordpress -e \
  "SELECT DATE(post_date) as date, COUNT(*) as count FROM wp_posts WHERE post_type='post' GROUP BY DATE(post_date) ORDER BY date DESC;"
```

### 自定义保留天数

如果需要修改保留天数，编辑脚本中的SQL语句：

```bash
# 保留30天（修改INTERVAL值）
DELETE FROM wp_posts WHERE post_type='post' AND DATE(post_date) < DATE_SUB(CURDATE(), INTERVAL 30 DAY);

# 只保留当天
DELETE FROM wp_posts WHERE post_type='post' AND DATE(post_date) < CURDATE();
```

### 备份配置
```bash
# 备份cron任务
crontab -l > /root/backup/crontab-blog-$(date +%Y%m%d).txt

# 备份日志
cp /var/log/blog-auto-generate.log /root/backup/blog-log-$(date +%Y%m%d).log
```

## 高级配置

### 自定义生成时间
```bash
# 修改crontab时间格式
# 格式：分 时 日 月 周
# 例子：每天10点30分
30 10 * * * /root/.openclaw/workspace/skills/auto-blog/scripts/generate-blog.sh
```

### 多次生成
```bash
# 每天早上9点和下午3点各生成一次
0 9,15 * * * /root/.openclaw/workspace/skills/auto-blog/scripts/generate-blog.sh
```

## 注意事项

1. **UTF-8编码**：所有内容生成必须使用UTF-8编码，避免中文乱码
2. **API限流**：注意Tavily和百度的API调用频率限制
3. **定时任务**：修改crontab后建议手动验证一下是否生效
4. **日志监控**：定期检查日志，及时发现生成失败的情况
5. **数据库备份**：大规模删除博客前建议先备份数据库

## 相关脚本

- `/root/.openclaw/workspace/skills/auto-blog/scripts/generate-blog.sh` - 主生成脚本
- `/root/.openclaw/workspace/tools/wp-publish-v2.sh` - WordPress发布工具
- `/var/log/blog-auto-generate.log` - 生成日志
- `/root/.openclaw/workspace/skills/tavily-search/scripts/search.mjs` - Tavily搜索
- `/root/.openclaw/workspace/skills/baidu-search/scripts/search.py` - 百度搜索
