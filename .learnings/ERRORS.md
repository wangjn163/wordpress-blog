# Errors

Command failures, exceptions, and integration issues.

## Format
- **Date**: YYYY-MM-DD
- **Command/Operation**: What failed
- **Error**: Error message or behavior
- **Root Cause**: Why it failed (if known)
- **Solution**: How to fix or work around it
- **See Also**: Link to related entries (if any)

---

## 2026-03-27

### 定时任务 Node.js 未安装错误
- **Date**: 2026-03-27
- **Command/Operation**: `crontab -e` 定时任务执行博客生成脚本
- **Error**: `ERROR: Node.js未安装`
- **Root Cause**: cron 环境变量不完整，无法找到通过 nvm 安装的 Node.js
- **Solution**: 在脚本中显式加载 nvm 环境并设置 PATH
- **Status**: ✅ 已修复
- **See Also**: LEARNINGS.md - Cron 环境变量问题修复

---