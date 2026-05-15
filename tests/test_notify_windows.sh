#!/usr/bin/env bash
set -euo pipefail

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
script="$(cat)"
printf 'script:%s\n' "$script" >> "$CLAUDE_HARK_FAKE_NOTIFY_LOG"
SH
chmod +x "$fake_bin/powershell.exe"
CLAUDE_HARK_FAKE_NOTIFY_LOG="$tmp_dir/backend.log" PATH="$fake_bin:$PATH" notify_windows 'Claude Code' 'toast body'
assert_contains "$(cat "$tmp_dir/backend.log")" 'powershell:-NoProfile -NonInteractive -ExecutionPolicy Bypass -Command - Claude Code toast body'
assert_contains "$(cat "$tmp_dir/backend.log")" "CreateToastNotifier('Claude-Hark')"

cat > "$fake_bin/powershell.exe" <<'SH'
#!/usr/bin/env bash
exit 1
SH
chmod +x "$fake_bin/powershell.exe"
CLAUDE_HARK_FAKE_NOTIFY_LOG="$tmp_dir/fail.log" PATH="$fake_bin:$PATH" notify_windows 'Claude Code' 'fallback body' 2> "$tmp_dir/stderr.log"
assert_contains "$(cat "$tmp_dir/stderr.log")" 'Claude-Hark notification: Claude Code | fallback body'
