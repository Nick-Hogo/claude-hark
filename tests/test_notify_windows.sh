#!/usr/bin/env bash
set -euo pipefail
# 这个测试脚本验证 Windows 通知后端的命令选择和 fallback 行为。

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo_root/tests/test_helpers.sh"
source "$repo_root/lib/notify-windows.sh"

tmp_dir="$(mktemp -d)"
export CLAUDE_HARK_NOTIFY_STUB="$tmp_dir/notify.log"

notify_windows 'Claude Code' '[deploy-watch] 等待权限：Bash；目的：运行验证命令确认当前结果'
assert_eq 'Claude Code|[deploy-watch] 等待权限：Bash；目的：运行验证命令确认当前结果' "$(cat "$CLAUDE_HARK_NOTIFY_STUB")"

unset CLAUDE_HARK_NOTIFY_STUB
fake_bin="$tmp_dir/bin"
mkdir -p "$fake_bin"

cat > "$fake_bin/powershell.exe" <<'SH'
#!/usr/bin/env bash
printf 'powershell:%s\n' "$*" >> "$CLAUDE_HARK_FAKE_NOTIFY_LOG"
printf 'title:%s\nbody:%s\nwsl-env:%s\n' "$CLAUDE_HARK_TOAST_TITLE" "$CLAUDE_HARK_TOAST_BODY" "${WSLENV:-}" >> "$CLAUDE_HARK_FAKE_NOTIFY_LOG"
script="$(cat)"
printf 'script:%s\n' "$script" >> "$CLAUDE_HARK_FAKE_NOTIFY_LOG"
SH
chmod +x "$fake_bin/powershell.exe"
CLAUDE_HARK_FAKE_NOTIFY_LOG="$tmp_dir/backend.log" PATH="$fake_bin:$PATH" notify_windows 'Claude Code' 'toast body'
backend_log="$(cat "$tmp_dir/backend.log")"
assert_contains "$backend_log" 'powershell:-NoProfile -NonInteractive -ExecutionPolicy Bypass -Command -'
assert_not_contains "$backend_log" '-Command - Claude Code toast body'
assert_contains "$backend_log" 'title:Claude Code'
assert_contains "$backend_log" 'body:toast body'
assert_contains "$backend_log" 'CLAUDE_HARK_TOAST_TITLE:CLAUDE_HARK_TOAST_BODY'
assert_contains "$backend_log" "WindowsPowerShell\\v1.0\\powershell.exe'"

cat > "$fake_bin/powershell.exe" <<'SH'
#!/usr/bin/env bash
exit 1
SH
chmod +x "$fake_bin/powershell.exe"
CLAUDE_HARK_FAKE_NOTIFY_LOG="$tmp_dir/fail.log" PATH="$fake_bin:$PATH" notify_windows 'Claude Code' 'fallback body' 2> "$tmp_dir/stderr.log"
assert_contains "$(cat "$tmp_dir/stderr.log")" 'Claude-Hark notification: Claude Code | fallback body'
