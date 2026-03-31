#!/bin/sh

set -eu

API_KEY_ENV="TENCENT_NEWS_APIKEY"
BASE_DOWNLOAD_URL="https://mat1.gtimg.com/qqcdn/qqnews/cli/hub"
DEFAULT_UPDATE_WINDOW_SECONDS=43200

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SKILL_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

# ── Config file path ──────────────────────────────────────────────
# Persistent config stored under $HOME/.config/tencent-news-cli/config.json
# Used as fallback when env var is not set (e.g. sandboxed agents).
CONFIG_DIR="$HOME/.config/tencent-news-cli"
CONFIG_FILE="$CONFIG_DIR/config.json"

fail() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g;s/"/\\"/g'
}

json_string() {
  printf '"%s"' "$(json_escape "$1")"
}

json_bool() {
  if [ "$1" = "true" ]; then
    printf 'true'
  else
    printf 'false'
  fi
}

quote_posix() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

compact_text() {
  tr '\n' ' ' | sed 's/[[:space:]][[:space:]]*/ /g;s/^ //;s/ $//'
}

download_file() {
  url=$1
  output_path=$2

  if command -v curl >/dev/null 2>&1; then
    curl -fSL -o "$output_path" "$url"
    return
  fi

  if command -v wget >/dev/null 2>&1; then
    wget -qO "$output_path" "$url"
    return
  fi

  fail "curl or wget is required to download the CLI"
}

detect_platform() {
  OS=$(uname -s | tr '[:upper:]' '[:lower:]')
  ARCH_RAW=$(uname -m)
  DETECTED_SHELL=$(basename "${SHELL:-sh}")

  case "$OS" in
    darwin|linux) ;;
    *)
      fail "unsupported os: $OS"
      ;;
  esac

  case "$ARCH_RAW" in
    arm64|aarch64)
      ARCH="arm64"
      ;;
    x86_64|amd64)
      ARCH="amd64"
      ;;
    *)
      fail "unsupported architecture: $ARCH_RAW"
      ;;
  esac

  case "$DETECTED_SHELL" in
    zsh)
      PROFILE_PATH="$HOME/.zshrc"
      ;;
    bash)
      PROFILE_PATH="$HOME/.bashrc"
      ;;
    *)
      PROFILE_PATH=""
      ;;
  esac

  CLI_FILENAME="tencent-news-cli"
  CLI_PATH="$SKILL_DIR/$CLI_FILENAME"
  CLI_DOWNLOAD_URL="$BASE_DOWNLOAD_URL/$OS-$ARCH/$CLI_FILENAME"
  LAST_CHECK_FILE="$SKILL_DIR/.last-update-check-$OS-$ARCH"
  HELP_COMMAND="$(quote_posix "$CLI_PATH") help"
  VERSION_COMMAND="$(quote_posix "$CLI_PATH") version"
}

read_last_check_epoch() {
  if [ ! -f "$LAST_CHECK_FILE" ]; then
    printf '0'
    return
  fi

  value=$(tr -d '\r\n' < "$LAST_CHECK_FILE")
  case "$value" in
    ''|*[!0-9]*)
      printf '0'
      ;;
    *)
      printf '%s' "$value"
      ;;
  esac
}

write_last_check_epoch() {
  epoch=${1:-$(date +%s)}
  printf '%s\n' "$epoch" > "$LAST_CHECK_FILE"
  printf '%s' "$epoch"
}

run_cli_version() {
  if [ ! -f "$CLI_PATH" ]; then
    fail "cli not found at $CLI_PATH"
  fi

  if [ ! -x "$CLI_PATH" ]; then
    chmod +x "$CLI_PATH"
  fi

  "$CLI_PATH" version 2>&1
}

extract_json_string() {
  key=$1
  json=$2
  printf '%s' "$json" | sed -n "s/.*\"$key\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" | head -n 1
}

extract_json_bool() {
  key=$1
  json=$2
  value=$(printf '%s' "$json" | sed -n "s/.*\"$key\"[[:space:]]*:[[:space:]]*\(true\).*/\1/p" | head -n 1)
  if [ -n "$value" ]; then
    printf '%s' "$value"
    return
  fi
  value=$(printf '%s' "$json" | sed -n "s/.*\"$key\"[[:space:]]*:[[:space:]]*\(false\).*/\1/p" | head -n 1)
  printf '%s' "$value"
}

extract_download_url() {
  key=$1
  json=$2
  printf '%s' "$json" | sed -n "s/.*\"$key\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" | head -n 1
}

print_platform_json() {
  printf '{'
  printf '"os":%s,' "$(json_string "$OS")"
  printf '"arch":%s,' "$(json_string "$ARCH")"
  printf '"detectedShell":%s,' "$(json_string "$DETECTED_SHELL")"
  printf '"preferredShell":%s,' "$(json_string "$DETECTED_SHELL")"
  if [ -n "$PROFILE_PATH" ]; then
    printf '"profilePath":%s,' "$(json_string "$PROFILE_PATH")"
  else
    printf '"profilePath":null,'
  fi
  printf '"cliFilename":%s,' "$(json_string "$CLI_FILENAME")"
  printf '"cliPath":%s,' "$(json_string "$CLI_PATH")"
  printf '"cliDownloadUrl":%s,' "$(json_string "$CLI_DOWNLOAD_URL")"
  printf '"lastCheckFile":%s,' "$(json_string "$LAST_CHECK_FILE")"
  printf '"helpCommand":%s,' "$(json_string "$HELP_COMMAND")"
  printf '"versionCommand":%s' "$(json_string "$VERSION_COMMAND")"
  printf '}'
}

# ── Config-file helpers ────────────────────────────────────────────

# Read the API key value from config.json (returns empty string if missing).
read_config_api_key() {
  if [ ! -f "$CONFIG_FILE" ]; then
    printf ''
    return
  fi
  # Extract value of "TENCENT_NEWS_APIKEY" from the JSON file (sed-only, no jq).
  sed -n "s/.*\"$API_KEY_ENV\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" "$CONFIG_FILE" | head -n 1
}

# Write (or overwrite) the API key into config.json (chmod 600).
write_config_api_key() {
  _cfg_key=$1
  mkdir -p "$CONFIG_DIR"
  printf '{\n  "%s": "%s"\n}\n' "$API_KEY_ENV" "$(json_escape "$_cfg_key")" > "$CONFIG_FILE"
  chmod 600 "$CONFIG_FILE"
}

# ── API-key status JSON ───────────────────────────────────────────
#
# Returns a JSON object describing the current API key state.
#
# Fields always present:
#   envVar, present, configFile, detectedShell, preferredShell,
#   profilePath, canAutoConfigure, verificationCommand
#
# When present=false AND the config file contains a key:
#   configFileHasKey : true
#   restoreCommand   : "export TENCENT_NEWS_APIKEY='<value>'"
#     ↑ The agent MUST execute this in its own shell before running the CLI.
#       (cli-state.sh runs as a subprocess—its export cannot propagate.)
#
# When present=false AND the config file has no key:
#   configFileHasKey : false

print_api_key_json() {
  printf '{'
  printf '"envVar":%s,' "$(json_string "$API_KEY_ENV")"

  if [ -n "${TENCENT_NEWS_APIKEY:-}" ]; then
    # Env var is set — everything is fine.
    printf '"present":true,'
    printf '"configFile":%s,' "$(json_string "$CONFIG_FILE")"
  else
    # Env var is missing — check the config file as fallback.
    _cfg_val=$(read_config_api_key)
    printf '"present":false,'
    printf '"configFile":%s,' "$(json_string "$CONFIG_FILE")"
    if [ -n "$_cfg_val" ]; then
      printf '"configFileHasKey":true,'
      printf '"restoreCommand":%s,' "$(json_string "export $API_KEY_ENV=$(quote_posix "$_cfg_val")")"
    else
      printf '"configFileHasKey":false,'
    fi
  fi

  printf '"detectedShell":%s,' "$(json_string "$DETECTED_SHELL")"
  printf '"preferredShell":%s,' "$(json_string "$DETECTED_SHELL")"
  if [ -n "$PROFILE_PATH" ]; then
    printf '"profilePath":%s,' "$(json_string "$PROFILE_PATH")"
  else
    printf '"profilePath":null,'
  fi
  printf '"canAutoConfigure":true,'
  printf '"verificationCommand":%s' "$(json_string "printf '%s\\n' \"\$TENCENT_NEWS_APIKEY\"")"
  printf '}'
}

set_api_key_env() {
  api_key=$1

  case "$OS" in
    darwin)
      # macOS: write to shell profile and use launchctl to set for GUI apps
      if [ -n "$PROFILE_PATH" ]; then
        temp_file=$(mktemp "${TMPDIR:-/tmp}/tencent-news-profile.XXXXXX")
        if [ -f "$PROFILE_PATH" ]; then
          grep -v "^[[:space:]]*export[[:space:]][[:space:]]*$API_KEY_ENV=" "$PROFILE_PATH" > "$temp_file" || true
        fi
        printf 'export %s=%s\n' "$API_KEY_ENV" "$(quote_posix "$api_key")" >> "$temp_file"
        mv "$temp_file" "$PROFILE_PATH"
      fi
      launchctl setenv "$API_KEY_ENV" "$api_key" 2>/dev/null || true
      STORAGE="macos-env"
      ;;
    linux)
      # Linux: write to shell profile; fall back to ~/.profile if shell is unsupported
      target_profile="$PROFILE_PATH"
      if [ -z "$target_profile" ]; then
        target_profile="$HOME/.profile"
      fi
      temp_file=$(mktemp "${TMPDIR:-/tmp}/tencent-news-profile.XXXXXX")
      if [ -f "$target_profile" ]; then
        grep -v "^[[:space:]]*export[[:space:]][[:space:]]*$API_KEY_ENV=" "$target_profile" > "$temp_file" || true
      fi
      printf 'export %s=%s\n' "$API_KEY_ENV" "$(quote_posix "$api_key")" >> "$temp_file"
      mv "$temp_file" "$target_profile"
      PROFILE_PATH="$target_profile"
      STORAGE="linux-shell-profile"
      ;;
    *)
      fail "unsupported os: $OS"
      ;;
  esac

  # Always mirror to the config file for cross-session persistence.
  write_config_api_key "$api_key"
}
