#!/bin/bash
# WordPress 自动发布脚本
# 解决 SQL 转义问题,使用文件方式

set -e

# 配置
DB_PASSWORD="WpP@ss5691577"
DB_USER="wordpress_user"
DB_NAME="wordpress"
WP_URL="http://42.193.14.72:8081"
TITLE="$1"
CONTENT="$2"

# 生成 slug
SLUG=$(echo "$TITLE" | iconv -t ASCII//TRANSLIT | sed 's/[^a-zA-Z0-9]/-/g' | tr '[:upper:]' '[:lower:]' | sed 's/-\+/-/g' | sed 's/^-//;s/-$//')

if [ -z "$SLUG" ]; then
    SLUG="post-$(date +%s)"
fi

echo "正在发布文章..."
echo "标题: $TITLE"
echo "Slug: $SLUG"

# 使用 docker exec with heredoc
docker exec wordpress-db mariadb -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" << EOSQL
INSERT INTO wp_posts 
(post_author, post_date, post_date_gmt, post_content, post_title, post_excerpt, 
post_status, comment_status, ping_status, post_password, post_name, to_ping, pinged, 
post_modified, post_modified_gmt, post_content_filtered, post_parent, guid, 
menu_order, post_type, post_mime_type, comment_count)
VALUES 
(1, NOW(), UTC_TIMESTAMP(), 
'$CONTENT', 
'', '$TITLE', '', 'publish', 'open', 'open', '', 
'$SLUG', '', '', NOW(), UTC_TIMESTAMP(), '', 0, 
'$WP_URL/?p=999', 0, 'post', '', 0);
EOSQL

if [ $? -eq 0 ]; then
    echo "✓ 文章发布成功！"
    
    # 获取最新文章ID
    LATEST_ID=$(docker exec wordpress-db mariadb -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -N -B -e "SELECT MAX(ID) FROM wp_posts WHERE post_type='post';" 2>/dev/null | tail -1)
    
    echo "文章ID: $LATEST_ID"
    echo "访问地址: $WP_URL/?p=$LATEST_ID"
    echo "后台编辑: $WP_URL/wp-admin/post.php?post=$LATEST_ID&action=edit"
    
    # 刷新 Apache 缓存
    docker exec wordpress service apache2 reload > /dev/null 2>&1
    echo "✓ 缓存已刷新"
else
    echo "✗ 发布失败"
    exit 1
fi
