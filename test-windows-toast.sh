#!/usr/bin/env bash
set -euo pipefail

title="${1:-Claude-Hark 测试}"
body="${2:-这条通知来自 WSL}"

if ! command -v powershell.exe >/dev/null 2>&1; then
  printf '未找到 powershell.exe，请确认 WSL 已启用 Windows 互操作。\n' >&2
  exit 1
fi

CLAUDE_HARK_TITLE="$title" \
CLAUDE_HARK_BODY="$body" \
WSLENV="${WSLENV:+$WSLENV:}CLAUDE_HARK_TITLE:CLAUDE_HARK_BODY" \
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command - <<'PS'
$ErrorActionPreference = 'Stop'
$title = $env:CLAUDE_HARK_TITLE
$body = $env:CLAUDE_HARK_BODY
if ([string]::IsNullOrEmpty($title) -or [string]::IsNullOrEmpty($body)) {
  throw 'WSL environment variable propagation failed'
}

Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.MessageBox]::Show($body, $title) | Out-Null
PS

printf 'Windows 弹窗测试完成。\n'
