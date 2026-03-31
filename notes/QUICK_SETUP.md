# ⚡ GitHub Actions 快速配置

## 3 步完成自动部署

### 步骤 1: 生成密钥 (在服务器上)

```bash
# 一键生成并配置
cd ~ && \
ssh-keygen -t rsa -b 4096 -C "github" -f ~/.ssh/github_key -N "" && \
cat ~/.ssh/github_key.pub >> ~/.ssh/authorized_keys && \
echo "✅ 密钥生成完成!" && \
echo "" && \
echo "📋 私钥内容 (复制整个内容):" && \
echo "====================" && \
cat ~/.ssh/github_key && \
echo "===================="
```

### 步骤 2: 配置 GitHub Secrets

1. 访问: https://github.com/wangjn163/wordpress-blog/settings/secrets/actions
2. 点击 "New repository secret"
3. 添加 4 个 Secrets:

```
HOST = 42.193.14.72
USER = root
PORT = 22
KEY = [粘贴上面显示的私钥内容]
```

### 步骤 3: 推送代码

```bash
cd /opt/projects/blog/wordpress

# 添加工作流
git add .github/
git commit -m "添加自动部署"
git push origin main
```

✅ **完成!** 现在每次推送都会自动部署!

---

## 测试

```bash
# 修改一个文件测试
echo "test" >> wp-content/plugins/test.txt

# 推送
git add .
git commit -m "测试自动部署"
git push

# ✅ GitHub Actions 会自动部署!
```

---

## 查看部署状态

访问: https://github.com/wangjn163/wordpress-blog/actions

---

**就这么简单!** 🎉
