"""Hard gates so RAG_ONLY / cache hits do not invoke live web research."""

from __future__ import annotations

from typing import Any

from ..retrieval.session import (
    capture_strict_from_text,
    claim_coverage_met,
    is_strict_mode,
    user_text,
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
    del args
    from opentelemetry import trace

    span = trace.get_current_span()
    if span is None or not span.is_recording():
        return
    span.add_event(
        "syntra.tool.gate",
        attributes={"tool.name": _tool_name(tool)},
    )


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


def gate_research_tools(tool: Any, args: dict[str, Any], tool_context: Any):
    """before_tool_callback: announce, then skip web / Fact Checker when gated."""
    _announce(tool, args)
    capture_strict_from_text(tool_context, user_text(tool_context))
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
