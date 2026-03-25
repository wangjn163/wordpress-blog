#!/bin/bash
# WordPress 文章发布工具 (改进版)
# 位置: /opt/projects/blog/wordpress/publish.sh
# 使用方法: ./publish.sh "文章标题" "文章内容(HTML格式)"

set -e

# 配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="/opt/projects/blog/wordpress"
ENV_FILE="$PROJECT_ROOT/.env"

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 加载环境变量
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
else
    echo -e "${RED}错误: 找不到 .env 文件${NC}"
    echo "请创建 $ENV_FILE 并设置数据库密码"
    exit 1
fi

# 默认值(如果 .env 中没有设置)
DB_PASSWORD="${DB_PASSWORD:-REDACTED_DB_PASSWORD}"
DB_USER="${DB_USER:-wordpress_user}"
DB_NAME="${DB_NAME:-wordpress}"
WP_URL="${WP_URL:-http://42.193.14.72:8081}"

# 显示使用说明
show_usage() {
    echo "WordPress 文章发布工具"
    echo ""
    echo "用法:"
    echo "  $0 \"文章标题\" \"文章内容(HTML)\""
    echo ""
    echo "示例:"
    echo "  $0 \"我的新文章\" \"<h2>标题</h2><p>内容</p>\""
    echo ""
    echo "  # 从文件发布"
    echo "  $0 \"文章标题\" \"\$(cat article.html)\""
    echo ""
    echo "  # 使用模板文件"
    echo "  $0 \"文章标题\" \"\$(cat /root/.openclaw/workspace/tools/wp-publish-template.md)\""
    echo ""
    echo "配置文件: $ENV_FILE"
    exit 1
}

# 参数检查
if [ -z "$1" ]; then
    show_usage
fi

TITLE="$1"
CONTENT="${2:-}"

# 清理内容中的引号
CONTENT=$(echo "$CONTENT" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')

# 生成 slug
SLUG=$(echo "$TITLE" | iconv -t UTF-8 //TRANSLIT 2>/dev/null | sed 's/[^a-zA-Z0-9]/-/g' | tr '[:upper:]' '[:lower:]' | sed 's/-\+/-/g' | sed 's/^-//;s/-$//')

if [ -z "$SLUG" ]; then
    SLUG="post-$(date +%s)"
fi

echo -e "${YELLOW}=========================================="
echo "  发布文章到 WordPress"
echo "==========================================${NC}"
echo ""
echo "标题: $TITLE"
echo "Slug: $SLUG"
echo ""

# 确认发布
read -p "确认发布? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}已取消${NC}"
    exit 0
fi

# 插入文章
echo -e "${YELLOW}正在发布...${NC}"

SQL_QUERY="INSERT INTO wp_posts 
(post_author, post_date, post_date_gmt, post_content, post_title, post_excerpt, 
post_status, comment_status, ping_status, post_password, post_name, to_ping, pinged, 
post_modified, post_modified_gmt, post_content_filtered, post_parent, guid, 
menu_order, post_type, post_mime_type, comment_count)
VALUES 
(1, NOW(), UTC_TIMESTAMP(), 
'$CONTENT', 
'', '$TITLE', '', 'publish', 'open', 'open', '', 
'$SLUG', '', '', NOW(), UTC_TIMESTAMP(), '', 0, 
'$WP_URL/?p=999', 0, 'post', '', 0);"

# 执行 SQL
docker exec wordpress-db mariadb -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "$SQL_QUERY" 2>/dev/null

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ 文章发布成功！${NC}"
    echo ""
    
    # 获取最新文章ID
    LATEST_ID=$(docker exec wordpress-db mariadb -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "SELECT MAX(ID) FROM wp_posts WHERE post_type='post';" 2>/dev/null | tail -1)
    
    echo "文章ID: $LATEST_ID"
    echo "访问地址: $WP_URL/?p=$LATEST_ID"
    echo "后台编辑: $WP_URL/wp-admin/post.php?post=$LATEST_ID&action=edit"
    echo ""
    
    # 刷新 Apache 缓存
    docker exec wordpress service apache2 reload > /dev/null 2>&1
    echo -e "${GREEN}✓ 缓存已刷新${NC}"
else
    echo -e "${RED}✗ 发布失败${NC}"
    echo ""
    echo "请检查:"
    echo "1. 数据库连接是否正常"
    echo "2. WordPress 容器是否运行"
    echo "3. 数据库密码是否正确"
    exit 1
fi

echo ""
echo -e "${GREEN}=========================================="
echo "  发布完成!"
echo "==========================================${NC}"
