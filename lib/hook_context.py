# 这个模块负责把 Claude Code hook payload 转换成脱敏后的结构化上下文。
# Shared hook payload parsing; this module extracts facts, not intent.
import json
from dataclasses import asdict, dataclass
from typing import Optional

from util import basename, json_string_field, load_json, redact_sensitive_text, truncate_inline, truncate_text


# 将 HookContext 或字典格式化为稳定的 JSON 文本。
def context_json(context):
    data = context.to_dict() if isinstance(context, HookContext) else context
    return json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True)


@dataclass
# 保存 hook payload 中已脱敏、可展示和可分析的结构化字段。
class HookContext:
    event_kind: str
    tool_name: str
    target: str
    file_path: Optional[str]
    file_name: Optional[str]
    command: Optional[str]
    command_preview: Optional[str]
    pattern: Optional[str]
    path: Optional[str]
    query: Optional[str]
    old_string_line_count: Optional[int]
    old_string_length: int
    new_string_length: int
    content_length: int
    content_preview: Optional[str]
    contains_redacted: bool

    # 将 dataclass 上下文转换为普通字典。
    def to_dict(self):
        return asdict(self)


# 从原始 hook payload 中提取工具、输入和目标信息。
class HookContextExtractor:
    @staticmethod
    # 从 hook payload 中读取工具名称。
    def extract_tool_name(payload_json):
        payload = load_json(payload_json, {})
        value = payload.get("tool_name", "unknown") if isinstance(payload, dict) else "unknown"
        return value if isinstance(value, str) else "unknown"

    @staticmethod
    # 从 hook payload 中读取工具输入并序列化成紧凑 JSON。
    def extract_tool_input_json(payload_json):
        payload = load_json(payload_json, {})
        tool_input = payload.get("tool_input", {}) if isinstance(payload, dict) else {}
        if not isinstance(tool_input, dict):
            tool_input = {}
        return json.dumps(tool_input, ensure_ascii=False, separators=(",", ":"))

    @classmethod
    # 根据事件、工具和输入生成统一的 HookContext。
    def extract(cls, event_kind, tool_name, tool_input_json):
        file_path = json_string_field(tool_input_json, "file_path")
        command_text = redact_sensitive_text(json_string_field(tool_input_json, "command"))
        old_string = redact_sensitive_text(json_string_field(tool_input_json, "old_string"))
        new_string = redact_sensitive_text(json_string_field(tool_input_json, "new_string"))
        content = redact_sensitive_text(json_string_field(tool_input_json, "content"))
        pattern = redact_sensitive_text(json_string_field(tool_input_json, "pattern"))
        path = json_string_field(tool_input_json, "path")
        query = redact_sensitive_text(json_string_field(tool_input_json, "query"))
        target = cls.target_for(tool_name, file_path, command_text, pattern, path)

        return HookContext(
            event_kind=event_kind,
            tool_name=tool_name,
            target=target,
            file_path=file_path or None,
            file_name=basename(file_path) if file_path else None,
            command=command_text or None,
            command_preview=truncate_inline(command_text, 120) if command_text else None,
            pattern=truncate_inline(pattern, 120) if pattern else None,
            path=path or None,
            query=truncate_inline(query, 120) if query else None,
            old_string_line_count=max(1, len(old_string.splitlines())) if old_string else None,
            old_string_length=len(old_string) if old_string else 0,
            new_string_length=len(new_string) if new_string else 0,
            content_length=len(content) if content else 0,
            content_preview=truncate_inline(content, 120) if content else None,
            contains_redacted="[REDACTED]" in "\n".join([old_string, new_string, content, command_text, pattern, query]),
        )

    @staticmethod
    # 根据工具类型和输入推断这次操作的展示目标。
    def target_for(tool_name, file_path, command_text, pattern, path):
        if tool_name in ("Edit", "Write") and file_path:
            return basename(file_path)
        if tool_name == "Bash" and command_text:
            return truncate_text(command_text, 80)
        if tool_name in ("Grep", "Glob") and pattern:
            return truncate_inline(f"{pattern} @ {path}", 64) if path else truncate_inline(pattern, 64)
        return tool_name
