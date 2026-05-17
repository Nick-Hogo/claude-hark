#!/usr/bin/env python3
# Thin CLI shim used by the shell hooks; keep hook logic in the focused modules.
import json
import sys

from hook_context import HookContextExtractor, context_json
from hook_handlers import handle_event
from llm_provider import LLMSummaryProvider
from session_namer import SessionNamer
from util import json_string_field, redact_sensitive_text, truncate_inline, truncate_text


# ---- CLI 适配层：供 shell shim 调用 ----
def command_table():
    return {
        "extract-tool-name": lambda args: HookContextExtractor.extract_tool_name(args[0]),
        "extract-tool-input-json": lambda args: HookContextExtractor.extract_tool_input_json(args[0]),
        "extract-hook-context": lambda args: context_json(HookContextExtractor.extract(args[0], args[1], args[2]).to_dict()),
        "json-string-field": lambda args: json_string_field(args[0], args[1]),
        "truncate-text": lambda args: truncate_text(args[0], int(args[1]) if len(args) > 1 else 500),
        "truncate-inline": lambda args: truncate_inline(args[0], int(args[1]) if len(args) > 1 else 48),
        "action-target": lambda args: HookContextExtractor.extract("permission", args[0], args[1]).target or args[0],
        "handle-event": lambda args: handle_event(args[0], args[1], args[2] if len(args) > 2 else "[]"),
        "redact-sensitive-text": lambda args: redact_sensitive_text(args[0]),
        "sanitize-action-payload": lambda args: LLMSummaryProvider.sanitize_payload(args[0], args[1], args[2]),
        "normalize-action-summary": lambda args: LLMSummaryProvider.normalize(args[0]),
        "action-summary-source": lambda args: LLMSummaryProvider().source(),
        "session-namer-available": lambda args: "configured" if SessionNamer().available() else "disabled",
        "generate-session-metadata": lambda args: json.dumps(
            SessionNamer().generate(args[0], args[1], args[2], args[3], args[4]), ensure_ascii=False, separators=(",", ":")
        ),
    }


def print_result(value):
    print(value, end="")
    if not value.endswith("\n"):
        print()


def main(argv):
    if len(argv) < 2:
        print("usage: action_summary.py <command> [args...]", file=sys.stderr)
        return 2

    command = argv[1]
    commands = command_table()
    if command not in commands:
        print(f"unknown command: {command}", file=sys.stderr)
        return 2

    try:
        print_result(commands[command](argv[2:]))
    except IndexError:
        print(f"missing arguments for command: {command}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
