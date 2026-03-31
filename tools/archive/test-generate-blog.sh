#!/bin/bash
LOG_FILE="/var/log/blog-auto-generate-test.log"
export TAVILY_API_KEY="REDACTED_TAVILY_API_KEY"
export BAIDU_API_KEY="REDACTED_BAIDU_API_KEY"
cd /root/.openclaw/workspace || exit 1

TODAY=$(date '+%Y年%m月%d日')
DATE_SHORT=$(date '+%Y-%m-%d')
TIME_NOW=$(date '+%H:%M:%S')
TIMESTAMP=$(date '+%Y%m%d%H%M%S')
TITLE="AI 测试博客 – $TODAY $TIME_NOW"
SLUG="ai-test-$TIMESTAMP"

echo "========================================" | tee -a "$LOG_FILE"
echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$LOG_FILE"
echo "正在使用百度搜索..." | tee -a "$LOG_FILE"

# 使用百度搜索
BAIDU_RESULT=$(timeout 60 python3 skills/baidu-search/scripts/search.py '{"query":"人工智能 AI news","count":3}' 2>&1)

if [ $? -eq 0 ] && echo "$BAIDU_RESULT" | grep -q '"title"'; then
    echo "✓ 百度搜索成功" | tee -a "$LOG_FILE"

    # 解析百度搜索结果并生成HTML
    CONTENT=$(echo "$BAIDU_RESULT" | python3 -c "
import json, sys
data = json.load(sys.stdin)
html = ''
for item in data[:3]:
    title = item.get('title', '未知标题').replace('<', '&lt;').replace('>', '&gt;')
    url = item.get('url', '')
    date_str = item.get('date', '')[:10]
    content_text = item.get('content', '')[:500].replace('<', '&lt;').replace('>', '&gt;')
    website = item.get('website', '未知来源')
    html += f'<li><strong>{title}</strong><br>{content_text}<br><small>来源：{website} | {date_str}</small></li>'
print(html)
")

    if [ -z "$CONTENT" ]; then
        CONTENT="<li><strong>测试内容</strong><br>这是一个测试博客文章。<br><small>来源：测试</small></li>"
    fi
else
    echo "✗ 百度搜索失败，使用备用内容" | tee -a "$LOG_FILE"
    CONTENT="<li><strong>AI技术持续发展</strong><br>人工智能技术正在快速发展中，各大公司纷纷推出新的AI产品和服务。<br><small>来源：备用内容</small></li>"
fi

echo "正在发布..." | tee -a "$LOG_FILE"

SQL_FILE="/tmp/blog_test_${RANDOM}.sql"

# 创建文章
cat > "$SQL_FILE" << EOF
INSERT INTO wp_posts
(post_author, post_date, post_date_gmt, post_content, post_title, post_excerpt,
post_status, comment_status, ping_status, post_password, post_name, to_ping, pinged,
post_modified, post_modified_gmt, post_content_filtered, post_parent, guid,
menu_order, post_type, post_mime_type, comment_count)
VALUES
(1, NOW(), UTC_TIMESTAMP(),
'<article>
  <h2>🧪 测试博客</h2>
  <p>测试时间：$TODAY $TIME_NOW</p>

  <h3>搜索结果</h3>
  <ul>
    $CONTENT
  </ul>

  <h3>系统信息</h3>
  <ul>
    <li><strong>测试状态</strong><br>博客生成功能测试中</li>
    <li><strong>搜索源</strong><br>百度搜索 (baidu-search skill)</li>
  </ul>

  <p style="color: #666; font-size:0.9em; margin-top:30px;">
    📅 $DATE_SHORT $TIME_NOW | 🤖 由CrazyClaw自动生成 | 🔍 百度搜索 | 📍 重庆
  </p>
</article>',
'$TITLE', '', 'publish', 'open', 'open', '', '$SLUG', '', '',
NOW(), UTC_TIMESTAMP(), '', 0, 'http://42.193.14.72:8081/?p=999', 0, 'post', '', 0);
EOF

# 发布
docker exec -i wordpress-db mariadb -u wordpress_user -pREDACTED_DB_PASSWORD wordpress < "$SQL_FILE" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "✓ 发布成功！" | tee -a "$LOG_FILE"
    LATEST_ID=$(docker exec wordpress-db mariadb -u wordpress_user -pREDACTED_DB_PASSWORD wordpress -e "SELECT MAX(ID) FROM wp_posts;" 2>/dev/null | tail -1)
    rm -f "$SQL_FILE"
    echo "========================================" | tee -a "$LOG_FILE"
    echo "✅ 测试博客已发布" | tee -a "$LOG_FILE"
    echo "📰 标题: $TITLE" | tee -a "$LOG_FILE"
    echo "🔗 地址: http://42.193.14.72:8081/?p=$LATEST_ID" | tee -a "$LOG_FILE"
else
    echo "✗ 发布失败" | tee -a "$LOG_FILE"
    rm -f "$SQL_FILE"
    exit 1
fi
