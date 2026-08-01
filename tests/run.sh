#!/usr/bin/env bash
set -euo pipefail
# 这个脚本负责按顺序运行 Claude-Hark 的全部 shell 测试。

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

bash "$repo_root/tests/test_layout.sh"
bash "$repo_root/tests/test_doc_contract.sh"
bash "$repo_root/tests/test_session_state.sh"
bash "$repo_root/tests/test_action_summary.sh"
bash "$repo_root/tests/test_notifier.sh"
bash "$repo_root/tests/test_notify_macos.sh"
bash "$repo_root/tests/test_notify_windows.sh"
bash "$repo_root/tests/test_hook_flow.sh"
bash "$repo_root/tests/test_cli.sh"
bash "$repo_root/tests/test_install.sh"
