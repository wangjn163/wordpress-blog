#!/bin/sh

set -eu

if [ "${1:-}" = "help" ]; then
  cat <<'EOF'
Usage: sh scripts/cli-state.sh [--update-window-seconds SECONDS]

Print install state, update-check window status, and API key status for macOS or Linux.
EOF
  exit 0
fi

. "$(dirname "$0")/_common.sh"

update_window_seconds=$DEFAULT_UPDATE_WINDOW_SECONDS

while [ "$#" -gt 0 ]; do
  case "$1" in
    --update-window-seconds)
      [ "$#" -ge 2 ] || fail "--update-window-seconds requires a value"
      update_window_seconds=$2
      shift 2
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

case "$update_window_seconds" in
  ''|*[!0-9]*)
    fail "--update-window-seconds must be a non-negative integer"
    ;;
esac

detect_platform

if [ -f "$CLI_PATH" ]; then
  cli_exists=true
else
  cli_exists=false
fi

last_check_epoch=$(read_last_check_epoch)
now_epoch=$(date +%s)

if [ $((now_epoch - last_check_epoch)) -gt "$update_window_seconds" ]; then
  needs_update_check=true
else
  needs_update_check=false
fi

printf '{\n'
printf '  "platform": %s,\n' "$(print_platform_json)"
printf '  "cliExists": %s,\n' "$(json_bool "$cli_exists")"
printf '  "lastCheckEpoch": %s,\n' "$last_check_epoch"
printf '  "nowEpoch": %s,\n' "$now_epoch"
printf '  "updateWindowSeconds": %s,\n' "$update_window_seconds"
printf '  "needsUpdateCheck": %s,\n' "$(json_bool "$needs_update_check")"
printf '  "apiKey": %s\n' "$(print_api_key_json)"
printf '}\n'
