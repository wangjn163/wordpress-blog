#!/bin/bash
# WordPress 文章发布工具 (改进版)
# 使用方法: ./wp-publish-v2.sh "文章标题" "文章内容(HTML格式)"

DB_PASSWORD="${DB_PASSWORD:-$(cat ~/.config/wordpress/db_password 2>/dev/null)}"
DB_USER="wordpress_user"
DB_NAME="wordpress"
WP_URL="http://42.193.14.72:8081"

if [ -z "$DB_PASSWORD" ]; then
  echo "错误: DB_PASSWORD 未设置，请设置环境变量或创建 ~/.config/wordpress/db_password"
  exit 1
fi

if [ -z "$1" ]; then
  echo "用法: $0 \"文章标题\" \"文章内容(HTML)\""
  exit 1
fi

TITLE="$1"
CONTENT="$2"
SLUG="ai-news-$(date +%Y%m%d%H%M%S)"

echo "正在发布文章..."
echo "标题: $TITLE"

# 转义单引号
CONTENT_ESCAPED=$(echo "$CONTENT" | sed "s/'/''/g")

# 创建临时SQL文件
SQL_FILE="/tmp/wp_publish_${RANDOM}.sql"

cat > "$SQL_FILE" << EOF
INSERT INTO wp_posts
(post_author, post_date, post_date_gmt, post_content, post_title, post_excerpt,
post_status, comment_status, ping_status, post_password, post_name, to_ping, pinged,
post_modified, post_modified_gmt, post_content_filtered, post_parent, guid,
menu_order, post_type, post_mime_type, comment_count)
VALUES
(1, NOW(), UTC_TIMESTAMP(),
'$CONTENT_ESCAPED',
'$TITLE', '', 'publish', 'open', 'open', '', '$SLUG', '', '',
NOW(), UTC_TIMESTAMP(), '', 0, '$WP_URL/?p=999', 0, 'post', '', 0);
EOF

# 执行SQL
docker exec -i wordpress-db mariadb -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" < "$SQL_FILE" 2>&1 > /dev/null

if [ $? -eq 0 ]; then
    echo "✓ 文章发布成功！"
    LATEST_ID=$(docker exec wordpress-db mariadb -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "SELECT MAX(ID) FROM wp_posts;" 2>/dev/null | tail -1)
    echo "文章ID: $LATEST_ID"
    echo "访问地址: $WP_URL/?p=$LATEST_ID"
    rm -f "$SQL_FILE"
    docker exec wordpress service apache2.reload > /dev/null 2>&1
else
    echo "✗ 发布失败"
    rm -f "$SQL_FILE"
    exit 1
fi
