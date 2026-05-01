#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/notify-macos.sh"

notify_user() {
  local title="$1"
  local body="$2"
  local os_name

  if [[ -n "${CLAUDE_HARK_NOTIFY_STUB:-}" ]]; then
    printf '%s|%s\n' "$title" "$body" > "$CLAUDE_HARK_NOTIFY_STUB"
    return
  fi

  os_name="$(uname -s)"
  case "$os_name" in
    Darwin)
      notify_macos "$title" "$body"
      ;;
    Linux)
      if command -v notify-send >/dev/null 2>&1; then
        notify-send "$title" "$body"
      else
        printf 'Claude-Hark notification: %s | %s\n' "$title" "$body" >&2
      fi
      ;;
    *)
      printf 'Claude-Hark notification: %s | %s\n' "$title" "$body" >&2
      ;;
  esac
}
