#!/usr/bin/env bash
set -euo pipefail
# 这个 shell 库负责选择平台通知后端并发送桌面通知。

# ---- 平台通知实现加载 ----
notifier_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$notifier_dir/notify-macos.sh"
source "$notifier_dir/notify-windows.sh"

# ---- 平台检测 ----
# WSL 不保证设置 OS=Windows_NT，因此同时检查官方环境变量和内核标识。
is_wsl() {
  [[ -n "${WSL_INTEROP:-}" ]] ||
    [[ -n "${WSL_DISTRO_NAME:-}" ]] ||
    grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null
}

# ---- 统一通知入口 ----
# 向用户发送通知，优先使用测试 stub 再选择系统后端。
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
      if is_wsl || [[ "${OS:-}" == "Windows_NT" ]]; then
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
