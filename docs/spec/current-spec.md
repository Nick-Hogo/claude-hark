# Claude-Hark Current Product Spec

> **Status: CURRENT**
> Effective: 2026-07-30 · Requirement: `update-product-core-roadmap`

This is the single current source for Claude-Hark product scope, lifecycle-event semantics, platform commitments, and stable-release gates. `README.md` explains usage; `docs/architecture.md` and `docs/configuration.md` describe technical implementation and canonical Hook configuration.

## Product Definition

Claude-Hark is a local-first execution-boundary governance tool and lifecycle console for individual developers running multiple Claude Code sessions. It routes attention when an Agent needs human intervention and preserves a bounded local history for context recovery.

The product north star is:

> Reduce continuous screen monitoring and context-recovery cost without silently missing a critical human-intervention boundary.

## Users and Boundaries

Primary users are individual developers and advanced coding operators running multiple Claude Code sessions. Claude-Hark is not a replacement Agent framework, does not make permission decisions, and does not require an MCP server, skill, remote service, or external LLM.

- **P0 — execution-boundary governance:** Hook capture, session identity, purpose fallback, intervention notification, local event recording, and safe degradation.
- **P1 — lifecycle console:** bounded history and Dashboard views for active work, intervention tasks, completion, and failure review. P1 failure must not block P0.
- **Not current scope:** cloud sync, cross-device state, team policy/RBAC/compliance, or automatic permission approval/rejection.

## Lifecycle Event Contract

All listed events update `latestAction` and append one history entry under the current implementation. “Dashboard lane” defines the intended product presentation. `Notification(permission_prompt)` is an active evidence record: it does not duplicate a system notification and does not create a separate intervention task.

<!-- EVENT-MATRIX:BEGIN -->
| Event | Record | Status | System notification | Dashboard lane | Session namer |
|---|---|---|---|---|---|
| `user-prompt-submit` | latest + history | active | No | Active | No |
| `pre-tool-use` | latest + history | active | No | Active | Optional, first eligible event |
| `post-tool-use` | latest + history | active | No | Active | No |
| `post-tool-use-failure` | latest + history | active | No | Active | No |
| `permission` | latest + history | notified | Yes | Tasks | No |
| `notification` | latest + history; only `permission_prompt` | active | No duplicate | Active | No |
| `elicitation` | latest + history | notified | Yes | Tasks | No |
| `stop` | latest + history | waiting_for_user | No | Review | No |
| `stop-failure` | latest + history | failed | No | Review | No |
<!-- EVENT-MATRIX:END -->

Canonical Claude Code event names, matchers, commands, and timeouts are maintained only in [`docs/configuration.md`](../configuration.md). The runtime composition root is `hooks/claude-hark.sh`.

### Intervention Notification Contract

`permission` and `elicitation` notifications optimize for immediate session localization and intent recovery:

```text
[session-alias] intervention · tool/type

意图：why this operation or decision advances the current task
操作/需要：the exact payload fact or elicitation request
```

- Session alias, tool name, command, file, MCP name, and request text are deterministic facts. They must come from the Hook payload or local session state and must not be rewritten or invented by an LLM.
- Operation intent is an inference. It may use the current payload, the current-turn Hook history, the latest user goal, and the assistant text immediately preceding the tool call from `transcript_path`.
- Conversation extraction is bounded, local, redacted, and excludes system messages, thinking blocks, tool results, and unrelated earlier turns. A missing or unreadable transcript must not block the Hook.
- The latest `user-prompt-submit` is the default task boundary. History sent for inference is a compact projection, not persisted prompts or complete display objects.
- An intent must explain the result sought by the operation. Merely restating “run a command/script”, “edit a file”, or “advance the task” is not a valid intent.
- When evidence is insufficient, the notification explicitly says the intent cannot be determined. Required semantic fields must not be populated with plausible fixed values.
- The LLM explains but never approves, rejects, changes, or hides the requested operation. Notification failure or LLM failure must not prevent local event recording and safe fallback.

## Platform Support

Support levels are product commitments, not an inventory of code paths. “Experimental” means best effort with incomplete installation, CI, or real-desktop evidence.

<!-- SUPPORT-MATRIX:BEGIN -->
| Platform | Level | Current commitment | Promotion evidence |
|---|---|---|---|
| macOS | Stable | Installer, doctor, terminal-notifier/osascript path, and core lifecycle flow | CI plus real desktop notification smoke |
| Linux desktop | Experimental | `notify-send` when available; fallback remains diagnostic | Declared distro range, CI, doctor, and real desktop validation |
| WSL | Experimental | Best-effort PowerShell bridge where available | WSL version matrix, path/install contract, and real toast validation |
| Native Windows | Experimental | Notification adapter experiment; not a promise of a complete Bash+jq runtime | Native runtime/install design, CI, and real Windows E2E |
<!-- SUPPORT-MATRIX:END -->

## Product Acceptance Index

| Area | Current acceptance direction | Delivery phase |
|---|---|---|
| State reliability | One event is one logical transaction; concurrent accepted events are not silently lost | Phase 2 |
| LLM fallback | Prompt/payload input, source, timeout, and fallback match their documented contract | Phase 2 |
| Data/privacy | Versioned schema, minimum persistence, bounded history, and tested redaction | Phase 3 |
| Installer | Backup, non-destructive merge, idempotent upgrade, scoped uninstall | Phase 4 |
| Platform diagnosis | Doctor reports backend availability and Stable/Experimental level honestly | Phase 4 |
| Dashboard | Versioned consumer contract, stale/error visibility, automated build and behavior tests | Phase 5 |
| Architecture/release | Lower god-node coupling and complete open-source release assets | Phase 6 |

Known current gaps are not silently rewritten as delivered behavior: state concurrency, minimum persistence, non-destructive installer merge, platform-aware doctor tests, and Dashboard test coverage remain scheduled work in the approved GudaSpec plan. The summarizer accepts prompt input only; the former payload input mode is not part of the current contract.

## Stable v1 Release Gates

<!-- RELEASE-GATE:BEGIN -->
- [ ] RG-1: P0 concurrent event, transaction, large-payload, malformed-input, and fallback invariants pass. Verification: Phase 2 deterministic and seeded stress tests.
- [ ] RG-2: State schema/version, compatibility, retention, and privacy minimization pass. Verification: Phase 3 fixtures, migration checks, and secret corpus.
- [ ] RG-3: Installer backup, non-destructive merge, idempotent upgrade, and scoped uninstall pass. Verification: Phase 4 JSON fixture/property tests.
- [ ] RG-4: macOS Stable evidence is complete. Verification: macOS CI and a recorded real notifier smoke check.
- [ ] RG-5: Dashboard consumer and quality gates pass. Verification: Phase 5 server/UI tests plus build, lint, and typecheck gates selected in that phase.
- [ ] RG-6: Product documentation and platform statements match implementation. Verification: `tests/test_doc_contract.sh` and release review.
- [ ] RG-7: Open-source release assets exist. Verification: LICENSE, version policy, changelog, upgrade/uninstall notes, and completed release checklist.
<!-- RELEASE-GATE:END -->

Until all gates pass, the project remains a 0.x developer preview. Linux, WSL, and Native Windows remain Experimental unless their promotion evidence is independently satisfied.

## Historical Rationale

The original hook-first reasoning, local-only trust model, alias fallback, and “explain rather than decide” principle remain valuable. Earlier scope promises and implementation steps have been superseded as the codebase added lifecycle history, Dashboard, Python handlers, and experimental platform adapters.

See [`docs/superpowers/README.md`](../superpowers/README.md) for the historical index and traceability notes.
