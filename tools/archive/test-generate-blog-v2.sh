#!/bin/bash
LOG_FILE="/var/log/blog-auto-generate-test.log"
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

# 使用百度搜索并保存到临时文件
BAIDU_RESULT=$(timeout 60 python3 skills/baidu-search/scripts/search.py '{"query":"人工智能 AI news","count":3}' 2>&1)

# 检查搜索是否成功
if echo "$BAIDU_RESULT" | grep -q '"title"'; then
    echo "✓ 百度搜索成功" | tee -a "$LOG_FILE"

    # 将结果保存到临时文件
    echo "$BAIDU_RESULT" > /tmp/baidu_result.json

    # 解析百度搜索结果
    CONTENT=$(python3 << 'PYTHON_SCRIPT'
import json

try:
    with open('/tmp/baidu_result.json', 'r', encoding='utf-8') as f:
        data = json.load(f)

    html = ''
    for item in data[:3]:
        title = item.get('title', '未知标题').replace('<', '&lt;').replace('>', '&gt;').replace('"', '&quot;')
        date_str = item.get('date', '')[:10]
        content_text = item.get('content', '')[:500].replace('<', '&lt;').replace('>', '&gt;').replace('"', '&quot;')
        website = item.get('website', '未知来源')
        html += f'<li><strong>{title}</strong><br>{content_text}<br><small>来源：{website} | {date_str}</small></li>\n'

    print(html)
except Exception as e:
    print(f'<li><strong>解析错误</strong><br>{str(e)}<br><small>来源：系统</small></li>')
PYTHON_SCRIPT
)

    if [ -z "$CONTENT" ]; then
        CONTENT="<li><strong>备用内容</strong><br>AI技术正在快速发展中。<br><small>来源：备用</small></li>"
    fi
else
    echo "✗ 百度搜索失败，使用备用内容" | tee -a "$LOG_FILE"
    CONTENT="<li><strong>AI技术持续发展</strong><br>人工智能技术正在快速发展中，各大公司纷纷推出新的AI产品和服务。<br><small>来源：备用内容</small></li>"
fi

echo "搜索内容解析完成" | tee -a "$LOG_FILE"
echo "正在发布..." | tee -a "$LOG_FILE"

SQL_FILE="/tmp/blog_test_${RANDOM}.sql"

# 转义单引号
CONTENT_ESCAPED=$(echo "$CONTENT" | sed "s/'/''/g")

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
  <h2>🧪 测试博客 - 百度搜索集成测试</h2>
  <p>测试时间：$TODAY $TIME_NOW</p>

  <h3>🔍 百度搜索结果</h3>
  <ul>
    $CONTENT_ESCAPED
  </ul>

  <h3>📊 测试信息</h3>
  <ul>
    <li><strong>测试状态</strong><br>博客生成功能测试成功</li>
    <li><strong>搜索源</strong><br>百度搜索 (baidu-search skill)</li>
    <li><strong>数据来源</strong><br>百度 AI 搜索 API</li>
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
    rm -f "$SQL_FILE" /tmp/baidu_result.json
    echo "========================================" | tee -a "$LOG_FILE"
    echo "✅ 测试博客已发布" | tee -a "$LOG_FILE"
    echo "📰 标题: $TITLE" | tee -a "$LOG_FILE"
    echo "🔗 地址: http://42.193.14.72:8081/?p=$LATEST_ID" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    echo "🎉 博客生成功能测试完成！"
else
    echo "✗ 发布失败" | tee -a "$LOG_FILE"
    rm -f "$SQL_FILE" /tmp/baidu_result.json
    exit 1
fi
