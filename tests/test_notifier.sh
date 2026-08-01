#!/usr/bin/env bash
set -euo pipefail
# 这个测试脚本验证通知分发层会调用正确的平台后端或 stub。

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo_root/tests/test_helpers.sh"
source "$repo_root/lib/notifier.sh"

tmp_dir="$(mktemp -d)"
export CLAUDE_HARK_NOTIFY_STUB="$tmp_dir/notify.log"

notify_user 'Claude Code' '[app] 等待权限：Edit；目的：准备修改 README'
assert_eq 'Claude Code|[app] 等待权限：Edit；目的：准备修改 README' "$(cat "$CLAUDE_HARK_NOTIFY_STUB")"

unset CLAUDE_HARK_NOTIFY_STUB
notify_windows() {
  printf 'windows:%s|%s\n' "$1" "$2" > "$tmp_dir/backend.log"
}
notify-send() {
  printf 'linux:%s|%s\n' "$1" "$2" > "$tmp_dir/backend.log"
}

# WSL must use the Windows bridge even when OS=Windows_NT is absent and
# notify-send happens to be installed inside the distribution.
WSL_INTEROP=/run/WSL/test_interop WSL_DISTRO_NAME= OS= notify_user 'Claude-Hark' 'WSL toast'
assert_eq 'windows:Claude-Hark|WSL toast' "$(cat "$tmp_dir/backend.log")"

WSL_INTEROP= WSL_DISTRO_NAME=Ubuntu-22.04 OS= notify_user 'Claude-Hark' 'WSL distro toast'
assert_eq 'windows:Claude-Hark|WSL distro toast' "$(cat "$tmp_dir/backend.log")"
