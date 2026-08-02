# 从 Claude Code transcript JSONL 中提取触发 Hook 前的最小对话上下文。
import json
import os

from util import redact_sensitive_text, truncate_text


MAX_TRANSCRIPT_BYTES = 256 * 1024


def _text_content(content):
    if isinstance(content, str):
        return content.strip()
    if not isinstance(content, list):
        return ""
    parts = []
    for block in content:
        if isinstance(block, dict) and block.get("type") == "text" and isinstance(block.get("text"), str):
            parts.append(block["text"].strip())
    return "\n".join(part for part in parts if part)


def _message(record):
    message = record.get("message") if isinstance(record, dict) else None
    return message if isinstance(message, dict) else record if isinstance(record, dict) else {}


def _role(record, message):
    value = message.get("role") or record.get("type")
    return value if value in ("user", "assistant") else ""


def extract_transcript_context(transcript_path, tool_use_id=""):
    """Return the latest user goal and assistant lead-in; failures safely return {}."""
    if not isinstance(transcript_path, str) or not transcript_path or not transcript_path.endswith(".jsonl"):
        return {}
    try:
        if not os.path.isfile(transcript_path):
            return {}
        with open(transcript_path, "rb") as stream:
            size = os.fstat(stream.fileno()).st_size
            stream.seek(max(0, size - MAX_TRANSCRIPT_BYTES))
            raw = stream.read()
        if size > MAX_TRANSCRIPT_BYTES:
            raw = raw.split(b"\n", 1)[-1]
    except (OSError, ValueError):
        return {}

    messages = []
    for raw_line in raw.splitlines():
        try:
            record = json.loads(raw_line)
        except (json.JSONDecodeError, UnicodeDecodeError):
            continue
        if not isinstance(record, dict):
            continue
        message = _message(record)
        role = _role(record, message)
        content = message.get("content")
        text = _text_content(content)
        if role and text:
            messages.append((role, text))

        # Prefer text from the assistant message containing this exact tool call.
        if role == "assistant" and tool_use_id and isinstance(content, list):
            contains_call = any(
                isinstance(block, dict) and block.get("type") == "tool_use" and block.get("id") == tool_use_id
                for block in content
            )
            if contains_call and text:
                messages[-1] = (role, text)

    last_user_index = next((index for index in range(len(messages) - 1, -1, -1) if messages[index][0] == "user"), None)
    if last_user_index is None:
        current_turn = messages
        user_goal = ""
    else:
        current_turn = messages[last_user_index + 1 :]
        user_goal = messages[last_user_index][1]
    assistant_text = next((text for role, text in reversed(current_turn) if role == "assistant"), "")

    result = {}
    if user_goal:
        result["userGoal"] = truncate_text(redact_sensitive_text(user_goal), 800)
    if assistant_text:
        result["assistantLeadIn"] = truncate_text(redact_sensitive_text(assistant_text), 800)
    return result
