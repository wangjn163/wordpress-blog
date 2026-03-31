# Learnings

Corrections, knowledge gaps, and best practices.

## Format
- **Date**: YYYY-MM-DD
- **Category**: correction | knowledge_gap | best_practice | simplify-and-harden
- **Context**: What happened
- **Learning**: What to remember
- **See Also**: Link to related entries (if any)

---

## 2026-03-27

### Cron 环境变量问题修复
- **Date**: 2026-03-27
- **Category**: best_practice
- **Context**: 自动博客定时任务在 cron 环境中失败，报错"Node.js未安装"
- **Root Cause**: cron 没有加载 nvm 环境变量，无法找到通过 nvm 安装的 Node.js
- **Solution**: 在脚本开头添加 nvm 环境加载和 PATH 设置：
  ```bash
  export NVM_DIR="$HOME/.nvm"
  if [ -s "$NVM_DIR/nvm.sh" ]; then
      \. "$NVM_DIR/nvm.sh"
  fi
  export PATH="$HOME/.nvm/versions/node/v22.22.1/bin:$PATH"
  ```
- **See Also**: `/root/.openclaw/workspace/skills/auto-blog/scripts/generate-blog.sh`

### 百度搜索时间过滤
- **Date**: 2026-03-27
- **Category**: best_practice
- **Context**: 博客连续两天内容相同，因为百度搜索返回了相同的老新闻
- **Root Cause**: 百度搜索请求没有添加时间过滤参数
- **Solution**: 在百度搜索请求中添加 `"freshness": "pw"` 参数，只搜索最近一周的内容
- **See Also**: `/root/.openclaw/workspace/skills/auto-blog/scripts/generate-blog.sh`

---