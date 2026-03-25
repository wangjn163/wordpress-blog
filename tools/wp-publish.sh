#!/bin/bash
# WordPress 文章发布工具
# 使用方法: ./wp-publish.sh "文章标题" "文章内容(HTML格式)"

DB_PASSWORD="REDACTED_DB_PASSWORD"
DB_USER="wordpress_user"
DB_NAME="wordpress"
WP_URL="http://42.193.14.72:8081"

if [ -z "$1" ]; then
  echo "用法: $0 \"文章标题\" \"文章内容(HTML)\""
  echo ""
  echo "示例:"
  echo "  $0 \"我的新文章\" \"<h2>标题</h2><p>内容</p>\""
  echo ""
  echo "或者从文件发布:"
  echo "  $0 \"文章标题\" \"\$(cat article.html)\""
  exit 1
fi

TITLE="$1"
CONTENT="$2"
SLUG="ai-news-$(date +%Y%m%d%H%M%S)"

echo "正在发布文章..."
echo "标题: $TITLE"
echo ""

# 使用环境变量传递内容，避免 heredoc 转义问题
export WP_PUBLISH_TITLE="$TITLE"
export WP_PUBLISH_CONTENT="$CONTENT"
export WP_PUBLISH_SLUG="$SLUG"

docker exec wordpress-db mariadb -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "INSERT INTO wp_posts (post_author, post_date, post_date_gmt, post_content, post_title, post_excerpt, post_status, comment_status, ping_status, post_password, post_name, to_ping, pinged, post_modified, post_modified_gmt, post_content_filtered, post_parent, guid, menu_order, post_type, post_mime_type, comment_count) VALUES (1, NOW(), UTC_TIMESTAMP(), '\${WP_PUBLISH_CONTENT}', '\${WP_PUBLISH_TITLE}', '', 'publish', 'open', 'open', '', '\${WP_PUBLISH_SLUG}', '', '', NOW(), UTC_TIMESTAMP(), '', 0, '$WP_URL/?p=999', 0, 'post', '', 0);" 2>&1

if [ $? -eq 0 ]; then
  echo "✓ 文章发布成功！"
  echo ""
  # 获取最新文章ID
  LATEST_ID=$(docker exec wordpress-db mariadb -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "SELECT MAX(ID) FROM wp_posts;" 2>/dev/null | tail -1)
  echo "文章ID: $LATEST_ID"
  echo "访问地址: $WP_URL/?p=$LATEST_ID"
  echo ""
  # 刷新 Apache 缓存
  docker exec wordpress service apache2 reload > /dev/null 2>&1
  echo "✓ 缓存已刷新"
else
  echo "✗ 发布失败"
  exit 1
fi
