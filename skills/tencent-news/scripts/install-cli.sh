#!/bin/sh

set -eu

if [ "${1:-}" = "help" ]; then
  cat <<'EOF'
Usage: sh scripts/install-cli.sh [--url DOWNLOAD_URL]

Download the current-platform CLI into the skill directory and verify it with version.
EOF
  exit 0
fi

. "$(dirname "$0")/_common.sh"

download_url=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --url)
      [ "$#" -ge 2 ] || fail "--url requires a value"
      download_url=$2
      shift 2
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

detect_platform

if [ -z "$download_url" ]; then
  download_url="$CLI_DOWNLOAD_URL"
fi

download_file "$download_url" "$CLI_PATH"
chmod +x "$CLI_PATH"

raw_version_output=$(run_cli_version)
compact_version_output=$(printf '%s' "$raw_version_output" | compact_text)
current_version=$(extract_json_string "current_version" "$compact_version_output")
latest_version=$(extract_json_string "latest_version" "$compact_version_output")

printf '{\n'
printf '  "installed": true,\n'
printf '  "platform": %s,\n' "$(print_platform_json)"
printf '  "downloadUrl": %s,\n' "$(json_string "$download_url")"
if [ -n "$current_version" ]; then
  printf '  "currentVersion": %s,\n' "$(json_string "$current_version")"
else
  printf '  "currentVersion": null,\n'
fi
if [ -n "$latest_version" ]; then
  printf '  "latestVersion": %s,\n' "$(json_string "$latest_version")"
else
  printf '  "latestVersion": null,\n'
fi
printf '  "rawVersionOutput": %s\n' "$(json_string "$compact_version_output")"
printf '}\n'
