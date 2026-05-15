#!/usr/bin/env bash
set -euo pipefail

# ---- macOS 通知适配 ----
notify_macos() {
  local title="$1"
  local body="$2"

  if [[ -n "${CLAUDE_HARK_NOTIFY_STUB:-}" ]]; then
    printf '%s|%s\n' "$title" "$body" > "$CLAUDE_HARK_NOTIFY_STUB"
    return
  fi

  # terminal-notifier renders multiline bodies better than osascript.
  if command -v terminal-notifier >/dev/null 2>&1; then
    terminal-notifier -title "$title" -message "$body"
    return
  fi

  local escaped_title escaped_body
  escaped_title=${title//\"/\\\"}
  escaped_body=${body//\"/\\\"}
  osascript -e "display notification \"$escaped_body\" with title \"$escaped_title\""
}
