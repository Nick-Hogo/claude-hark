#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

bash "$repo_root/tests/test_layout.sh"
bash "$repo_root/tests/test_session_state.sh"
bash "$repo_root/tests/test_action_summary.sh"
bash "$repo_root/tests/test_notifier.sh"
bash "$repo_root/tests/test_notify_macos.sh"
bash "$repo_root/tests/test_hook_flow.sh"
bash "$repo_root/tests/test_notify_blocked.sh"
bash "$repo_root/tests/test_cli.sh"
bash "$repo_root/tests/test_install.sh"
