# 通用工具函数：JSON 解析、文本截断、敏感信息脱敏，供所有模块复用。
import json
import os
import re
from pathlib import PurePath

DEFAULT_SUMMARY_MAX_CHARS = 80
SENSITIVE_PATTERNS = [
    r"(?i)(api[_-]?key\s*[=:]\s*)[^\s,;]+",
    r"(?i)(token\s*[=:]\s*)[^\s,;]+",
    r"(?i)(password\s*[=:]\s*)[^\s,;]+",
    r"(?i)(secret\s*[=:]\s*)[^\s,;]+",
]


def summary_max_chars():
    """读取环境变量中配置的摘要最大字符数，默认 DEFAULT_SUMMARY_MAX_CHARS。"""
    return int(os.environ.get("CLAUDE_HARK_SUMMARY_MAX_CHARS", str(DEFAULT_SUMMARY_MAX_CHARS)))


def load_json(value, default):
    """解析 JSON 字符串，解析失败时返回 default，容错 hook payload 格式错误。"""
    try:
        return json.loads(value)
    except (TypeError, json.JSONDecodeError):
        return default


def json_string_field(json_text, field):
    """从 JSON 对象字符串中读取指定字段，非字符串值返回空字符串。"""
    data = load_json(json_text, {})
    value = data.get(field, "") if isinstance(data, dict) else ""
    return value if isinstance(value, str) else ""


def basename(path):
    """返回路径最后一段，用于通知标签和摘要中的短文件名。"""
    return PurePath(path).name


def truncate_text(text, max_chars=500):
    """将文本截断至 max_chars 字符，防止长 payload 溢出提示词或通知。"""
    return text[:max_chars]


def truncate_inline(text, max_chars=48):
    """将文本压缩为单行预览，超出 max_chars 时末尾加省略号。"""
    value = text.replace("\n", " ").strip()
    if len(value) > max_chars:
        value = value[: max(0, max_chars - 3)].rstrip() + "..."
    return value


def lines(*items):
    """将多个字符串用换行符拼接，用于构建多行通知正文。"""
    return "\n".join(items)


def first_nonempty_line(text):
    """返回文本中第一条非空行，用于从外部摘要器输出中提取候选摘要。"""
    return next((line.strip() for line in text.splitlines() if line.strip()), "")


def redact_sensitive_text(text):
    """将文本中的 API key、token、密码等敏感键值替换为 [REDACTED]。"""
    value = text
    for pattern in SENSITIVE_PATTERNS:
        value = re.sub(pattern, lambda match: match.group(1) + "[REDACTED]", value)
    return value
