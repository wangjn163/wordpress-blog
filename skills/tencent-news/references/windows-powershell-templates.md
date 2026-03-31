# Windows PowerShell 脚本模板

Windows 流程统一使用这份模板管理 `*.ps1` 的恢复与执行。

当你在 Windows 上执行 PowerShell 流程时：

1. 先检查所需脚本是否已存在于 `scripts/` 目录。
2. 如果 `scripts/_common.ps1` 或目标脚本缺失，再从本文件读取对应模板。
3. 将代码块原样写回 `scripts/` 目录，文件名与标题保持一致。
4. 至少恢复 `scripts/_common.ps1` 和当前目标脚本。
5. 再执行 `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/<name>.ps1`。

## `scripts/_common.ps1`

```powershell
Set-StrictMode -Version Latest

$Script:TencentNewsApiKeyEnv = "TENCENT_NEWS_APIKEY"
$Script:TencentNewsBaseDownloadUrl = "https://mat1.gtimg.com/qqcdn/qqnews/cli/hub"
$Script:TencentNewsDefaultUpdateWindowSeconds = 43200
$Script:TencentNewsScriptsDir = $PSScriptRoot
$Script:TencentNewsSkillDir = Split-Path -Parent $Script:TencentNewsScriptsDir

# ── Config file path ──────────────────────────────────────────────
# Persistent config stored under $HOME/.config/tencent-news-cli/config.json
# Used as fallback when env var is not set (e.g. sandboxed agents).
$Script:TencentNewsConfigDir = Join-Path $HOME ".config" | Join-Path -ChildPath "tencent-news-cli"
$Script:TencentNewsConfigFile = Join-Path $Script:TencentNewsConfigDir "config.json"

function Write-TencentNewsJson {
  param(
    [Parameter(Mandatory = $true)]
    [object]$Value
  )

  $Value | ConvertTo-Json -Depth 8
}

function Fail-TencentNews {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Message
  )

  [Console]::Error.WriteLine("Error: $Message")
  exit 1
}

function Get-TencentNewsPlatformInfo {
  $archRaw = if ($env:PROCESSOR_ARCHITEW6432) {
    $env:PROCESSOR_ARCHITEW6432
  } elseif ($env:PROCESSOR_ARCHITECTURE) {
    $env:PROCESSOR_ARCHITECTURE
  } else {
    [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
  }

  $arch = switch -Regex ($archRaw.ToLowerInvariant()) {
    "arm64|aarch64" { "arm64"; break }
    "amd64|x86_64" { "amd64"; break }
    default { throw "unsupported architecture: $archRaw" }
  }

  $cliFilename = "tencent-news-cli.exe"
  $cliPath = Join-Path $Script:TencentNewsSkillDir $cliFilename
  $cliDownloadUrl = "$($Script:TencentNewsBaseDownloadUrl)/windows-$arch/$cliFilename"
  $lastCheckFile = Join-Path $Script:TencentNewsSkillDir ".last-update-check-windows-$arch"

  [pscustomobject]@{
    os                  = "windows"
    arch                = $arch
    detectedShell       = "powershell"
    preferredShell      = "powershell"
    profilePath         = $PROFILE.CurrentUserCurrentHost
    cliFilename         = $cliFilename
    cliPath             = $cliPath
    cliDownloadUrl      = $cliDownloadUrl
    lastCheckFile       = $lastCheckFile
    helpCommand         = "& '$cliPath' help"
    versionCommand      = "& '$cliPath' version"
  }
}

# ── Config-file helpers ────────────────────────────────────────────

function Read-TencentNewsConfigApiKey {
  if (-not (Test-Path -LiteralPath $Script:TencentNewsConfigFile)) {
    return $null
  }
  try {
    $cfg = Get-Content -LiteralPath $Script:TencentNewsConfigFile -Raw | ConvertFrom-Json
    $val = $cfg.$($Script:TencentNewsApiKeyEnv)
    if ($val) { return $val }
  } catch {}
  return $null
}

function Write-TencentNewsConfigApiKey {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ApiKey
  )
  if (-not (Test-Path -LiteralPath $Script:TencentNewsConfigDir)) {
    New-Item -ItemType Directory -Path $Script:TencentNewsConfigDir -Force | Out-Null
  }
  @{ $Script:TencentNewsApiKeyEnv = $ApiKey } | ConvertTo-Json | Set-Content -LiteralPath $Script:TencentNewsConfigFile -Encoding UTF8
}

# ── API key state ─────────────────────────────────────────────────
#
# Returns a PSCustomObject describing the current API key state.
#
# When present=$false AND the config file contains a key:
#   configFileHasKey = $true
#   restoreCommand   = "$env:TENCENT_NEWS_APIKEY = '<value>'"
#     → The agent MUST execute this in its own PowerShell session.
#
# When present=$false AND the config file has no key:
#   configFileHasKey = $false

function Get-TencentNewsApiKeyState {
  param(
    [Parameter(Mandatory = $true)]
    [object]$PlatformInfo
  )

  $envPresent = [bool]$env:TENCENT_NEWS_APIKEY

  $result = [ordered]@{
    envVar              = $Script:TencentNewsApiKeyEnv
    present             = $envPresent
    configFile          = $Script:TencentNewsConfigFile
  }

  if (-not $envPresent) {
    $cfgVal = Read-TencentNewsConfigApiKey
    if ($cfgVal) {
      $escaped = $cfgVal.Replace("'", "''")
      $result["configFileHasKey"] = $true
      $result["restoreCommand"]   = "`$env:$($Script:TencentNewsApiKeyEnv) = '$escaped'"
    } else {
      $result["configFileHasKey"] = $false
    }
  }

  $result["detectedShell"]       = $PlatformInfo.detectedShell
  $result["preferredShell"]      = $PlatformInfo.preferredShell
  $result["profilePath"]         = $PlatformInfo.profilePath
  $result["canAutoConfigure"]    = $true
  $result["verificationCommand"] = '$env:TENCENT_NEWS_APIKEY'

  [pscustomobject]$result
}

function Read-TencentNewsLastCheckEpoch {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  if (-not (Test-Path -LiteralPath $Path)) {
    return [int64]0
  }

  $raw = (Get-Content -LiteralPath $Path -Raw).Trim()
  if ($raw -notmatch '^\d+$') {
    return [int64]0
  }

  return [int64]$raw
}

function Write-TencentNewsLastCheckEpoch {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [int64]$Epoch = ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
  )

  Set-Content -LiteralPath $Path -Value $Epoch
  return $Epoch
}

function Get-TencentNewsDownloadUrl {
  param(
    [Parameter(Mandatory = $true)]
    [object]$PlatformInfo,
    [string]$ExplicitUrl
  )

  if ($ExplicitUrl) {
    return $ExplicitUrl
  }

  return "$($Script:TencentNewsBaseDownloadUrl)/$($PlatformInfo.os)-$($PlatformInfo.arch)/$($PlatformInfo.cliFilename)"
}

function Download-TencentNewsCli {
  param(
    [Parameter(Mandatory = $true)]
    [string]$DownloadUrl,
    [Parameter(Mandatory = $true)]
    [object]$PlatformInfo
  )

  Invoke-WebRequest -Uri $DownloadUrl -OutFile $PlatformInfo.cliPath
}

function Get-TencentNewsCliVersion {
  param(
    [Parameter(Mandatory = $true)]
    [string]$CliPath
  )

  if (-not (Test-Path -LiteralPath $CliPath)) {
    throw "cli not found at $CliPath"
  }

  $rawOutput = (& $CliPath version 2>&1 | Out-String).Trim()
  if (-not $rawOutput) {
    throw "cli returned empty version output"
  }

  try {
    $parsed = $rawOutput | ConvertFrom-Json
  } catch {
    $parsed = $null
  }

  [pscustomobject]@{
    RawOutput = $rawOutput
    Parsed    = $parsed
  }
}

function Resolve-TencentNewsVersionDownloadUrl {
  param(
    [Parameter(Mandatory = $true)]
    [object]$VersionInfo,
    [Parameter(Mandatory = $true)]
    [object]$PlatformInfo
  )

  $key = "$($PlatformInfo.os)_$($PlatformInfo.arch)"
  $candidate = $VersionInfo.download_urls.$key

  if ($candidate) {
    return $candidate
  }

  return Get-TencentNewsDownloadUrl -PlatformInfo $PlatformInfo
}

function Set-TencentNewsApiKey {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ApiKey
  )

  # Write to Windows user-level environment variable (registry).
  [Environment]::SetEnvironmentVariable($Script:TencentNewsApiKeyEnv, $ApiKey, "User")

  # Also write to config file for cross-session persistence.
  Write-TencentNewsConfigApiKey -ApiKey $ApiKey

  $escaped = $ApiKey.Replace("'", "''")

  [pscustomobject]@{
    configured         = $true
    present            = $true
    storage            = "windows-user-env"
    configFile         = $Script:TencentNewsConfigFile
    sessionCommand     = "`$env:$($Script:TencentNewsApiKeyEnv) = '$escaped'"
    verificationCommand = '$env:TENCENT_NEWS_APIKEY'
    requiresNewTerminal = $false
  }
}
```

## `scripts/cli-state.ps1`

```powershell
param(
  [int]$UpdateWindowSeconds = 43200,
  [switch]$Help
)

if ($Help) {
  @"
Usage: powershell -NoProfile -ExecutionPolicy Bypass -File scripts/cli-state.ps1 [-UpdateWindowSeconds 43200]

Print install state, update-check window status, and API key status for Windows.
"@
  exit 0
}

. "$PSScriptRoot/_common.ps1"

if ($UpdateWindowSeconds -lt 0) {
  Fail-TencentNews "-UpdateWindowSeconds must be a non-negative integer."
}

try {
  $platform = Get-TencentNewsPlatformInfo
  $lastCheckEpoch = Read-TencentNewsLastCheckEpoch -Path $platform.lastCheckFile
  $nowEpoch = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

  Write-TencentNewsJson @{
    platform          = $platform
    cliExists         = Test-Path -LiteralPath $platform.cliPath
    lastCheckEpoch    = $lastCheckEpoch
    nowEpoch          = $nowEpoch
    updateWindowSeconds = $UpdateWindowSeconds
    needsUpdateCheck  = (($nowEpoch - $lastCheckEpoch) -gt $UpdateWindowSeconds)
    apiKey            = Get-TencentNewsApiKeyState -PlatformInfo $platform
  }
} catch {
  Fail-TencentNews $_.Exception.Message
}
```

## `scripts/install-cli.ps1`

```powershell
param(
  [string]$Url,
  [switch]$Help
)

if ($Help) {
  @"
Usage: powershell -NoProfile -ExecutionPolicy Bypass -File scripts/install-cli.ps1 [-Url DOWNLOAD_URL]

Download the current-platform CLI into the skill directory and verify it with version.
"@
  exit 0
}

. "$PSScriptRoot/_common.ps1"

try {
  $platform = Get-TencentNewsPlatformInfo
  $downloadUrl = Get-TencentNewsDownloadUrl -PlatformInfo $platform -ExplicitUrl $Url
  Download-TencentNewsCli -DownloadUrl $downloadUrl -PlatformInfo $platform
  $version = Get-TencentNewsCliVersion -CliPath $platform.cliPath

  Write-TencentNewsJson @{
    installed        = $true
    platform         = $platform
    downloadUrl      = $downloadUrl
    currentVersion   = $version.Parsed.current_version
    latestVersion    = $version.Parsed.latest_version
    rawVersionOutput = $version.RawOutput
  }
} catch {
  Fail-TencentNews $_.Exception.Message
}
```

## `scripts/check-update.ps1`

```powershell
param(
  [switch]$Apply,
  [switch]$Help
)

if ($Help) {
  @"
Usage: powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check-update.ps1 [-Apply]

Inspect the CLI version JSON and optionally download the newer binary for Windows.
"@
  exit 0
}

. "$PSScriptRoot/_common.ps1"

try {
  $platform = Get-TencentNewsPlatformInfo
  if (-not (Test-Path -LiteralPath $platform.cliPath)) {
    Fail-TencentNews "cli not found at $($platform.cliPath). Run powershell -NoProfile -ExecutionPolicy Bypass -File scripts/install-cli.ps1 first."
  }

  $before = Get-TencentNewsCliVersion -CliPath $platform.cliPath
  if (-not $before.Parsed) {
    Fail-TencentNews "`version` did not return valid JSON."
  }

  $downloadUrl = Resolve-TencentNewsVersionDownloadUrl -VersionInfo $before.Parsed -PlatformInfo $platform
  $applied = $false
  $after = $before

  if ($Apply -and $before.Parsed.need_update) {
    Download-TencentNewsCli -DownloadUrl $downloadUrl -PlatformInfo $platform
    $after = Get-TencentNewsCliVersion -CliPath $platform.cliPath
    $applied = $true
  }

  $checkedAt = Write-TencentNewsLastCheckEpoch -Path $platform.lastCheckFile

  Write-TencentNewsJson @{
    platform            = $platform
    checkedAt           = $checkedAt
    needUpdate          = [bool]$before.Parsed.need_update
    applied             = $applied
    selectedDownloadUrl = $downloadUrl
    currentVersion      = $after.Parsed.current_version
    latestVersion       = $before.Parsed.latest_version
    releaseNotes        = $before.Parsed.release_notes
    rawBefore           = $before.RawOutput
    rawAfter            = $after.RawOutput
  }
} catch {
  Fail-TencentNews $_.Exception.Message
}
```

## `scripts/api-key.ps1`

```powershell
param(
  [string]$Set,
  [switch]$Help
)

if ($Help) {
  @"
Usage: powershell -NoProfile -ExecutionPolicy Bypass -File scripts/api-key.ps1 [-Set KEY]

Inspect or persist the TENCENT_NEWS_APIKEY value for Windows.
"@
  exit 0
}

. "$PSScriptRoot/_common.ps1"

try {
  $platform = Get-TencentNewsPlatformInfo

  if ($Set) {
    # Set mode: write to Windows user env + config file.
    $result = Set-TencentNewsApiKey -ApiKey $Set
    Write-TencentNewsJson @{
      envVar              = $Script:TencentNewsApiKeyEnv
      present             = $true
      detectedShell       = $platform.detectedShell
      preferredShell      = $platform.preferredShell
      profilePath         = $platform.profilePath
      canAutoConfigure    = $true
      configured          = $true
      storage             = $result.storage
      configFile          = $result.configFile
      sessionCommand      = $result.sessionCommand
      verificationCommand = $result.verificationCommand
      requiresNewTerminal = $result.requiresNewTerminal
      note                = "Run sessionCommand in the current terminal if you need the key immediately."
    }
    exit 0
  }

  # Read mode: Get-TencentNewsApiKeyState checks env var + config file fallback.
  Write-TencentNewsJson (Get-TencentNewsApiKeyState -PlatformInfo $platform)
} catch {
  Fail-TencentNews $_.Exception.Message
}
```

## `scripts/runtime-info.ps1`

```powershell
param(
  [switch]$Help
)

if ($Help) {
  @"
Usage: powershell -NoProfile -ExecutionPolicy Bypass -File scripts/runtime-info.ps1

Print platform info, CLI paths, and recommended help/version commands for Windows.
"@
  exit 0
}

. "$PSScriptRoot/_common.ps1"

try {
  $platform = Get-TencentNewsPlatformInfo
  Write-TencentNewsJson @{
    skillDir = $Script:TencentNewsSkillDir
    platform = $platform
    apiKey   = Get-TencentNewsApiKeyState -PlatformInfo $platform
  }
} catch {
  Fail-TencentNews $_.Exception.Message
}
```
