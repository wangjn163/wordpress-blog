# WordPress 文章发布模板

## 使用方法
调用此模板发布文章到 WordPress

## 文章内容模板

```
标题：[文章标题]

<!--more-->

<h2>[小节标题1]</h2>
<p>[内容段落1]</p>

<h2>[小节标题2]</h2>
<p>[内容段落2]</p>

<h3>[子标题]</h3>
<p>[内容段落3]</p>

<h2>[小节标题3]</h2>
<ul>
<li>[列表项1]</li>
<li>[列表项2]</li>
</ul>

<h2>引用</h2>
<blockquote>
<p>[引用内容]</p>
<p>-- [引用来源]</p>
</blockquote>

<p>(完)</p>
```

## 数据库命令模板

```sql
-- 创建新文章
INSERT INTO wp_posts 
(post_author, post_date, post_date_gmt, post_content, post_title, post_excerpt, 
post_status, comment_status, ping_status, post_password, post_name, to_ping, pinged, 
post_modified, post_modified_gmt, post_content_filtered, post_parent, guid, 
menu_order, post_type, post_mime_type, comment_count)
VALUES 
(1, NOW(), UTC_TIMESTAMP(), 
'[HTML内容]', 
'', '[文章标题]', '', 'publish', 'open', 'open', '', 
'[文章slug]', '', '', NOW(), UTC_TIMESTAMP(), '', 0, 
'http://42.193.14.72:8081/?p=[ID]', 0, 'post', '', 0);

-- 更新现有文章
UPDATE wp_posts SET 
post_title = '[新标题]',
post_content = '[新HTML内容]',
post_name = '[新slug]'
WHERE ID = [文章ID];

-- 删除文章
DELETE FROM wp_posts WHERE ID = [文章ID];
```

## 常用 HTML 标签

```html
<!-- 标题 -->
<h1>一级标题</h1>
<h2>二级标题</h2>
<h3>三级标题</h3>
<h4>四级标题</h4>

<!-- 段落 -->
<p>段落内容</p>

<!-- 列表 -->
<ul>
  <li>无序列表项</li>
  <li>另一项</li>
</ul>

<ol>
  <li>有序列表项</li>
  <li>另一项</li>
</ol>

<!-- 引用 -->
<blockquote>
  <p>引用内容</p>
  <p>-- 来源</p>
</blockquote>

<!-- 代码 -->
<pre><code>代码内容</code></pre>

<!-- 链接 -->
<a href="链接地址">链接文字</a>

<!-- 图片 -->
<img src="图片地址" alt="描述">

<!-- 分隔线 -->
<hr>
```

## 发布示例

```bash
# 方法1: 直接通过数据库发布
docker exec wordpress-db mariadb -u wordpress_user -p'REDACTED_DB_PASSWORD' wordpress << 'EOF'
INSERT INTO wp_posts 
(post_author, post_date, post_date_gmt, post_content, post_title, post_excerpt, 
post_status, comment_status, ping_status, post_password, post_name, to_ping, pinged, 
post_modified, post_modified_gmt, post_content_filtered, post_parent, guid, 
menu_order, post_type, post_mime_type, comment_count)
VALUES 
(1, NOW(), UTC_TIMESTAMP(), 
'<h2>文章标题</h2><p>文章内容</p>', 
'', '我的文章', '', 'publish', 'open', 'open', '', 
'my-article', '', '', NOW(), UTC_TIMESTAMP(), '', 0, 
'http://42.193.14.72:8081/?p=999', 0, 'post', '', 0);
EOF

# 方法2: 更新现有文章
docker exec wordpress-db mariadb -u wordpress_user -p'REDACTED_DB_PASSWORD' wordpress << 'EOF'
UPDATE wp_posts SET 
post_content = '<h2>新内容</h2><p>更新后的文章</p>'
WHERE ID = 9;
EOF

# 刷新缓存
docker exec wordpress service apache2 reload
```

## 快速操作

```bash
# 查看所有文章
docker exec wordpress-db mariadb -u wordpress_user -p'REDACTED_DB_PASSWORD' wordpress -e "SELECT ID, post_title, post_status FROM wp_posts WHERE post_type='post' ORDER BY ID DESC;"

# 查看最新文章ID
docker exec wordpress-db mariadb -u wordpress_user -p'REDACTED_DB_PASSWORD' wordpress -e "SELECT MAX(ID) FROM wp_posts;"

# 访问文章
curl http://42.193.14.72:8081/?p=[文章ID]
```
