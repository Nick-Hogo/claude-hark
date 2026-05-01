#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo_root/tests/test_helpers.sh"
source "$repo_root/lib/notifier.sh"

tmp_dir="$(mktemp -d)"
export CLAUDE_HARK_NOTIFY_STUB="$tmp_dir/notify.log"

notify_user 'Claude Code' '[app] 等待权限：Edit；目的：准备修改 README'
assert_eq 'Claude Code|[app] 等待权限：Edit；目的：准备修改 README' "$(cat "$CLAUDE_HARK_NOTIFY_STUB")"
