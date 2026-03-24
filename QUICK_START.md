# 📝 WordPress 博客快速发布指南

## 🎯 两种发布方式

### 方式一: 使用脚本发布 ⚡

```bash
# 1. 进入项目目录
cd /opt/projects/blog/wordpress

# 2. 发布文章
./publish.sh "文章标题" "<h2>副标题</h2><p>文章内容...</p>"

# 3. 或从文件发布
./publish.sh "文章标题" "$(cat /path/to/article.html)"
```

### 方式二: 使用 WordPress 后台 🖥️

1. 访问: `http://42.193.14.72:8081/wp-admin`
2. 登录 (admin / 你的密码)
3. 点击 "文章" → "写文章"
4. 编辑并发布

---

## 📋 标准文章格式

### HTML 格式 (推荐)

```html
<h2>副标题(可选)</h2>

<p>这里是文章正文...</p>

<h3>小标题</h3>
<p>更多内容...</p>

<hr>
<p><strong>标签:</strong> #技术 #WordPress</p>
```

### Markdown 格式 (需要转换)

先转换为 HTML,或者使用 Markdown 插件

---

## 🔧 常用命令

### 查看所有文章
```bash
docker exec wordpress-db mariadb -u wordpress_user -p"REDACTED_DB_PASSWORD" wordpress \
  -e "SELECT ID, post_title, post_status FROM wp_posts WHERE post_type='post' ORDER BY post_date DESC LIMIT 10;"
```

### 查看特定文章
```bash
docker exec wordpress-db mariadb -u wordpress_user -p"REDACTED_DB_PASSWORD" wordpress \
  -e "SELECT * FROM wp_posts WHERE ID=123;"
```

### 删除文章
```bash
docker exec wordpress-db mariadb -u wordpress_user -p"REDACTED_DB_PASSWORD" wordpress \
  -e "DELETE FROM wp_posts WHERE ID=123;"
```

---

## 📂 文件结构

```
/opt/projects/blog/wordpress/          # 博客项目
├── publish.sh                          # ⭐ 发布脚本
├── .env                               # 配置文件(密码)
├── PUBLISH_WORKFLOW.md                 # 详细工作流
└── wp-content/                        # WordPress 内容

/root/.openclaw/workspace/tools/       # 文章草稿
├── wp-publish-template.md             # 文章模板
└── articles/                          # 存放草稿
```

---

## ⚡ 快速开始

### 第一次发布

```bash
# 1. 测试发布
cd /opt/projects/blog/wordpress
./publish.sh "测试文章" "<h2>这是测试</h2><p>测试内容...</p>"

# 2. 访问查看
echo "访问: http://42.193.14.72:8081"
```

### 日常发布

```bash
# 方式A: 直接发布
./publish.sh "今天的技术分享" "$(cat article.html)"

# 方式B: 后台发布
# 访问 http://42.193.14.72:8081/wp-admin
```

---

## 🎨 文章样式建议

### 推荐的 HTML 结构

```html
<!-- 标题 -->
<h2>主标题</h2>

<!-- 摘要 -->
<p class="excerpt">文章摘要...</p>

<!-- 正文 -->
<p>段落内容...</p>

<!-- 小标题 -->
<h3>章节标题</h3>
<p>更多内容...</p>

<!-- 列表 -->
<ul>
  <li>项目1</li>
  <li>项目2</li>
</ul>

<!-- 代码块 -->
<pre><code>代码内容</code></pre>

<!-- 分隔线 -->
<hr>

<!-- 标签 -->
<p><strong>标签:</strong> #技术 #WordPress</p>
```

---

## 🚨 故障排查

### 发布失败

```bash
# 检查数据库连接
docker exec wordpress-db mariadb -u wordpress_user -p"REDACTED_DB_PASSWORD" wordpress -e "SELECT 1;"

# 检查 WordPress 容器
docker ps | grep wordpress

# 查看日志
docker logs wordpress
```

### 文章不显示

```bash
# 检查文章状态
docker exec wordpress-db mariadb -u wordpress_user -p"REDACTED_DB_PASSWORD" wordpress \
  -e "SELECT post_status FROM wp_posts WHERE post_title='文章标题';"

# 清除缓存
docker exec wordpress service apache2 reload
```

---

## 📚 更多信息

- **详细工作流:** `/opt/projects/blog/PUBLISH_WORKFLOW.md`
- **文章模板:** `/root/.openclaw/workspace/tools/wp-publish-template.md`
- **GitHub 仓库:** https://github.com/wangjn163/wordpress-blog
- **博客地址:** http://42.193.14.72:8081

---

**记住:** 代码用 Git,内容用发布工具! 🎯
