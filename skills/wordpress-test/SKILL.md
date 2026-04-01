# WordPress 测试技能

本技能用于快速测试WordPress站点功能和排查问题。

## 测试命令

### 1. 测试首页
```bash
curl -I http://localhost:8081/
```

### 2. 测试单篇文章页
```bash
curl -I http://localhost:8081/2026/03/23/ai-frontier-multimodal-agents-1774227907/
```

### 3. 测试分页
```bash
curl -I http://localhost:8081/page/2/
```

### 4. 检查PHP错误日志
```bash
docker logs wordpress --tail 50 | grep -i "error\|fatal"
```

### 5. 检查WordPress容器状态
```bash
docker ps | grep wordpress
```

### 6. 测试AJAX评论
```bash
curl -X POST http://localhost:8081/wp-admin/admin-ajax.php \
  -d "action=ajax_comment_submit" \
  -d "comment_post_ID=10" \
  -d "author=测试" \
  -d "email=test@example.com" \
  -d "comment=测试评论"
```

### 7. 检查插件激活状态
```bash
docker exec wordpress php -r "
require_once('/var/www/html/wp-load.php');
\$plugins = get_option('active_plugins');
print_r(\$plugins);
"
```

### 8. 检查文章列表
```bash
docker exec wordpress-db mariadb -uwordpress_user -p$DB_PASSWORD wordpress -e "SELECT ID, post_title, post_status FROM wp_posts WHERE post_type='post' ORDER BY ID DESC;"
```

### 9. 测试评论功能
```bash
docker exec wordpress php -r "
require_once('/var/www/html/wp-load.php');
\$comments = get_comments(array('count' => true));
echo '总评论数: ' . \$comments . '\n';
"
```

### 10. 重启WordPress服务
```bash
docker restart wordpress
```

### 11. 验证AI评论回复率
```bash
docker exec wordpress php -r "
require_once('/var/www/html/wp-load.php');
\$unreplied = get_comments(array('status' => 'approve', 'parent' => 0));
\$total = 0;
\$replied = 0;
foreach (\$unreplied as \$comment) {
    if (\$comment->comment_author === get_option('blogname')) continue;
    \$total++;
    \$has_reply = get_comments(array('parent' => \$comment->comment_ID, 'count' => true));
    if (\$has_reply > 0) \$replied++;
}
echo \"用户评论: \$total\n\";
echo \"已回复: \$replied\n\";
echo \"回复率: \" . (\$total > 0 ? round(\$replied/\$total*100, 1) : 0) . \"%\n\";
"
```

### 12. 列出所有未回复的用户评论
```bash
docker exec wordpress php -r "
\$mysqli = new mysqli('wordpress-db', 'wordpress_user', $DB_PASSWORD, 'wordpress');
\$result = \$mysqli->query(\"SELECT comment_ID, comment_author, comment_content, comment_date FROM wp_comments WHERE comment_approved='1' AND comment_parent=0 ORDER BY comment_date DESC\");
echo '未回复评论列表：\n';
echo '===================================\n';
\$has_unreplied = false;
while (\$row = \$result->fetch_assoc()) {
    if (\$row['comment_author'] === 'AI爱好者') continue;
    \$check = \$mysqli->query(\"SELECT COUNT(*) as cnt FROM wp_comments WHERE comment_parent=\" . \$row['comment_ID']);
    \$reply_cnt = \$check->fetch_assoc()['cnt'];
    if (\$reply_cnt == 0) {
        printf(\"❌ ID:%d | %s | %s | %s\n\", \$row['comment_ID'], \$row['comment_author'], \$row['comment_content'], \$row['comment_date']);
        \$has_unreplied = true;
    }
}
if (!\$has_unreplied) echo \"✅ 所有用户评论都已回复！\n\";
\$mysqli->close();
"
```

### 13. 检查系统定时任务状态
```bash
# 查看 WordPress cron 任务列表
docker exec wordpress php -r "
require_once('/var/www/html/wp-load.php');
\$crons = _get_cron_array();
echo '定时任务列表：\n';
foreach (\$crons as \$timestamp => \$hooks) {
    echo date('Y-m-d H:i:s', \$timestamp) . \"\n\";
    foreach (\$hooks as \$hook => \$details) {
        echo \"  ⏰ \$hook\n\";
    }
}
"

# 检查系统级 cron（宿主机）
crontab -l | grep wordpress
```

### 14. 查看评论回复详情
```bash
docker exec wordpress php -r "
\$mysqli = new mysqli('wordpress-db', 'wordpress_user', $DB_PASSWORD, 'wordpress');
\$result = \$mysqli->query(\"SELECT c1.comment_ID, c1.comment_author, c1.comment_content, c1.comment_date, c2.comment_ID as reply_id, c2.comment_content as reply_content FROM wp_comments c1 LEFT JOIN wp_comments c2 ON c2.comment_parent = c1.comment_ID WHERE c1.comment_approved='1' AND c1.comment_parent=0 ORDER BY c1.comment_date DESC LIMIT 10\");
echo '评论及回复情况：\n';
echo '===================================\n';
while (\$row = \$result->fetch_assoc()) {
    printf(\"ID:%d | %s: %s\n\", \$row['comment_ID'], \$row['comment_author'], \$row['comment_content']);
    if (\$row['reply_id']) {
        printf(\"  └─ AI回复: %s\n\", \$row['reply_content']);
    } else {
        printf(\"  └─ ❌ 未回复\n\");
    }
    echo \"\n\";
}
\$mysqli->close();
"
```

## 常见问题排查

### 致命错误
1. 检查PHP错误日志
2. 检查函数是否重复定义
3. 检查PHP内存限制

### 页面无法访问
1. 检查容器状态
2. 检查Apache配置
3. 检查端口映射

### 评论功能异常
1. 检查AJAX处理函数是否在functions.php中
2. 检查插件激活状态
3. 查看错误日志

## 快速修复命令

### 重载Apache
```bash
docker exec wordpress service apache2 reload
```

### 增加PHP内存
```bash
docker exec wordpress sh -c "echo 'memory_limit = 512M' > /usr/local/etc/php/conf.d/memory-limit.ini"
docker restart wordpress
```

### 清理缓存
```bash
docker exec wordpress sh -c "rm -rf /var/www/html/wp-content/cache/*"
```

## 测试流程

每次修改后建议按以下顺序测试：
1. 测试首页
2. 测试单篇文章页
3. 测试分页
4. 测试评论提交
5. 测试微信分享按钮
6. 检查错误日志

## AI评论回复系统专项测试

### 监控和诊断命令
```bash
# 1. 快速诊断（一键检查系统状态）
# 2. 检查回复率（命令11）
# 3. 列出未回复评论（命令12）
# 4. 查看评论详情（命令14）
# 5. 检查定时任务状态（命令13）
```

### 快速诊断
```bash
# 一键检查AI回复系统状态
docker exec wordpress php -r "
require_once('/var/www/html/wp-load.php');
echo '=== AI评论回复系统诊断 ===\n';
echo '站点名称: ' . get_option('blogname') . \"\n\";
echo '插件状态: ' . (is_plugin_active('ai-comment-reply/ai-comment-reply.php') ? '✅ 已激活' : '❌ 未激活') . \"\n\";
\$next = wp_next_scheduled('ai_comment_reply_cron');
echo '定时任务: ' . (\$next ? '✅ 已调度 (下次: ' . date('Y-m-d H:i:s', \$next) . ')' : '❌ 未调度') . \"\n\";
\$unreplied = get_comments(array('status' => 'approve', 'parent' => 0));
\$total = 0; \$replied = 0;
foreach (\$unreplied as \$comment) {
    if (\$comment->comment_author === get_option('blogname')) continue;
    \$total++;
    \$has_reply = get_comments(array('parent' => \$comment->comment_ID, 'count' => true));
    if (\$has_reply > 0) \$replied++;
}
echo \"\n统计：\n\";
echo \"用户评论总数: \$total\n\";
echo \"已回复: \$replied\n\";
echo \"未回复: \" . (\$total - \$replied) . \"\n\";
echo \"回复率: \" . (\$total > 0 ? round(\$replied/\$total*100, 1) : 0) . \"%\n\";
"
```
