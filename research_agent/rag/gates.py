"""Hard gates so RAG_ONLY / cache hits do not invoke live web research."""

from __future__ import annotations

from typing import Any

from ..retrieval.session import (
    capture_strict_from_text,
    claim_coverage_met,
    is_strict_mode,
    web_blocked,
)

WEB_TOOL_NAMES = {
    "gather_sources",
    "search_web",
    "fetch_page",
    "fetch_pages",
    "generate_research_queries",
}


def _tool_name(tool: Any) -> str:
    return str(getattr(tool, "name", None) or getattr(tool, "__name__", "") or "")


def _announce(tool: Any, args: dict[str, Any] | None) -> None:
    payload = args or {}
    queries = payload.get("queries")
    queries_detail = (
        ", ".join(str(item) for item in queries if item)
        if isinstance(queries, list)
        else ""
    )
    detail = (
        payload.get("request")
        or payload.get("query")
        or queries_detail
        or payload.get("url")
        or payload.get("question")
        or payload.get("topic")
        or (str(payload.get("package_json") or "")[:80])
        or ""
    )
    suffix = f": {detail[:120]}" if detail else ""
    print(f"[{_tool_name(tool)}]{suffix}", flush=True)


def _agent_name(args: dict[str, Any] | None) -> str:
    payload = args or {}
    return str(
        payload.get("agent_name")
        or payload.get("agentName")
        or payload.get("agent")
        or ""
    ).strip()


def _is_transfer(name: str, args: dict[str, Any] | None, agent: str) -> bool:
    if name not in {"transfer_to_agent", "transferToAgent"}:
        return False
    return _agent_name(args).lower() == agent.lower()


def _user_text(tool_context: Any) -> str:
    if tool_context is None:
        return ""
    for attr in ("user_content", "user_message"):
        value = getattr(tool_context, attr, None)
        text = _content_text(value)
        if text:
            return text
    session = getattr(tool_context, "session", None)
    events = getattr(session, "events", None) if session is not None else None
    if events:
        for event in events:
            content = getattr(event, "content", None) or (
                event.get("content") if isinstance(event, dict) else None
            )
            text = _content_text(content)
            if text:
                return text
    return ""


def _content_text(content: Any) -> str:
    if content is None:
        return ""
    if isinstance(content, str):
        return content
    parts = getattr(content, "parts", None)
    if parts is None and isinstance(content, dict):
        parts = content.get("parts")
    if not parts:
        text = getattr(content, "text", None)
        return str(text or "")
    chunks: list[str] = []
    for part in parts:
        if isinstance(part, str):
            chunks.append(part)
            continue
        text = getattr(part, "text", None)
        if text is None and isinstance(part, dict):
            text = part.get("text")
        if text:
            chunks.append(str(text))
    return "\n".join(chunks)


def gate_research_tools(tool: Any, args: dict[str, Any], tool_context: Any):
    """before_tool_callback: announce, then skip web / Fact Checker when gated."""
    _announce(tool, args)
    capture_strict_from_text(tool_context, _user_text(tool_context))
    name = _tool_name(tool)

    if web_blocked(tool_context):
        if name in WEB_TOOL_NAMES:
            return {
                "success": True,
                "skipped": True,
                "reason": "RAG_ONLY or exact cache hit; skip web research.",
            }
        if _is_transfer(name, args, "source_researcher"):
            return {
                "success": True,
                "skipped": True,
                "reason": "Skipped Source Researcher: SYNTRA cache already covered this topic.",
            }

    if claim_coverage_met(tool_context) and name in WEB_TOOL_NAMES:
        return {
            "success": True,
            "skipped": True,
            "reason": "Three teachable claims already covered; skip further web fetches.",
        }

    if _is_transfer(name, args, "fact_checker") and not is_strict_mode(tool_context):
        return {
            "success": True,
            "skipped": True,
            "reason": "Fact Checker skipped (strict mode off).",
        }
    return None
