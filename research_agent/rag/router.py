"""Choose RAG only, web only, or hybrid retrieval."""

from __future__ import annotations

from typing import Any

from ..retrieval.freshness import classify_freshness
from ..schema import FreshnessClass, RetrievalMode
from .firebase_cache import ResearchCache, default_cache
from .store import KnowledgeStore, default_store

MIN_RAG_SCORE = 0.18


def decide_mode(
    freshness: FreshnessClass | str,
    hits: list[dict[str, Any]] | None,
) -> RetrievalMode:
    freshness_value = (
        freshness.value if isinstance(freshness, FreshnessClass) else str(freshness)
    )
    useful = [hit for hit in (hits or []) if float(hit.get("score") or 0) >= MIN_RAG_SCORE]

    if freshness_value == FreshnessClass.TIME_SENSITIVE.value:
        return RetrievalMode.WEB_ONLY
    if freshness_value == FreshnessClass.RECENT.value:
        return RetrievalMode.HYBRID if useful else RetrievalMode.WEB_ONLY
    if freshness_value == FreshnessClass.MIXED.value:
        return RetrievalMode.HYBRID
    if useful:
        return RetrievalMode.RAG_ONLY
    return RetrievalMode.WEB_ONLY


def _merge_hits(
    local_hits: list[dict[str, Any]],
    cache_hits: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    merged = list(cache_hits) + list(local_hits)
    merged.sort(key=lambda hit: float(hit.get("score") or 0), reverse=True)
    seen: set[str] = set()
    out: list[dict[str, Any]] = []
    for hit in merged:
        key = str(hit.get("path") or "")
        if key and key in seen:
            continue
        if key:
            seen.add(key)
        out.append(hit)
    return out


def plan_retrieval_mode(
    question: str,
    *,
    education_level: str = "",
    exam_board: str = "",
    subject: str = "",
    store: KnowledgeStore | None = None,
    cache: ResearchCache | None = None,
    k: int = 5,
) -> dict[str, Any]:
    freshness = classify_freshness(question)
    filters = {
        "subject": subject,
        "education_level": education_level,
        "exam_board": exam_board,
    }
    local_hits: list[dict[str, Any]] = []
    cache_hits: list[dict[str, Any]] = []
    if freshness != FreshnessClass.TIME_SENSITIVE:
        try:
            cache_hits = (cache if cache is not None else default_cache()).lookup(
                question,
                subject=subject,
                education_level=education_level,
                exam_board=exam_board,
                k=k,
            )
        except Exception:
            cache_hits = []
        if not cache_hits:
            local_hits = (store or default_store()).retrieve(
                question, filters=filters, k=k
            )
    hits = _merge_hits(local_hits, cache_hits)
    mode = decide_mode(freshness, hits)
    exact = any((hit.get("metadata") or {}).get("exact") for hit in cache_hits)
    if exact and freshness == FreshnessClass.STABLE:
        mode = RetrievalMode.RAG_ONLY
    return {
        "success": True,
        "question": question,
        "freshness": freshness.value,
        "mode": mode.value,
        "rag_filters": filters,
        "web_needed": mode != RetrievalMode.RAG_ONLY,
        "rag_hit_count": len(hits),
        "cache_hit_count": len(cache_hits),
        "cache_exact": exact,
        "rag_preview": [
            {
                "title": hit.get("title"),
                "score": hit.get("score"),
                "path": hit.get("path"),
                "source": (hit.get("metadata") or {}).get("source"),
                "education_level": (hit.get("metadata") or {}).get("education_level"),
                "subject": (hit.get("metadata") or {}).get("subject"),
            }
            for hit in hits[:3]
        ],
        "reason": _reason(freshness, mode, hits, exact=exact),
    }


def _reason(
    freshness: FreshnessClass,
    mode: RetrievalMode,
    hits: list[dict[str, Any]],
    *,
    exact: bool = False,
) -> str:
    if mode == RetrievalMode.WEB_ONLY and freshness == FreshnessClass.TIME_SENSITIVE:
        return "Time-sensitive question; web research takes priority."
    if mode == RetrievalMode.RAG_ONLY and exact:
        return "Exact research-cache hit; reuse the verified package and skip web."
    if mode == RetrievalMode.RAG_ONLY:
        return f"Stable question with {len(hits)} cached or seed knowledge hit(s)."
    if mode == RetrievalMode.HYBRID:
        return "Use the research cache, seed knowledge, and web research together."
    return "No sufficient cached or seed knowledge; web research required."
