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
    """Return the configured summary length limit.

    Input: none; reads CLAUDE_HARK_SUMMARY_MAX_CHARS from the environment.
    Output: int max character count, defaulting to DEFAULT_SUMMARY_MAX_CHARS.
    Purpose: centralizes the length limit used when rendering action summaries.
    """
    return int(os.environ.get("CLAUDE_HARK_SUMMARY_MAX_CHARS", str(DEFAULT_SUMMARY_MAX_CHARS)))


def load_json(value, default):
    """Parse a JSON string with a safe fallback.

    Input: value is the JSON text to parse; default is returned on parse failure.
    Output: parsed JSON value, or default when value is invalid or not parseable.
    Purpose: keeps hook payload parsing tolerant of malformed or missing JSON.
    """
    try:
        return json.loads(value)
    except (TypeError, json.JSONDecodeError):
        return default


def json_string_field(json_text, field):
    """Read a string field from a JSON object.

    Input: json_text is a JSON object string; field is the key to read.
    Output: the field value when it is a string, otherwise an empty string.
    Purpose: normalizes optional hook payload fields before rendering summaries.
    """
    data = load_json(json_text, {})
    value = data.get(field, "") if isinstance(data, dict) else ""
    return value if isinstance(value, str) else ""


def basename(path):
    """Return the final path component.

    Input: path is a file or directory path string.
    Output: final path component as a string.
    Purpose: shortens file paths for notification labels and summaries.
    """
    return PurePath(path).name


def truncate_text(text, max_chars=500):
    """Limit text to a maximum number of characters.

    Input: text is the source string; max_chars is the maximum returned length.
    Output: text sliced to max_chars characters.
    Purpose: prevents long payloads from overflowing prompts or notifications.
    """
    return text[:max_chars]


def truncate_inline(text, max_chars=48):
    """Convert text to a compact one-line preview.

    Input: text is the source string; max_chars is the maximum returned length.
    Output: a stripped single-line string, with ellipsis when truncated.
    Purpose: renders command, pattern, or prompt snippets safely in one line.
    """
    value = text.replace("\n", " ").strip()
    if len(value) > max_chars:
        value = value[: max(0, max_chars - 3)].rstrip() + "..."
    return value


def lines(*items):
    """Join strings with newline separators.

    Input: any number of string items.
    Output: one string containing all items separated by newlines.
    Purpose: keeps multi-line notification body construction readable.
    """
    return "\n".join(items)


def first_nonempty_line(text):
    """Return the first line with visible content.

    Input: text is a potentially multi-line string.
    Output: the first non-empty stripped line, or an empty string if none exists.
    Purpose: extracts a concise candidate summary from external summarizer output.
    """
    return next((line.strip() for line in text.splitlines() if line.strip()), "")


def redact_sensitive_text(text):
    """Redact common key/value secrets in text.

    Input: text is the source string that may contain sensitive values.
    Output: text with matched secret values replaced by [REDACTED].
    Purpose: prevents tokens, passwords, API keys, and secrets from appearing in summaries.
    """
    value = text
    for pattern in SENSITIVE_PATTERNS:
        value = re.sub(pattern, lambda match: match.group(1) + "[REDACTED]", value)
    return value
