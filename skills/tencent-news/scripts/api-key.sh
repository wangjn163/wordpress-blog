#!/bin/sh

set -eu

if [ "${1:-}" = "help" ]; then
  cat <<'EOF'
Usage: sh scripts/api-key.sh [--set KEY]

Inspect or persist the TENCENT_NEWS_APIKEY value for macOS or Linux.
EOF
  exit 0
fi

. "$(dirname "$0")/_common.sh"

api_key=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --set)
      [ "$#" -ge 2 ] || fail "--set requires a value"
      api_key=$2
      shift 2
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

detect_platform

if [ -z "$api_key" ]; then
  # Read mode: print_api_key_json already checks env var + config file fallback.
  printf '%s\n' "$(print_api_key_json)"
  exit 0
fi

# Set mode: write to shell profile + config file.
set_api_key_env "$api_key"

printf '{\n'
printf '  "envVar": %s,\n' "$(json_string "$API_KEY_ENV")"
printf '  "present": true,\n'
printf '  "detectedShell": %s,\n' "$(json_string "$DETECTED_SHELL")"
printf '  "preferredShell": %s,\n' "$(json_string "$DETECTED_SHELL")"
printf '  "profilePath": %s,\n' "$(json_string "$PROFILE_PATH")"
printf '  "canAutoConfigure": true,\n'
printf '  "configured": true,\n'
printf '  "storage": %s,\n' "$(json_string "$STORAGE")"
printf '  "configFile": %s,\n' "$(json_string "$CONFIG_FILE")"
printf '  "sessionCommand": %s,\n' "$(json_string "export $API_KEY_ENV=$(quote_posix "$api_key")")"
printf '  "verificationCommand": %s,\n' "$(json_string "printf '%s\\n' \"\$TENCENT_NEWS_APIKEY\"")"
printf '  "requiresNewTerminal": false,\n'
printf '  "note": %s\n' "$(json_string "Run sessionCommand in the current terminal if you need the key immediately.")"
printf '}\n'
