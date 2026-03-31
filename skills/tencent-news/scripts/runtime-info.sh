#!/bin/sh

set -eu

if [ "${1:-}" = "help" ]; then
  cat <<'EOF'
Usage: sh scripts/runtime-info.sh

Print platform info, CLI paths, and recommended help/version commands for macOS or Linux.
EOF
  exit 0
fi

. "$(dirname "$0")/_common.sh"

detect_platform

printf '{\n'
printf '  "skillDir": %s,\n' "$(json_string "$SKILL_DIR")"
printf '  "platform": %s,\n' "$(print_platform_json)"
printf '  "apiKey": %s\n' "$(print_api_key_json)"
printf '}\n'
