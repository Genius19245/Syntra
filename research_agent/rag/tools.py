"""ADK tools for hybrid RAG + web routing."""

from __future__ import annotations

from typing import Any, Optional
import json

from google.adk.tools.tool_context import ToolContext

from ..retrieval.authority import evaluate_source
from ..retrieval.queries import generate_research_queries
from ..retrieval.session import remember_evidence, set_cache_exact, set_retrieval_mode
from .firebase_cache import default_cache
from .labels import label_prompt
from .router import _merge_hits, plan_retrieval_mode
from .store import default_store
from .writer import parse_package, persist_research_package


def plan_retrieval(
    question: str,
    education_level: str = "",
    exam_board: str = "",
    subject: str = "",
    tool_context: Optional[ToolContext] = None,
) -> dict[str, Any]:
    """Decide RAG_ONLY, WEB_ONLY, or HYBRID for this research question.

    Call this after label_prompt. Do not skip it. Time-sensitive
    questions require web research. A strong Firestore cache hit can
    skip web research for a stable topic.
    """
    plan = plan_retrieval_mode(
        question,
        education_level=education_level,
        exam_board=exam_board,
        subject=subject,
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
    tool_context: Optional[ToolContext] = None,
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
    cache_hits: list[dict[str, Any]] = []
    try:
        cache_hits = default_cache().lookup(
            query,
            subject=subject,
            education_level=education_level,
            exam_board=exam_board,
            k=limit,
        )
    except Exception:
        cache_hits = []
    local_hits: list[dict[str, Any]] = []
    if not cache_hits:
        local_hits = default_store().retrieve(query, filters=filters, k=limit)
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
    cache_result: dict[str, Any] = {"stored": False, "reason": "Firestore cache unavailable."}
    try:
        cache_result = default_cache().store(package)
    except Exception as exc:
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
