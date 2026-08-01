#!/usr/bin/env python3
# 这个脚本提供 shell 可调用的 Python CLI，转发 hook 摘要和处理命令。
# Thin CLI shim used by the shell hooks; keep hook logic in the focused modules.
import json
import sys

from hook_context import HookContextExtractor, context_json
from hook_handlers import handle_event
from llm_provider import LLMSummaryProvider
from session_namer import SessionNamer
from util import json_string_field, redact_sensitive_text, truncate_inline, truncate_text


# ---- CLI 适配层：供 shell shim 调用 ----
# 返回 action_summary.py 支持的 CLI 子命令映射。
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


# 输出命令结果并确保以换行结尾。
def print_result(value):
    print(value, end="")
    if not value.endswith("\n"):
        print()


# 从标准输入读取 NUL 分隔参数。
def stdin_args():
    data = sys.stdin.buffer.read()
    if not data:
        return []
    values = data.split(b"\0")
    if values[-1] == b"":
        values.pop()
    return [value.decode() for value in values]


# 解析 CLI 参数并执行对应子命令。
def main(argv):
    args = argv[1:] or stdin_args()
    if not args:
        print("usage: action_summary.py <command> [args...]", file=sys.stderr)
        return 2

    command = args[0]
    commands = command_table()
    if command not in commands:
        print(f"unknown command: {command}", file=sys.stderr)
        return 2

    try:
        print_result(commands[command](args[1:]))
    except IndexError:
        print(f"missing arguments for command: {command}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
