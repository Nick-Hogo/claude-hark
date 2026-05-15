#!/usr/bin/env bash
set -euo pipefail

# ---- 平台通知实现加载 ----
notifier_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$notifier_dir/notify-macos.sh"
source "$notifier_dir/notify-windows.sh"

# ---- 统一通知入口 ----
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
      if [[ "${OS:-}" == "Windows_NT" ]]; then
        notify_windows "$title" "$body"
      elif command -v notify-send >/dev/null 2>&1; then
        notify-send "$title" "$body"
      else
        printf 'Claude-Hark notification: %s | %s\n' "$title" "$body" >&2
      fi
      ;;
    MINGW*|MSYS*|CYGWIN*)
      notify_windows "$title" "$body"
      ;;
    *)
      if [[ "${OS:-}" == "Windows_NT" ]]; then
        notify_windows "$title" "$body"
      else
        printf 'Claude-Hark notification: %s | %s\n' "$title" "$body" >&2
      fi
      ;;
  esac
}
