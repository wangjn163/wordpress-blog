#!/bin/bash
# 博客自动生成健康检查
# 每小时检查博客生成是否成功

LOG_FILE="/var/log/blog-health-check.log"
WORKSPACE="/root/.openclaw/workspace"

echo "========================================" >> "$LOG_FILE"
echo "健康检查时间: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"

# 获取当前小时
CURRENT_HOUR=$(date '+%H')
CURRENT_DATE=$(date '+%Y-%m-%d')

echo "检查时间范围: $CURRENT_DATE $CURRENT_HOUR:00" >> "$LOG_FILE"

# 检查最近1小时内是否有新文章发布
echo "正在检查最近的文章..." >> "$LOG_FILE"

RECENT_POSTS=$(docker exec wordpress-db mariadb -u wordpress_user -pREDACTED_DB_PASSWORD wordpress -N -e "SELECT COUNT(*) FROM wp_posts WHERE post_date >= DATE_SUB(NOW(), INTERVAL 2 HOUR) AND post_status='publish' AND post_type='post';" 2>/dev/null)

echo "最近2小时内发布的文章数: $RECENT_POSTS" >> "$LOG_FILE"

# 获取最新的文章信息
LATEST_POST=$(docker exec wordpress-db mariadb -u wordpress_user -pREDACTED_DB_PASSWORD wordpress -e "SELECT ID, post_title, post_date FROM wp_posts WHERE post_status='publish' AND post_type='post' ORDER BY post_date DESC LIMIT 1;" 2>/dev/null)

echo "最新文章:" >> "$LOG_FILE"
echo "$LATEST_POST" >> "$LOG_FILE"

# 检查日志中的错误
echo "正在检查生成日志中的错误..." >> "$LOG_FILE"
ERROR_COUNT=$(tail -100 /var/log/blog-auto-generate.log | grep -c "✗\|失败\|错误\|Error" || echo "0")
echo "发现错误数量: $ERROR_COUNT" >> "$LOG_FILE"

if [ "$ERROR_COUNT" -gt 0 ]; then
    echo "⚠️  警告：发现 $ERROR_COUNT 个错误" >> "$LOG_FILE"
    echo "最近的错误信息:" >> "$LOG_FILE"
    tail -50 /var/log/blog-auto-generate.log | grep -A 2 "✗\|失败\|错误\|Error" | tail -20 >> "$LOG_FILE"
fi

# 统计今天的文章数量
TODAY_COUNT=$(docker exec wordpress-db mariadb -u wordpress_user -pREDACTED_DB_PASSWORD wordpress -N -e "SELECT COUNT(*) FROM wp_posts WHERE DATE(post_date) = CURDATE() AND post_status='publish' AND post_type='post';" 2>/dev/null)

echo "今天已发布的文章总数: $TODAY_COUNT" >> "$LOG_FILE"

# 状态判断
if [ "$TODAY_COUNT" -eq 0 ]; then
    echo "❌ 状态：异常 - 今天还没有文章发布" >> "$LOG_FILE"
    STATUS="❌ 异常"
elif [ "$TODAY_COUNT" -lt $((10#$(date +%H) / 2 + 1)) ]; then
    echo "⚠️  状态：警告 - 文章数量低于预期" >> "$LOG_FILE"
    STATUS="⚠️  警告"
else
    echo "✅ 状态：正常 - 博客生成运行良好" >> "$LOG_FILE"
    STATUS="✅ 正常"
fi

echo "========================================" >> "$LOG_FILE"

# 输出到控制台（用于 heartbeat 检查）
echo "博客健康检查: $STATUS"
echo "  - 今天文章数: $TODAY_COUNT"
echo "  - 最近2小时: $RECENT_POSTS 篇"
echo "  - 错误数量: $ERROR_COUNT"

# 如果有异常，返回非零退出码
if [ "$STATUS" = "❌ 异常" ]; then
    exit 1
fi
