#!/bin/bash
LOG_FILE="/var/log/blog-auto-generate-both.log"
export BAIDU_API_KEY="REDACTED_BAIDU_API_KEY"
export TAVILY_API_KEY="REDACTED_TAVILY_API_KEY"
cd /root/.openclaw/workspace || exit 1

TODAY=$(date '+%Y年%m月%d日')
DATE_SHORT=$(date '+%Y-%m-%d')
TIME_NOW=$(date '+%H:%M:%S')
TIMESTAMP=$(date '+%Y%m%d%H%M%S')
TITLE="AI 每日资讯 – $TODAY"
SLUG="ai-daily-$TIMESTAMP"

echo "========================================" | tee -a "$LOG_FILE"
echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$LOG_FILE"
echo "步骤1: 搜索AI新闻..." | tee -a "$LOG_FILE"

# 使用百度搜索
echo "正在执行百度搜索..." | tee -a "$LOG_FILE"
python3 skills/baidu-search/scripts/search.py '{"query":"人工智能 AI news","count":3}' 2>/dev/null > /tmp/baidu_result.json

if [ -s /tmp/baidu_result.json ] && grep -q '"title"' /tmp/baidu_result.json; then
    echo "百度搜索成功" | tee -a "$LOG_FILE"
    
    # 解析百度搜索结果
    Baidu_CONTENT=$(python3 << 'PYTHON_SCRIPT'
import json
try:
    with open('/tmp/baidu_result.json', 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    html = ''
    for item in data[:3]:
        title = item.get('title', '').replace('<', '&lt;').replace('>', '&gt;').replace('"', '&quot;').replace("'", "''")
        date_str = item.get('date', '')[:10]
        content_text = item.get('content', '')[:600].replace('<', '&lt;').replace('>', '&gt;').replace('"', '&quot;').replace("'", "''")
        website = item.get('website', '未知来源')
        html += f'<li><strong>{title}</strong><br>{content_text}<br><small>来源：{website} | {date_str}</small></li>\n'
    
    print(html)
except Exception as e:
    print(f'<li><strong>搜索错误</strong><br>{str(e)}<br><small>来源：系统</small></li>')
PYTHON_SCRIPT
)
else
    echo "百度搜索失败" | tee -a "$LOG_FILE"
    Baidu_CONTENT="<li><strong>备用内容</strong><br>AI技术正在快速发展中。<br><small>来源：备用</small></li>"
fi

# 使用 Tavily 搜索获取概览
echo "正在执行Tavily搜索..." | tee -a "$LOG_FILE"
TAVILY_RESULT=$(timeout 60 /root/.nvm/versions/node/v22.22.1/bin/node /root/.openclaw/workspace/skills/tavily-search/scripts/search.mjs "人工智能 AI 最新动态" --topic general -n 2 2>/dev/null)

if [ $? -eq 0 ] && echo "$TAVILY_RESULT" | grep -q "## Answer"; then
    echo "Tavily搜索成功" | tee -a "$LOG_FILE"
    Tavily_CONTENT=$(echo "$TAVILY_RESULT" | sed -n '/## Answer/,/## Sources/p' | tail -n +2 | head -n -1 | tr '\n' ' | sed 's/  */ /g' | head -c 800)
else
    echo "Tavily搜索失败" | tee -a "$LOG_FILE"
    Tavily_CONTENT="AI技术持续快速发展，各大科技公司不断推出新的产品和服务。"
fi

echo "步骤2: 生成文章..." | tee -a "$LOG_FILE"

# 转义单引号
Baidu_CONTENT_ESCAPED=$(echo "$Baidu_CONTENT" | sed "s/'/''/g")
Tavily_CONTENT_ESCAPED=$(echo "$Tavily_CONTENT" | sed "s/'/''/g")

SQL_FILE="/tmp/blog_${RANDOM}.sql"

# 生成文章内容
ARTICLE_CONTENT="<article>
  <h2>从多模态革命到智能体时代</h2>
  <p>今天是${TODAY}，欢迎来到今天的 AI 每日资讯！</p>

  <h3>📰 行业动态概览 (Tavily搜索)</h3>
  <p>${Tavily_CONTENT_ESCAPED}</p>

  <h3>🔍 详细资讯 (百度搜索)</h3>
  <ul>
    ${Baidu_CONTENT_ESCAPED}
  </ul>

  <h3>🛠️ 新工具推荐</h3>
  <ul>
    <li><strong>Claude Code</strong><br>Anthropic 推出的 AI 编程工具，支持多种编程语言和框架。</li>
    <li><strong>Cursor</strong><br>AI原生的代码编辑器，提供智能补全和代码解释功能。</li>
    <li><strong>GitHub Copilot</strong><br>GitHub 推出的 AI 编程助手，集成在IDE中提供实时建议。</li>
  </ul>

  <h3>🤖 模型更新</h3>
  <ul>
    <li><strong>开源模型</strong><br>Llama 3、Mistral、Qwen 等开源大模型性能持续提升。</li>
    <li><strong>模型能力</strong><br>各大公司持续突破模型能力限制。</li>
  </ul>

  <p style=\"color: #666; font-size:0.9em; margin-top:30px;\">
    📅 ${DATE_SHORT} ${TIME_NOW} | 🤖 由CrazyClaw自动生成 | 🔍 百度+Tavily搜索 | 📍 重庆
  </p>
</article>"

# 创建SQL
echo "INSERT INTO wp_posts
(post_author, post_date, post_date_gmt, post_content, post_title, post_excerpt,
post_status, comment_status, ping_status, post_password, post_name, to_ping, pinged,
post_modified, post_modified_gmt, post_content_filtered, post_parent, guid,
menu_order, post_type, post_mime_type, comment_count)
VALUES
(1, NOW(), UTC_TIMESTAMP(),
'\$ARTICLE_CONTENT',
'\$TITLE', '', 'publish', 'open', 'open', '', '\$SLUG', '', '',
NOW(), UTC_TIMESTAMP(), '', 0, 'http://42.193.14.72:8081/?p=999', 0, 'post', '', 0);" > "$SQL_FILE"

# 替换变量
sed -i "s/\\\$ARTICLE_CONTENT/$ARTICLE_CONTENT/g" "$SQL_FILE"
sed -i "s/\\\$TITLE/$TITLE/g" "$SQL_FILE"
sed -i "s/\\\$SLUG/$SLUG/g" "$SQL_FILE"

echo "步骤3: 发布到WordPress..." | tee -a "$LOG_FILE"

# 发布
docker exec -i wordpress-db mariadb -u wordpress_user -pREDACTED_DB_PASSWORD wordpress < "$SQL_FILE" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "✓ 发布成功！" | tee -a "$LOG_FILE"
    LATEST_ID=$(docker exec wordpress-db mariadb -u wordpress_user -pREDACTED_DB_PASSWORD wordpress -e "SELECT MAX(ID) FROM wp_posts;" 2>/dev/null | tail -1)
    rm -f "$SQL_FILE" /tmp/baidu_result.json
    docker exec wordpress service apache2.reload > /dev/null 2>&1
    echo "========================================" | tee -a "$LOG_FILE"
    echo "✅ 博客已发布" | tee -a "$LOG_FILE"
    echo "📰 标题: $TITLE" | tee -a "$LOG_FILE"
    echo "🔗 地址: http://42.193.14.72:8081/?p=$LATEST_ID" | tee -a "$LOG_FILE"
else
    echo "✗ 发布失败" | tee -a "$LOG_FILE"
    rm -f "$SQL_FILE" /tmp/baidu_result.json
    exit 1
fi
