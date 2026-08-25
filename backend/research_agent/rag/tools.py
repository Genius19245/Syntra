"""ADK tools for hybrid RAG + web routing."""

from __future__ import annotations

import json
from typing import Any

from google.adk.tools.tool_context import ToolContext

from ..retrieval.authority import evaluate_source
from ..retrieval.queries import generate_research_queries
from ..retrieval.session import (
    recall_rag_hits,
    remember_evidence,
    remember_rag_hits,
    set_cache_exact,
    set_retrieval_mode,
    user_text,
)
from .firebase_cache import FAIL_SOFT, default_cache
from .labels import label_prompt
from .router import (
    _merge_hits,
    plan_retrieval_mode,
    refresh_requested,
    strip_refresh_directive,
)
from .store import default_store
from .writer import parse_package, persist_research_package


def _hits_key(
    topic: str,
    subject: str,
    education_level: str,
    exam_board: str,
    refresh: bool,
) -> tuple:
    return (
        (topic or "").strip(),
        (subject or "").strip().lower(),
        (education_level or "").strip().lower(),
        (exam_board or "").strip().lower(),
        bool(refresh),
    )


def plan_retrieval(
    question: str,
    education_level: str = "",
    exam_board: str = "",
    subject: str = "",
    refresh_cache: bool = False,
    tool_context: ToolContext | None = None,
) -> dict[str, Any]:
    """Decide RAG_ONLY, WEB_ONLY, or HYBRID for this research question.

    Call this after label_prompt. Do not skip it. Time-sensitive
    questions require web research. A strong Firestore cache hit can
    skip web research for a stable topic. Refresh cache: yes or a
    stale TTL skips the exact hit so the topic can be re-researched.
    """
    refresh = bool(refresh_cache) or refresh_requested(
        question, user_text(tool_context)
    )
    hits_out: list = []
    plan = plan_retrieval_mode(
        question,
        education_level=education_level,
        exam_board=exam_board,
        subject=subject,
        refresh_cache=refresh,
        hits_out=hits_out,
    )
    if hits_out:
        bundle = hits_out[0]
        remember_rag_hits(
            tool_context,
            _hits_key(
                bundle["topic"],
                bundle["subject"],
                bundle["education_level"],
                bundle["exam_board"],
                bundle["refresh"],
            ),
            bundle["cache_hits"],
            bundle["local_hits"],
            bundle["k"],
        )
    set_retrieval_mode(tool_context, plan["mode"], plan["freshness"])
    set_cache_exact(tool_context, bool(plan.get("cache_exact")))
    return plan


def retrieve_knowledge(
    query: str,
    education_level: str = "",
    exam_board: str = "",
    subject: str = "",
    k: int = 5,
    refresh_cache: bool = False,
    tool_context: ToolContext | None = None,
) -> dict[str, Any]:
    """Retrieve persistent educational knowledge. Not a replacement for web search.

    Queries the shared Firestore research cache first (vector search with
    lexical fallback). Local markdown under knowledge/ is a seed fallback
    only when Firestore returns nothing. Filter by subject, education
    level, and exam board when those were specified.
    """
    filters = {
        "subject": subject,
        "education_level": education_level,
        "exam_board": exam_board,
    }
    limit = max(1, min(int(k or 5), 8))
    lookup_topic = strip_refresh_directive(query)
    refresh = bool(refresh_cache) or refresh_requested(query, user_text(tool_context))
    key = _hits_key(lookup_topic, subject, education_level, exam_board, refresh)
    reused = recall_rag_hits(tool_context, key, limit)
    cache_hits: list[dict[str, Any]] = []
    local_hits: list[dict[str, Any]] = []
    if reused is not None:
        cache_hits, local_hits = reused
    else:
        try:
            cache_hits = default_cache().lookup(
                lookup_topic,
                subject=subject,
                education_level=education_level,
                exam_board=exam_board,
                k=limit,
                refresh=refresh,
            )
        except FAIL_SOFT:
            cache_hits = []
        if not cache_hits:
            local_hits = default_store().retrieve(
                lookup_topic, filters=filters, k=limit
            )
        remember_rag_hits(tool_context, key, cache_hits, local_hits, limit)
    hits = _merge_hits(local_hits, cache_hits)[:limit]
    for hit in hits:
        package = hit.get("package") or {}
        for claim in package.get("claims") or []:
            if isinstance(claim, dict):
                remember_evidence(tool_context, claim)
    return {
        "success": True,
        "query": query,
        "filters": filters,
        "hit_count": len(hits),
        "cache_hit_count": len(cache_hits),
        "hits": hits,
    }


def store_knowledge(package_json: str) -> dict[str, Any]:
    """Save a verified research package into the Firestore research cache.

    Local markdown under knowledge/ is still written as a seed copy.
    Call this before returning the package.
    Time-sensitive work is skipped automatically. Unverified claims
    are skipped only when fact-check was used.
    Later lessons retrieve this via retrieve_knowledge.
    """
    try:
        package = parse_package(package_json)
    except (ValueError, TypeError, json.JSONDecodeError) as exc:
        return {
            "success": False,
            "stored": False,
            "firebase_stored": False,
            "error": f"Could not parse research package: {exc}",
        }
    try:
        result = persist_research_package(package)
    except OSError as exc:
        return {
            "success": False,
            "stored": False,
            "firebase_stored": False,
            "error": f"Could not write knowledge file: {exc}",
        }
    cache_result: dict[str, Any] = {
        "stored": False,
        "reason": "Firestore cache unavailable.",
    }
    try:
        cache_result = default_cache().store(package)
    except FAIL_SOFT as exc:
        cache_result = {
            "success": False,
            "stored": False,
            "reason": f"Firestore write failed: {exc}",
        }
    result["firebase_stored"] = bool(cache_result.get("stored"))
    result["firebase_reason"] = cache_result.get("reason")
    if cache_result.get("prompt_key"):
        result["prompt_key"] = cache_result["prompt_key"]
    return result


__all__ = [
    "evaluate_source",
    "generate_research_queries",
    "label_prompt",
    "plan_retrieval",
    "retrieve_knowledge",
    "store_knowledge",
]
