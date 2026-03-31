# tencent-news-cli 安装指南

默认安装路径走平台原生脚本，不依赖 Node.js 或 Python。

在 Windows 上执行前，先检查 `scripts/_common.ps1` 和 `scripts/install-cli.ps1` 是否存在；如果缺失，再读取 [`windows-powershell-templates.md`](windows-powershell-templates.md) 把它们原样写回 `scripts/` 目录，然后执行下方 PowerShell 命令。

## 首选方案

### macOS / Linux

```sh
sh scripts/install-cli.sh
```

### Windows PowerShell

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/install-cli.ps1
```

安装脚本会自动完成以下事情：

1. 识别当前 `OS` 和 `ARCH`
2. 计算当前平台对应的下载地址
3. 从 `https://mat1.gtimg.com/qqcdn/qqnews/cli/hub/<os>-<arch>/` 下载 CLI
4. 在 macOS / Linux 上自动 `chmod +x`
5. 运行 `version` 验证安装结果

如果需要覆盖默认下载地址：

### macOS / Linux

```sh
# macOS (Apple Silicon)
sh scripts/install-cli.sh --url 'https://mat1.gtimg.com/qqcdn/qqnews/cli/hub/darwin-arm64/tencent-news-cli'

# Linux (ARM64)
sh scripts/install-cli.sh --url 'https://mat1.gtimg.com/qqcdn/qqnews/cli/hub/linux-arm64/tencent-news-cli'
```

### Windows PowerShell

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/install-cli.ps1 -Url 'https://mat1.gtimg.com/qqcdn/qqnews/cli/hub/windows-amd64/tencent-news-cli.exe'
```

## 输出字段

安装脚本会输出 JSON，常用字段如下：

- `platform.cliPath`：CLI 完整路径
- `downloadUrl`：实际下载地址
- `currentVersion`：安装后版本
- `latestVersion`：CLI 报告的最新版本
- `rawVersionOutput`：原始版本输出

## 手动回退

仅当脚本下载失败、用户要求手动安装、或需要排查网络问题时，才使用手动命令。

### macOS / Linux

```sh
BASE_URL="https://mat1.gtimg.com/qqcdn/qqnews/cli/hub"
DOWNLOAD_URL="$BASE_URL/<os>-<arch>/tencent-news-cli"

curl -fSL -o "{SKILL_DIR}/tencent-news-cli" "$DOWNLOAD_URL"
chmod +x "{SKILL_DIR}/tencent-news-cli"
"{SKILL_DIR}/tencent-news-cli" version
```

### Windows PowerShell

```powershell
$BaseUrl = "https://mat1.gtimg.com/qqcdn/qqnews/cli/hub"
$DownloadUrl = "$BaseUrl/windows-<arch>/tencent-news-cli.exe"
$CliBin = Join-Path "{SKILL_DIR}" "tencent-news-cli.exe"

Invoke-WebRequest -Uri $DownloadUrl -OutFile $CliBin
& $CliBin version
```

## 故障排查

- 安装脚本报 `unsupported os` 或 `unsupported architecture`：当前平台不在 skill 支持范围内。
- 下载失败：优先检查网络连接和 CDN 地址可达性。
- macOS 安全提示：前往“系统设置 -> 隐私与安全性”允许运行。
- Windows SmartScreen 拦截：在安全提示中选择“更多信息 -> 仍要运行”。
