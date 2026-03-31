# WordPress CI/CD 自动部署配置指南

**创建时间:** 2026-03-24

## 🎯 目标

实现从代码修改到自动部署上线的完整流程:

```
本地修改 → Git 提交 → GitHub 推送 → 自动部署 → 用户可见
   ↑___________GitHub Actions___________↑
```

---

## 📋 前置要求

### 1. 服务器 SSH 配置

```bash
# 在服务器上生成 SSH 密钥对
ssh-keygen -t rsa -b 4096 -C "github-actions" -f ~/.ssh/github_actions

# 将公钥添加到 authorized_keys
cat ~/.ssh/github_actions.pub >> ~/.ssh/authorized_keys

# 测试 SSH 连接
ssh -i ~/.ssh/github_actions localhost "echo 'SSH test successful'"
```

### 2. GitHub Secrets 配置

需要在 GitHub 仓库中配置以下 Secrets:

| Secret 名称 | 说明 | 示例值 |
|------------|------|--------|
| `SERVER_HOST` | 服务器 IP 地址 | `42.193.14.72` |
| `SERVER_USER` | SSH 用户名 | `root` |
| `SERVER_PORT` | SSH 端口 | `22` |
| `SSH_PRIVATE_KEY` | SSH 私钥 | 整个私钥文件内容 |

---

## 🔧 配置步骤

### 步骤 1: 生成 SSH 密钥

```bash
# 在服务器上执行
cd ~
ssh-keygen -t rsa -b 4096 -C "github-actions" -f ~/.ssh/github_deploy_key -N ""

# 查看私钥(复制这个内容)
cat ~/.ssh/github_deploy_key
```

**重要:** 复制整个私钥内容,包括:
```
-----BEGIN OPENSSH PRIVATE KEY-----
...很多行...
-----END OPENSSH PRIVATE KEY-----
```

### 步骤 2: 配置服务器

```bash
# 添加公钥到 authorized_keys
cat ~/.ssh/github_deploy_key.pub >> ~/.ssh/authorized_keys

# 设置正确权限
chmod 600 ~/.ssh/github_deploy_key
chmod 644 ~/.ssh/authorized_keys

# 测试 SSH 登录
ssh -i ~/.ssh/github_deploy_key localhost "hostname"
```

### 步骤 3: 在 GitHub 配置 Secrets

1. 访问你的 GitHub 仓库
2. 点击 `Settings` → `Secrets and variables` → `Actions`
3. 点击 `New repository secret`
4. 添加以下 Secrets:

```
SERVER_HOST = 42.193.14.72
SERVER_USER = root
SERVER_PORT = 22
SSH_PRIVATE_KEY = [粘贴整个私钥内容]
```

### 步骤 4: 推送工作流文件

```bash
cd /opt/projects/blog/wordpress

# 添加工作流文件
git add .github/workflows/deploy.yml
git commit -m "添加 GitHub Actions 自动部署"
git push origin main
```

---

## 🚀 使用方法

### 自动部署

只要推送到 `main` 分支,就会自动部署:

```bash
# 修改插件或主题
vim wp-content/plugins/my-plugin/file.php

# 提交并推送
git add .
git commit -m "修复插件 bug"
git push origin main

# ✅ GitHub Actions 自动执行部署
```

### 手动触发

在 GitHub 上:
1. 点击 `Actions` 标签
2. 选择 `Deploy WordPress to Server`
3. 点击 `Run workflow` 按钮

---

## 🔄 工作流程

### 开发流程

```bash
# 1. 本地修改
vim wp-content/plugins/my-plugin/plugin.php

# 2. 测试修改
# 在本地或测试环境测试

# 3. Git 提交
git add .
git commit -m "更新插件功能"

# 4. 推送到 GitHub
git push origin main

# 5. ✅ 自动部署
# GitHub Actions 自动:
#   - SSH 连接到服务器
#   - 拉取最新代码
#   - 设置文件权限
#   - 清理缓存
#   - 完成部署
```

### 部署过程

```
GitHub 收到推送
    ↓
触发 GitHub Actions
    ↓
SSH 连接到服务器
    ↓
执行部署脚本:
    • git pull
    • 设置权限
    • 清理缓存
    ↓
部署完成 ✅
    ↓
用户可以看到更新
```

---

## 📊 监控部署

### 查看部署状态

1. 访问 GitHub 仓库
2. 点击 `Actions` 标签
3. 查看最近的部署记录

### 部署日志

每次部署都会显示:
- ✓/✅ 成功步骤
- ✗/❌ 失败步骤
- 📋 部署信息(分支、提交、作者、时间)
- 📄 完整日志

---

## 🎓 高级用法

### 只在特定文件变化时部署

```yaml
on:
  push:
    paths:
      - 'wp-content/plugins/**'   # 只在插件变化时
      - 'wp-content/themes/**'    # 只在主题变化时
```

### 手动触发部署

```yaml
on:
  workflow_dispatch:  # 允许手动触发
```

### 环境变量

```yaml
env:
  WP_PATH: /opt/projects/blog/wordpress
  DOCKER_COMPOSE: docker compose
```

---

## 🛠️ 故障排查

### 部署失败

#### 1. SSH 连接失败
```bash
# 检查密钥
ssh -i ~/.ssh/github_deploy_key localhost "hostname"

# 检查 SSH 服务
systemctl status ssh
```

#### 2. Git 权限错误
```bash
# 检查仓库权限
ls -la /opt/projects/blog/wordpress/.git

# 修复权限
sudo chown -R www-data:www-data /opt/projects/blog/wordpress
```

#### 3. Docker 容器问题
```bash
# 检查容器状态
docker ps | grep wordpress

# 查看日志
docker logs wordpress
```

---

## 🔐 安全注意事项

### ✅ 推荐做法

1. **使用专用的 SSH 密钥**
   - 不要使用个人 SSH 密钥
   - 为 GitHub Actions 生成专用密钥

2. **限制 SSH 权限**
   - 只允许执行特定命令
   - 使用非 root 用户(建议)

3. **定期轮换密钥**
   - 每几个月更换一次 SSH 密钥
   - 删除不再使用的密钥

### ❌ 避免做法

1. ❌ 不要在日志中显示敏感信息
2. ❌ 不要提交 .env 文件到 Git
3. ❌ 不要给 GitHub Actions 过多权限

---

## 📚 相关文档

- **GitHub Actions 文档:** https://docs.github.com/en/actions
- **SSH Action:** https://github.com/appleboy/ssh-action
- **项目 README:** /opt/projects/blog/README_PUBLISH.md

---

## 🎯 总结

使用 GitHub Actions 自动部署后:

| 操作 | 之前 | 现在 |
|-----|------|------|
| **修改代码** | 手动上传 | Git 推送 |
| **部署到服务器** | 手动执行 | 自动触发 |
| **清理缓存** | 手动执行 | 自动完成 |
| **设置权限** | 手动执行 | 自动完成 |
| **查看日志** | 服务器日志 | GitHub Actions |

**时间对比:**
- 手动部署: 5-10 分钟
- 自动部署: 2-3 分钟 ⚡

---

**下一步:** 配置 GitHub Secrets,推送到 GitHub,享受自动化! 🚀
