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

  # Windows PowerShell 5.1 rejects arguments after `-Command -`. WSLENV safely
  # carries UTF-8 title/body through WSL interop without interpolating them into PowerShell.
  if ! CLAUDE_HARK_TOAST_TITLE="$title" CLAUDE_HARK_TOAST_BODY="$body" \
    WSLENV="${WSLENV:+$WSLENV:}CLAUDE_HARK_TOAST_TITLE:CLAUDE_HARK_TOAST_BODY" \
    "$powershell" -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command - <<'PS'
$ErrorActionPreference = 'Stop'
$Title = $env:CLAUDE_HARK_TOAST_TITLE
$Body = $env:CLAUDE_HARK_TOAST_BODY
if ([string]::IsNullOrWhiteSpace($Title) -or [string]::IsNullOrWhiteSpace($Body)) {
  throw 'Claude-Hark toast text propagation failed'
}
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
# Use Windows' existing registered PowerShell AppID. This avoids requiring users
# to install a shortcut, edit the registry, or run a Windows-side setup step.
$appId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
$notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId)
$notifier.Show($notification)
PS
  then
    printf 'Claude-Hark notification: %s | %s\n' "$title" "$body" >&2
  fi
}
