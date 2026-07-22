#!/usr/bin/env bash
set -euo pipefail
# 这个测试脚本验证 macOS 通知后端的转义和 fallback 行为。

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo_root/tests/test_helpers.sh"
source "$repo_root/lib/notify-macos.sh"

tmp_dir="$(mktemp -d)"
export CLAUDE_HARK_NOTIFY_STUB="$tmp_dir/notify.log"

notify_macos 'Claude Code' '[deploy-watch] 等待权限：Bash；目的：运行验证命令确认当前结果'
assert_eq 'Claude Code|[deploy-watch] 等待权限：Bash；目的：运行验证命令确认当前结果' "$(cat "$CLAUDE_HARK_NOTIFY_STUB")"

unset CLAUDE_HARK_NOTIFY_STUB
fake_bin="$tmp_dir/bin"
mkdir -p "$fake_bin"

cat > "$fake_bin/terminal-notifier" <<'SH'
#!/usr/bin/env bash
printf 'terminal-notifier:%s\n' "$*" >> "$CLAUDE_HARK_FAKE_NOTIFY_LOG"
SH
chmod +x "$fake_bin/terminal-notifier"
CLAUDE_HARK_FAKE_NOTIFY_LOG="$tmp_dir/backend.log" PATH="$fake_bin:$PATH" notify_macos 'Claude Code' 'terminal notifier body'
assert_contains "$(cat "$tmp_dir/backend.log")" 'terminal-notifier:-title Claude Code -message terminal notifier body'

rm "$fake_bin/terminal-notifier"
cat > "$fake_bin/osascript" <<'SH'
#!/usr/bin/env bash
printf 'osascript:%s\n' "$*" >> "$CLAUDE_HARK_FAKE_NOTIFY_LOG"
SH
chmod +x "$fake_bin/osascript"
CLAUDE_HARK_FAKE_NOTIFY_LOG="$tmp_dir/fallback.log" PATH="$fake_bin:/usr/bin:/bin" notify_macos 'Claude Code' 'osascript body'
assert_contains "$(cat "$tmp_dir/fallback.log")" 'osascript:-e display notification "osascript body" with title "Claude Code"'
