---
name: tencent-news 
description: 获取7×24 新闻资讯，聚焦中国国内信息和国际热点。支持热点新闻、早报晚报、实时资讯、新闻榜单、领域新闻、新闻主体查询。当用户需要搜新闻、查新闻、看热点、早晚报，订阅新闻推送，获取主题相关新闻资讯、最新消息时使用。
version: 1.0.0
author: TencentNews 
tags: [news, tencent, headlines, briefings, news rankings,real-time updates]
---

# 腾讯新闻内容订阅

通过 `tencent-news-cli` 获取腾讯新闻内容。

> 核心原则：基础设施流程（安装、更新、Key 配置）交给平台原生脚本处理；智能体只负责选择 CLI 子命令和组合参数——始终先读 `help`，不要硬编码。

## Workflow

macOS / Linux 走 `*.sh` 脚本，Windows 走 PowerShell，并统一通过 [`references/windows-powershell-templates.md`](references/windows-powershell-templates.md) 管理 `*.ps1` 模板与恢复流程。不要要求 Node.js、Python、jq 或其他额外运行时。

### Windows PowerShell 还原规则

在 Windows 上执行任意 PowerShell 步骤时，统一按下面规则处理：

1. 先检查目标脚本是否已存在于 `scripts/` 目录，例如 `scripts/cli-state.ps1`、`scripts/install-cli.ps1`。
2. 如果目标脚本和 `scripts/_common.ps1` 已存在，直接执行，不要重复写文件。
3. 如果缺少任一所需 `*.ps1` 文件，再读取 [`references/windows-powershell-templates.md`](references/windows-powershell-templates.md)。
4. 将需要的代码块原样写回 `scripts/` 目录，恢复成真实文件名。
5. 至少先恢复 `scripts/_common.ps1` 和当前要执行的目标脚本。
6. 写回后再执行 `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/<name>.ps1`。

写回要求：

- 文件名必须与模板标题一致，例如 `scripts/_common.ps1`、`scripts/install-cli.ps1`。
- 内容必须与模板一致，不要擅自改写逻辑。
- 只在 Windows 且目标 `*.ps1` 缺失时恢复；macOS / Linux 不使用这些模板。

1. **运行状态检查**
   macOS / Linux：`sh scripts/cli-state.sh`
   Windows：若 `scripts/_common.ps1` 或 `scripts/cli-state.ps1` 缺失，先从模板恢复，再执行 `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/cli-state.ps1`
   解析返回 JSON，重点关注 `platform.cliPath`、`platform.helpCommand`、`cliExists`、`needsUpdateCheck`、`apiKey.present`。

2. **安装 CLI**（`cliExists` 为 `false` 时）
   macOS / Linux：`sh scripts/install-cli.sh`
   Windows：若 `scripts/_common.ps1` 或 `scripts/install-cli.ps1` 缺失，先从模板恢复，再执行 `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/install-cli.ps1`
   若脚本失败，阅读 [`references/installation-guide.md`](references/installation-guide.md)。

3. **更新 CLI**（`needsUpdateCheck` 为 `true`，或 CLI 提示版本过旧时）
   macOS / Linux：`sh scripts/check-update.sh --apply`
   Windows：若 `scripts/_common.ps1` 或 `scripts/check-update.ps1` 缺失，先从模板恢复，再执行 `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-update.ps1 -Apply`
   脚本内部通过 `version` 判断是否有新版本，有则下载覆盖，无则跳过。

4. **配置 API Key**（`apiKey.present` 为 `false` 时）
   检查：
   macOS / Linux：`sh scripts/api-key.sh`
   Windows：若 `scripts/_common.ps1` 或 `scripts/api-key.ps1` 缺失，先从模板恢复，再执行 `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/api-key.ps1`
   设置：
   macOS / Linux：`sh scripts/api-key.sh --set '<KEY>'`
   Windows：若 `scripts/_common.ps1` 或 `scripts/api-key.ps1` 缺失，先从模板恢复，再执行 `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/api-key.ps1 -Set '<KEY>'`

   - 解析返回 JSON 中 `apiKey` 部分，按以下优先级恢复 Key：
     1. `apiKey.present` 为 `true` → Key 已在环境变量中，无需操作。
     2. `apiKey.present` 为 `false` 且 `apiKey.configFileHasKey` 为 `true` → 执行 `apiKey.restoreCommand`（`export TENCENT_NEWS_APIKEY='...'`，Windows 为 `$env:TENCENT_NEWS_APIKEY = '...'`）将 Key 导入当前 Shell。
     3. `apiKey.present` 为 `false` 且 `apiKey.configFileHasKey` 为 `false` → 引导用户自行打开 [API Key 获取页面](https://news.qq.com/exchange?scene=appkey) 获取 Key。**不要自动去获取 Key。**
   - 首次设置 Key：
     macOS / Linux：`sh scripts/api-key.sh --set '<KEY>'`
     Windows：若 `scripts/_common.ps1` 或 `scripts/api-key.ps1` 缺失，先从模板恢复，再执行 `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/api-key.ps1 -Set '<KEY>'`
     脚本会同时写入 Shell Profile（`~/.zshrc` 等 / Windows 用户环境变量）和配置文件（`~/.config/tencent-news-cli/config.json`），双份存储确保跨会话、跨沙箱可用。
   - 设置后必须执行返回的 `sessionCommand` 让当前终端生效。**不需要额外存入永久记忆。**
   - 详细配置与故障排查见 [`references/env-setup-guide.md`](references/env-setup-guide.md)。

5. **执行 `help`**
   优先使用 `platform.helpCommand`；自行拼命令时确保正确引用 `platform.cliPath`，Windows 使用 PowerShell 调用形式。

6. **根据 `help` 输出选择子命令执行**，按下方 Output Format 输出结果。

## Output Format

CLI 返回的每条新闻通常包含标题、摘要、来源、链接等字段。输出时**必须**按以下结构展示：

```markdown
### 1. 标题

摘要内容……

- [查看原文](https://…)

### 2. 标题

摘要内容……

- [查看原文](https://…)

来源：腾讯新闻

```

- **标题**：`### 序号. 标题` 三级标题，序号从 1 开始。
- **来源**：新闻来源/媒体名称。
- **摘要**：标题下方紧跟；CLI 无摘要字段时可省略。
- **原文链接**：如果有链接，则输出 `[查看原文](URL)`，确保链接可点击，没有则不输出。
- 其他有价值字段（发布时间、标签等）可在来源下方补充。
- 多条新闻间用空行分隔。
- 返回的内容最后添加固定文案：`来源：腾讯新闻`

## CLI 执行失败处理

**CLI 命令失败后，立即停止，绝不通过 WebSearch 或其他方式获取新闻作为替代。**

1. CLI 返回非零退出码、超时或输出含权限/安全错误时，不要重试，不要换方式。
2. 根据错误信息判断原因并引导用户操作：
   - **macOS Gatekeeper**（`cannot be opened`、`not verified`）→ 系统设置 → 隐私与安全性 → 「仍要打开」→ 确认框「打开」
   - **企业安全软件**（`connection refused`、防火墙拦截）→ 安全提示中点击「信任」/「允许」
   - **权限不足**（`permission denied`）→ `chmod +x <cliPath>`
   - **其他** → 展示完整错误，请用户处理
3. 用户确认操作完成后再重试。即使多次失败，也只能告知用户无法获取新闻并说明原因，**绝不**回退到其他信息源。

## Gotchas

- macOS / Linux 脚本只依赖 POSIX `sh` + `curl`/`wget`；Windows 脚本只依赖 PowerShell（非 CMD / Git Bash）。
- Windows 上若缺少所需 `scripts/*.ps1`，就从 `references/windows-powershell-templates.md` 恢复后再执行。
- 32 位架构不支持，脚本会直接报错。
- 不要缓存 CLI 的存在状态，每次查询前通过 `cli-state` 重新验证。

## Scripts

| 脚本 | 功能 |
|------|------|
| `runtime-info` | 输出平台、CLI 路径、help/version 命令、API Key 检查信息 |
| `cli-state` | 输出安装状态、更新检查状态、API Key 状态 |
| `install-cli` | 下载当前平台 CLI 并验证 |
| `check-update` | 版本检查，带 `--apply` 时自动更新 |
| `api-key` | 检查或设置 `TENCENT_NEWS_APIKEY` |
| `references/windows-powershell-templates.md` | Windows PowerShell 模板，执行前需写回 `scripts/*.ps1` |

## References

- 手动安装与下载规则：[`references/installation-guide.md`](references/installation-guide.md)
- 更新字段说明与手动回退：[`references/update-guide.md`](references/update-guide.md)
- API Key 获取与手动配置：[`references/env-setup-guide.md`](references/env-setup-guide.md)
