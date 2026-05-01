#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo_root/tests/test_helpers.sh"
source "$repo_root/lib/notify-macos.sh"

tmp_dir="$(mktemp -d)"
export CLAUDE_HARK_NOTIFY_STUB="$tmp_dir/notify.log"

notify_macos 'Claude Code' '[deploy-watch] 等待权限：Bash；目的：运行验证命令确认当前结果'
assert_eq 'Claude Code|[deploy-watch] 等待权限：Bash；目的：运行验证命令确认当前结果' "$(cat "$CLAUDE_HARK_NOTIFY_STUB")"
