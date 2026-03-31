#!/bin/sh

set -eu

if [ "${1:-}" = "help" ]; then
  cat <<'EOF'
Usage: sh scripts/check-update.sh [--apply]

Inspect the CLI version JSON and optionally download the newer binary for macOS or Linux.
EOF
  exit 0
fi

. "$(dirname "$0")/_common.sh"

apply_update=false

while [ "$#" -gt 0 ]; do
  case "$1" in
    --apply)
      apply_update=true
      shift
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

detect_platform

if [ ! -f "$CLI_PATH" ]; then
  fail "cli not found at $CLI_PATH. Run sh scripts/install-cli.sh first."
fi

raw_before=$(run_cli_version)
compact_before=$(printf '%s' "$raw_before" | compact_text)
need_update=$(extract_json_bool "need_update" "$compact_before")
current_version=$(extract_json_string "current_version" "$compact_before")
latest_version=$(extract_json_string "latest_version" "$compact_before")
release_notes=$(extract_json_string "release_notes" "$compact_before")
selected_download_url=$(extract_download_url "${OS}_${ARCH}" "$compact_before")

if [ -z "$selected_download_url" ]; then
  selected_download_url="$CLI_DOWNLOAD_URL"
fi

applied=false
raw_after=$compact_before
after_current_version=$current_version

if [ "$apply_update" = "true" ] && [ "$need_update" = "true" ]; then
  download_file "$selected_download_url" "$CLI_PATH"
  chmod +x "$CLI_PATH"
  raw_after=$(run_cli_version | compact_text)
  after_current_version=$(extract_json_string "current_version" "$raw_after")
  applied=true
fi

checked_at=$(write_last_check_epoch)

printf '{\n'
printf '  "platform": %s,\n' "$(print_platform_json)"
printf '  "checkedAt": %s,\n' "$checked_at"
printf '  "needUpdate": %s,\n' "$(json_bool "${need_update:-false}")"
printf '  "applied": %s,\n' "$(json_bool "$applied")"
printf '  "selectedDownloadUrl": %s,\n' "$(json_string "$selected_download_url")"
if [ -n "$after_current_version" ]; then
  printf '  "currentVersion": %s,\n' "$(json_string "$after_current_version")"
else
  printf '  "currentVersion": null,\n'
fi
if [ -n "$latest_version" ]; then
  printf '  "latestVersion": %s,\n' "$(json_string "$latest_version")"
else
  printf '  "latestVersion": null,\n'
fi
if [ -n "$release_notes" ]; then
  printf '  "releaseNotes": %s,\n' "$(json_string "$release_notes")"
else
  printf '  "releaseNotes": null,\n'
fi
printf '  "rawBefore": %s,\n' "$(json_string "$compact_before")"
printf '  "rawAfter": %s\n' "$(json_string "$raw_after")"
printf '}\n'
