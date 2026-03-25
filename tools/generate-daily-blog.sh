#!/bin/bash
# 每5分钟自动生成AI资讯博客
# 同时使用 Tavily 和 百度 搜索API获取真实的AI新闻

set -e

LOG_FILE="/var/log/blog-auto-generate.log"
WORKSPACE="/root/.openclaw/workspace"

# 设置 API Keys
export TAVILY_API_KEY="REDACTED_TAVILY_API_KEY"
export BAIDU_API_KEY="REDACTED_BAIDU_API_KEY"

echo "========================================" >> "$LOG_FILE"
echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"

cd "$WORKSPACE"

# 生成今日日期和时间段
TODAY=$(date '+%Y年%m月%d日')
DATE_SHORT=$(date '+%Y-%m-%d')
TIME_NOW=$(date '+%H:%M:%S')
HOUR=$(date '+%H')
MINUTE=$(date '+%M')
TITLE="AI资讯 - ${TODAY} ${HOUR}时${MINUTE}分"
SLUG="ai-news-$(date +%Y%m%d%H%M%S)"

echo "步骤1: 搜索AI新闻（百度+Tavily）..." >> "$LOG_FILE"

# 生成时间戳
TIMESTAMP=$(date '+%Y年%m月%d日 %H时%M分')

# 并行搜索两个引擎
# 获取今天的日期范围（用于搜索过滤）
TODAY_START=$(date '+%Y-%m-%d')
TODAY_END=$(date '+%Y-%m-%d' -d '+1 day')

# 1. 百度搜索（中文）- 限定今天
timeout 30 python3 /root/.openclaw/workspace/skills/baidu-search/scripts/search.py "{\"query\":\"AI人工智能 最新新闻\",\"freshness\":\"${TODAY_START}to${TODAY_END}\",\"count\":3}" 2>/dev/null | tail -n +2 > /tmp/baidu_result.json || echo "[]" > /tmp/baidu_result.json

# 2. Tavily搜索（英文）- 限定今天
timeout 30 /root/.nvm/versions/node/v22.22.1/bin/node /root/.openclaw/workspace/skills/tavily-search/scripts/search.mjs "AI人工智能 最新新闻 $TODAY_START" --topic general -n 3 > /tmp/tavily_result.txt 2>&1 || echo "Tavily搜索失败" > /tmp/tavily_result.txt

# 处理百度搜索结果
BAIDU_CONTENT=""
# 检查是否有JSON数组（以 [{ 开头）
if grep -q "^\[\$" /tmp/baidu_result.json 2>/dev/null; then
    echo "百度搜索成功" >> "$LOG_FILE"
    # 直接使用jq提取（精简内容）
    if command -v jq >/dev/null 2>&1; then
        BAIDU_CONTENT=$(jq -r '.[0] | "<strong>【百度】\(.title)</strong><br>\(.content[:300])...<br><small>来源：百度搜索</small>"' /tmp/baidu_result.json 2>>"$LOG_FILE")
    else
        # 备用方案：使用sed提取
        BAIDU_CONTENT=$(sed -n '/"title"/p' /tmp/baidu_result.json | head -1 | sed 's/.*"title"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/<strong>【百度】\1<\/strong><br>/')
        BAIDU_CONTENT="$BAIDU_CONTENT$(sed -n '/"content"/p' /tmp/baidu_result.json | head -1 | sed 's/.*"content"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1...<br><small>来源：百度搜索<\/small>/')"
    fi
    echo "提取的百度内容长度: ${#BAIDU_CONTENT}" >> "$LOG_FILE"
else
    echo "百度搜索失败或无结果" >> "$LOG_FILE"
fi

# 处理Tavily搜索结果
TAVILY_CONTENT=""
if grep -q "## Answer" /tmp/tavily_result.txt; then
    echo "Tavily搜索成功" >> "$LOG_FILE"
    TAVILY_ANSWER=$(sed -n '/## Answer/,/## Sources/p' /tmp/tavily_result.txt | tail -n +2 | head -n -1 | tr '\n' ' ' | sed 's/  */ /g')
    TAVILY_CONTENT="<strong>【Tavily】国际AI动态</strong><br>$TAVILY_ANSWER<br><small>来源：Tavily搜索</small>"
else
    echo "Tavily搜索失败或无结果" >> "$LOG_FILE"
fi

# 组合搜索结果
if [ -n "$BAIDU_CONTENT" ] && [ -n "$TAVILY_CONTENT" ]; then
    # 两个都有结果
    ANSWER="$BAIDU_CONTENT<br><br>$TAVILY_CONTENT"
    HAS_ENGLISH=1
    CHINESE_TRANSLATION="$BAIDU_CONTENT"
elif [ -n "$BAIDU_CONTENT" ]; then
    # 只有百度
    ANSWER="$BAIDU_CONTENT"
    HAS_ENGLISH=0
    CHINESE_TRANSLATION=""
elif [ -n "$TAVILY_CONTENT" ]; then
    # 只有Tavily
    ANSWER="$TAVILY_CONTENT"
    HAS_ENGLISH=1
    CHINESE_TRANSLATION=""
else
    # 都失败
    ANSWER="AI技术持续快速发展，各大科技公司不断推出新的产品和服务。"
    HAS_ENGLISH=0
    CHINESE_TRANSLATION=""
fi

echo "步骤2: 生成文章内容..." >> "$LOG_FILE"

# 创建博客内容（完全动态，只保留基础结构）
SQL_ID="${RANDOM}"
TEMP_SQL="/tmp/blog_insert_${SQL_ID}.sql"

if [ "$HAS_ENGLISH" -eq 1 ] && [ -n "$CHINESE_TRANSLATION" ]; then
    # 包含英文内容，显示英汉对照
    cat > "$TEMP_SQL" << EOSQL
INSERT INTO wp_posts
(post_author, post_date, post_date_gmt, post_content, post_title, post_excerpt,
post_status, comment_status, ping_status, post_password, post_name, to_ping, pinged,
post_modified, post_modified_gmt, post_content_filtered, post_parent, guid,
menu_order, post_type, post_mime_type, comment_count)
VALUES
(1, NOW(), UTC_TIMESTAMP(),
'<article>
  <h2>🤖 AI资讯速递</h2>
  <p>今天是TODAY_PLACEHOLDER HOUR_PLACEHOLDER时MINUTE_PLACEHOLDER分，以下是最新的AI行业动态。</p>

  <h3>📰 最新资讯（多源聚合）</h3>
  ANSWER_PLACEHOLDER

  <p style="color: #888; font-size: 0.9em; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee;">
    📅 DATE_PLACEHOLDER TIME_PLACEHOLDER | 🤖 由CrazyClaw自动生成 | 🔍 百度+Tavily搜索 | 📍 重庆
  </p>
</article>',
'TITLE_PLACEHOLDER', '', 'publish', 'open', 'open', '', 'SLUG_PLACEHOLDER', '', '',
NOW(), UTC_TIMESTAMP(), '', 0, 'http://42.193.14.72:8081/?p=999', 0, 'post', '', 0);
EOSQL
else
    # 纯内容
    cat > "$TEMP_SQL" << EOSQL
INSERT INTO wp_posts
(post_author, post_date, post_date_gmt, post_content, post_title, post_excerpt,
post_status, comment_status, ping_status, post_password, post_name, to_ping, pinged,
post_modified, post_modified_gmt, post_content_filtered, post_parent, guid,
menu_order, post_type, post_mime_type, comment_count)
VALUES
(1, NOW(), UTC_TIMESTAMP(),
'<article>
  <h2>🤖 AI资讯速递</h2>
  <p>今天是TODAY_PLACEHOLDER HOUR_PLACEHOLDER时MINUTE_PLACEHOLDER分，以下是最新的AI行业动态。</p>

  <h3>📰 最新资讯（多源聚合）</h3>
  ANSWER_PLACEHOLDER

  <p style="color: #888; font-size: 0.9em; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee;">
    📅 DATE_PLACEHOLDER TIME_PLACEHOLDER | 🤖 由CrazyClaw自动生成 | 🔍 百度+Tavily搜索 | 📍 重庆
  </p>
</article>',
'TITLE_PLACEHOLDER', '', 'publish', 'open', 'open', '', 'SLUG_PLACEHOLDER', '', '',
NOW(), UTC_TIMESTAMP(), '', 0, 'http://42.193.14.72:8081/?p=999', 0, 'post', '', 0);
EOSQL
fi

# 替换占位符（使用 | 作为分隔符避免冲突）
sed -i "s|TODAY_PLACEHOLDER|${TODAY}|g; s|DATE_PLACEHOLDER|${DATE_SHORT}|g; s|HOUR_PLACEHOLDER|${HOUR}|g; s|MINUTE_PLACEHOLDER|${MINUTE}|g; s|TIME_PLACEHOLDER|${TIME_NOW}|g; s|TITLE_PLACEHOLDER|${TITLE}|g; s|SLUG_PLACEHOLDER|${SLUG}|g" "$TEMP_SQL"

# 替换答案内容（使用Python脚本处理特殊字符）
export ANSWER_TEXT="$ANSWER"
export SQL_ID="$SQL_ID"
python3 /tmp/escape_answer.py

echo "步骤3: 发布到WordPress..." >> "$LOG_FILE"

# 发布到WordPress
docker exec -i wordpress-db mariadb -u wordpress_user -pREDACTED_DB_PASSWORD wordpress < "$TEMP_SQL" >> "$LOG_FILE" 2>&1

if [ $? -eq 0 ]; then
    echo "✓ 博客发布成功！" >> "$LOG_FILE"
    LATEST_ID=$(docker exec wordpress-db mariadb -u wordpress_user -pREDACTED_DB_PASSWORD wordpress -e "SELECT MAX(ID) FROM wp_posts;" 2>/dev/null | tail -1)
    echo "文章ID: $LATEST_ID" >> "$LOG_FILE"
    echo "文章地址: http://42.193.14.72:8081/?p=$LATEST_ID" >> "$LOG_FILE"
    docker exec wordpress service apache2 reload > /dev/null 2>&1
    echo "✓ 缓存已刷新" >> "$LOG_FILE"
    rm -f "$TEMP_SQL" /tmp/tavily_result.txt /tmp/baidu_result.json
else
    echo "✗ 博客发布失败" >> "$LOG_FILE"
    rm -f "$TEMP_SQL" /tmp/tavily_result.txt /tmp/baidu_result.json
    exit 1
fi

echo "完成时间: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"

# 输出成功消息
echo "✅ 博客已生成并发布"
echo "📰 标题: $TITLE"
echo "🔗 地址: http://42.193.14.72:8081/?p=$LATEST_ID"
echo "🔍 使用 百度+Tavily 双引擎搜索"
