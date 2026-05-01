# Troubleshooting

Run `claude-hark doctor` to verify that `jq`, the platform notifier, and the session state store are available.

## Common issues

- `jq: missing` — install jq and rerun `claude-hark doctor`.
- No notification appears — verify macOS notifications are enabled for the terminal app running Claude Code.
- Hook appears idle — confirm the expected `PreToolUse`, `PermissionRequest`, and `Elicitation` entries exist in `~/.claude/settings.json` and point to `claude-hark.sh`.
- State is not where you expected — by default Claude-Hark writes to `<project>/.claude-hark/state.json`; set `CLAUDE_HARK_HOME` to force another directory.
- Permission notifications use generic text — the recent `PreToolUse` summary may be missing or stale; Claude-Hark falls back to local rules after `CLAUDE_HARK_INTENT_TTL_SECONDS`.
- LLM summaries never appear — run `claude-hark doctor` and check whether it reports `summarizer: configured`.
- LLM summaries are slow or missing — fallback is expected when `CLAUDE_HARK_SUMMARIZER_COMMAND` fails or exceeds `CLAUDE_HARK_SUMMARIZER_TIMEOUT`.

## Notes on `claude -p` summarizers

Calling `claude -p` from a hook is optional and can add latency, cost, and recursion risk. Claude-Hark mitigates this by setting `CLAUDE_HARK_SUMMARIZING=1`, sanitizing payloads, applying a timeout, and falling back to rule summaries. If recursive hook behavior still appears, disable `CLAUDE_HARK_SUMMARIZER_COMMAND` and verify the default flow first.
