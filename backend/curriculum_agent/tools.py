"""Keep full research in session state; bound what curriculum LLMs see."""

from __future__ import annotations

import json
import re
from collections.abc import Mapping
from typing import Any

from google.adk.agents.readonly_context import ReadonlyContext
from google.genai import types

# Prompt budgets. Gemini 3.5 Flash rejects requests over 1_048_576 input tokens.
# A cached Forces research_package can be hundreds of thousands of tokens; the
# curriculum parent then inlined it again on top of nested-agent history.
MAX_RESEARCH_BRIEF_CHARS = 8_000
MAX_PROMPT_FIELD_CHARS = 12_000
MAX_INSTRUCTION_CHARS = 48_000
MAX_CONTENT_PART_CHARS = 12_000
MAX_CONTENTS_CHARS = 96_000
MAX_BRIEF_CLAIMS = 12
MAX_BRIEF_CONCEPTS = 12
MAX_BRIEF_MISCONCEPTIONS = 6
MAX_CLAIM_CHARS = 280

_STATE_PLACEHOLDER = re.compile(r"\{([A-Za-z_][A-Za-z0-9_]*)(\?)?\}")
_RESEARCH_KEYS = frozenset({"research_package", "research_brief"})
_BRACE_RE = re.compile(r"[{}]")


def compact_research_for_prompt(package: Any) -> str:
    """Bounded markdown brief. Full package stays in session state for tools."""

    data = _as_mapping(package)
    if not data:
        text = _stringify(package)
        return _clip(text, MAX_RESEARCH_BRIEF_CHARS) if text else ""

    lines: list[str] = ["RESEARCH BRIEF (compact; full package is in session state)"]
    for label, key in (
        ("Topic", "topic"),
        ("Subject", "subject"),
        ("Level", "education_level"),
        ("Board", "exam_board"),
    ):
        value = _clean(data.get(key))
        if value:
            lines.append(f"{label}: {_clip(value, 200)}")

    method = _as_mapping(data.get("research_method"))
    if method:
        bits = [
            f"{key}={method.get(key)}"
            for key in ("retrieval_mode", "rag_used", "web_used", "fact_check_used")
            if method.get(key) not in (None, "")
        ]
        if bits:
            lines.append("Method: " + ", ".join(str(bit) for bit in bits))

    concepts = _string_list(data.get("key_concepts"), MAX_BRIEF_CONCEPTS)
    if concepts:
        lines.append("Key concepts:")
        lines.extend(f"- {_clip(item, 160)}" for item in concepts)

    claims = _claim_lines(data.get("claims"))
    if claims:
        lines.append("Verified claims:")
        lines.extend(claims)

    misconceptions = _string_list(data.get("misconceptions"), MAX_BRIEF_MISCONCEPTIONS)
    if misconceptions:
        lines.append("Misconceptions:")
        lines.extend(f"- {_clip(item, 160)}" for item in misconceptions)

    uncertainties = _string_list(data.get("uncertainties"), 4)
    if uncertainties:
        lines.append("Uncertainties (do not teach as settled fact):")
        lines.extend(f"- {_clip(item, 160)}" for item in uncertainties)

    brief = _strip_braces("\n".join(lines).strip())
    return _clip(brief, MAX_RESEARCH_BRIEF_CHARS)


def render_compact_instruction(template: str, state: Mapping[str, Any] | None) -> str:
    """Fill `{key?}` templates without dumping unbounded research_package."""

    snapshot = dict(state or {})

    def _replace(match: re.Match[str]) -> str:
        key = match.group(1)
        optional = match.group(2) == "?"
        if key in _RESEARCH_KEYS:
            return compact_research_for_prompt(snapshot.get("research_package"))
        if key not in snapshot:
            return "" if optional else match.group(0)
        return _clip(_stringify(snapshot[key]), MAX_PROMPT_FIELD_CHARS)

    rendered = _STATE_PLACEHOLDER.sub(_replace, template)
    return _clip(rendered, MAX_INSTRUCTION_CHARS)


def bind_instruction(template: str):
    """ADK InstructionProvider: compact research at render time."""

    def _instruction(ctx: ReadonlyContext) -> str:
        return render_compact_instruction(template, ctx.state)

    _instruction.__template__ = template
    return _instruction


def instruction_template(agent: Any) -> str:
    instruction = getattr(agent, "instruction", "")
    if callable(instruction):
        return str(getattr(instruction, "__template__", "") or "")
    return instruction if isinstance(instruction, str) else ""


def ensure_research_brief(callback_context: Any) -> None:
    """Write a compact brief into session state; leave research_package intact."""

    state = getattr(callback_context, "state", None)
    if state is None:
        return
    package = state.get("research_package") if hasattr(state, "get") else None
    state["research_brief"] = compact_research_for_prompt(package)


def compact_curriculum_llm_request(callback_context: Any, llm_request: Any) -> None:
    """Hard cap conversation history so nested copies cannot hit the 1M token cap."""

    del callback_context
    config = getattr(llm_request, "config", None)
    if config is not None:
        instruction = getattr(config, "system_instruction", None)
        compacted = _compact_system_instruction(instruction)
        if compacted is not instruction:
            config.system_instruction = compacted

    contents = getattr(llm_request, "contents", None)
    if not isinstance(contents, list):
        return
    used = 0
    for content in contents:
        parts = getattr(content, "parts", None) or []
        for part in parts:
            text = getattr(part, "text", None)
            if not isinstance(text, str) or not text:
                continue
            remaining = max(0, MAX_CONTENTS_CHARS - used)
            budget = min(MAX_CONTENT_PART_CHARS, remaining)
            compact = _compact_history_text(text, budget)
            if compact != text:
                part.text = compact
            used += len(getattr(part, "text", "") or "")


def _compact_system_instruction(instruction: Any) -> Any:
    if instruction is None:
        return instruction
    if isinstance(instruction, str):
        return _clip(instruction, MAX_INSTRUCTION_CHARS)
    if isinstance(instruction, types.Content):
        parts = list(instruction.parts or [])
        changed = False
        new_parts = []
        for part in parts:
            text = getattr(part, "text", None)
            if isinstance(text, str) and len(text) > MAX_INSTRUCTION_CHARS:
                new_parts.append(types.Part(text=_clip(text, MAX_INSTRUCTION_CHARS)))
                changed = True
            else:
                new_parts.append(part)
        if changed:
            return types.Content(role=instruction.role, parts=new_parts)
    return instruction


def _compact_history_text(text: str, budget: int) -> str:
    if len(text) <= budget:
        return text
    if _looks_like_research(text):
        payload = text
        marker = " said: "
        if marker in text:
            payload = text.split(marker, 1)[-1]
        brief = compact_research_for_prompt(payload)
        prefix = ""
        if marker in text:
            prefix = text.split(marker, 1)[0] + marker
        return _clip(prefix + brief, budget)
    return _clip(text, budget)


def _looks_like_research(text: str) -> bool:
    head = text[:4000]
    return (
        '"research_method"' in head
        or '"claims"' in head
        or "RESEARCH PACKAGE" in head
        or "[research_agent] said:" in head
        or "[research_and_profile] said:" in head
    )


def _as_mapping(value: Any) -> dict[str, Any]:
    if isinstance(value, Mapping):
        return dict(value)
    if hasattr(value, "model_dump"):
        dumped = value.model_dump()
        return dumped if isinstance(dumped, dict) else {}
    if isinstance(value, str):
        stripped = value.strip()
        if stripped.startswith(("{", "[")):
            try:
                decoded = json.loads(stripped)
            except json.JSONDecodeError:
                return {}
            if isinstance(decoded, dict):
                return decoded
    return {}


def _claim_lines(raw: Any) -> list[str]:
    if not isinstance(raw, list):
        return []
    lines: list[str] = []
    for item in raw:
        if len(lines) >= MAX_BRIEF_CLAIMS:
            break
        data = _as_mapping(item) if not isinstance(item, str) else {"claim": item}
        claim = _clean(data.get("claim") or data.get("text") or item)
        if not claim:
            continue
        verdict = ""
        verification = _as_mapping(data.get("verification"))
        if verification.get("verdict"):
            verdict = f"[{_clean(verification.get('verdict'))}] "
        lines.append(f"- {verdict}{_clip(claim, MAX_CLAIM_CHARS)}")
    return lines


def _string_list(raw: Any, limit: int) -> list[str]:
    if isinstance(raw, str):
        raw = [raw]
    if not isinstance(raw, list):
        return []
    items: list[str] = []
    for item in raw:
        text = _clean(item)
        if text:
            items.append(text)
        if len(items) >= limit:
            break
    return items


def _stringify(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, str):
        return value
    if hasattr(value, "model_dump"):
        value = value.model_dump()
    try:
        return json.dumps(value, ensure_ascii=False, default=str)
    except (TypeError, ValueError):
        return str(value)


def _clean(value: Any) -> str:
    if value is None:
        return ""
    return " ".join(str(value).split())


def _strip_braces(text: str) -> str:
    return _BRACE_RE.sub("", text)


def _clip(text: str, max_chars: int) -> str:
    if max_chars <= 0:
        return ""
    if len(text) <= max_chars:
        return text
    if max_chars <= 16:
        return text[:max_chars]
    return text[: max_chars - 14].rstrip() + "\n[truncated]"
