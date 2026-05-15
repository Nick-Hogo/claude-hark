# Troubleshooting

Run `claude-hark doctor` to verify that `jq`, the platform notifier, and the session state store are available.

## Common issues

- `jq: missing` — install jq and rerun `claude-hark doctor`.
- No notification appears — run `claude-hark doctor` to confirm whether `terminal-notifier` or `osascript` is active, then enable notifications for that app in macOS settings.
- Hook appears idle — confirm the expected `PreToolUse`, `PermissionRequest`, and `Elicitation` entries exist in `~/.claude/settings.json` and point to `claude-hark.sh`.
- State is not where you expected — by default Claude-Hark writes to `<project>/.claude-hark/state.json`; set `CLAUDE_HARK_HOME` to force another directory.
- Permission notifications use generic text — the recent `PreToolUse` summary may be missing or stale; Claude-Hark falls back to local rules after `CLAUDE_HARK_INTENT_TTL_SECONDS`.
- AI session names never appear — run `claude-hark doctor` and check whether it reports `session namer: configured`; otherwise Claude-Hark falls back to repo/branch alias rules.
- AI session names stay generic — manual aliases are never overwritten, and namer failures, timeouts, empty output, or invalid JSON intentionally keep the existing fallback alias.
- LLM summaries never appear — run `claude-hark doctor` and check whether it reports `summarizer: configured`.
- LLM summaries are slow or missing — fallback is expected when `CLAUDE_HARK_SUMMARIZER_COMMAND` fails or exceeds `CLAUDE_HARK_SUMMARIZER_TIMEOUT`.
- Prompt-rendered notification bodies fall back to the fixed template — check `<project>/.claude-hark/error.log` for `ERROR prompt-renderer ...` lines.

## Prompt renderer error log

When prompt body rendering fails, Claude-Hark appends a readable error line to `<project>/.claude-hark/error.log`. Set `CLAUDE_HARK_HOME` to move the runtime directory, or `CLAUDE_HARK_ERROR_LOG` to choose the exact log file.

Common reasons:

- `timeout` — `claude -p` exceeded `CLAUDE_HARK_BODY_RENDERER_TIMEOUT`; increase the timeout if prompt rendering is expected to be slow.
- `command_missing` — the command is empty, not found, or cannot be executed in the hook environment.
- `nonzero_exit` — the command ran but exited with a non-zero status.
- `empty_output` — the command succeeded but printed no usable body.
- `guard_active` — recursive rendering was blocked by `CLAUDE_HARK_BODY_RENDERING=1`.

Set `CLAUDE_HARK_BODY_RENDERER=template` to force the fixed template and skip prompt body rendering.

## Notes on `claude -p` summarizers

Calling `claude -p` from a hook is optional and can add latency, cost, and recursion risk. Claude-Hark mitigates this by setting `CLAUDE_HARK_SUMMARIZING=1`, sanitizing payloads, applying a timeout, and falling back to rule summaries. If recursive hook behavior still appears, disable `CLAUDE_HARK_SUMMARIZER_COMMAND` and verify the default flow first.
