#!/usr/bin/env bash
set -euo pipefail
# 这个 shell 库负责通过 Windows 通知机制发送 Claude-Hark 提醒。

# 选择当前环境可用的 PowerShell 命令。
powershell_command() {
  if command -v powershell.exe >/dev/null 2>&1; then
    printf '%s\n' powershell.exe
    return 0
  fi
  if command -v pwsh.exe >/dev/null 2>&1; then
    printf '%s\n' pwsh.exe
    return 0
  fi
  if command -v pwsh >/dev/null 2>&1; then
    printf '%s\n' pwsh
    return 0
  fi
  if command -v powershell >/dev/null 2>&1; then
    printf '%s\n' powershell
    return 0
  fi
  return 1
}

# 通过 PowerShell Toast 或终端 fallback 发送 Windows 通知。
notify_windows() {
  local title="$1"
  local body="$2"

  if [[ -n "${CLAUDE_HARK_NOTIFY_STUB:-}" ]]; then
    printf '%s|%s\n' "$title" "$body" > "$CLAUDE_HARK_NOTIFY_STUB"
    return
  fi

  local powershell
  if ! powershell="$(powershell_command)"; then
    printf 'Claude-Hark notification: %s | %s\n' "$title" "$body" >&2
    return
  fi

  if ! "$powershell" -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command - "$title" "$body" <<'PS'
param([string]$Title, [string]$Body)

$ErrorActionPreference = 'Stop'
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

$template = @"
<toast>
  <visual>
    <binding template="ToastGeneric">
      <text></text>
      <text></text>
    </binding>
  </visual>
</toast>
"@

$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
$xml.LoadXml($template)
$textNodes = $xml.GetElementsByTagName('text')
$textNodes.Item(0).AppendChild($xml.CreateTextNode($Title)) | Out-Null
$textNodes.Item(1).AppendChild($xml.CreateTextNode($Body)) | Out-Null
$notification = [Windows.UI.Notifications.ToastNotification]::new($xml)
$notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Claude-Hark')
$notifier.Show($notification)
PS
  then
    printf 'Claude-Hark notification: %s | %s\n' "$title" "$body" >&2
  fi
}
