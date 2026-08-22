"""Build a small, deduplicated set of research queries."""

from __future__ import annotations

import re
from typing import Iterable

_MAX_QUERIES = 6

DEFAULT_DIMENSIONS = (
    "core_concept",
    "curriculum_requirements",
    "common_misconceptions",
    "required_depth",
)

_WHITESPACE = re.compile(r"\s+")
_PUNCT = re.compile(r"[^\w\s\-']", re.UNICODE)


def normalize_query(query: str) -> str:
    text = (query or "").strip().lower()
    text = _PUNCT.sub(" ", text)
    text = _WHITESPACE.sub(" ", text)
    return text.strip()


def dedupe_queries(
    queries: Iterable[str],
    *,
    max_queries: int = _MAX_QUERIES,
) -> list[str]:
    unique: list[str] = []
    seen: set[str] = set()
    for raw in queries:
        query = " ".join((raw or "").split())
        if not query:
            continue
        key = normalize_query(query)
        if not key or key in seen:
            continue
        seen.add(key)
        unique.append(query)
        if len(unique) >= max_queries:
            break
    return unique


def _level_fragment(education_level: str) -> str:
    return " ".join((education_level or "").split())


def _board_fragment(exam_board: str) -> str:
    return " ".join((exam_board or "").split())


def build_research_queries(
    topic: str,
    *,
    education_level: str = "",
    exam_board: str = "",
    subject: str = "",
    dimensions: Iterable[str] | None = None,
    max_queries: int = _MAX_QUERIES,
) -> list[dict[str, str]]:
    """Return dimension-tagged queries. Domain-independent templates."""
    topic = " ".join((topic or "").split())
    if not topic:
        return []

    level = _level_fragment(education_level)
    board = _board_fragment(exam_board)
    subject_name = " ".join((subject or "").split())
    chosen = tuple(dimensions) if dimensions is not None else DEFAULT_DIMENSIONS

    planned: list[dict[str, str]] = []

    def add(dimension: str, query: str) -> None:
        query = " ".join(query.split())
        if query:
            planned.append({"dimension": dimension, "query": query})

    for dimension in chosen:
        key = dimension.strip().lower().replace(" ", "_")
        if key in {"core_concept", "core_mechanism", "definition"}:
            add(
                "core_concept",
                f"{topic} {subject_name} {level} definition explanation",
            )
        elif key in {"curriculum_requirements", "curriculum", "specification"}:
            if board or level:
                add(
                    "curriculum_requirements",
                    f"{topic} {level} {board} official specification curriculum",
                )
        elif key in {"common_misconceptions", "misconceptions"}:
            add(
                "common_misconceptions",
                f"{topic} {level} common misconceptions",
            )
        elif key in {"required_depth", "worked_example", "methods"}:
            add(
                "required_depth",
                f"{topic} {subject_name} {level} {board} classroom worked example",
            )
        elif key in {"evidence", "examples"}:
            add(
                "evidence",
                f"{topic} {level} evidence examples",
            )
        else:
            add(key or "general", f"{topic} {subject_name} {level} {dimension}")

    deduped_queries = dedupe_queries(
        (item["query"] for item in planned),
        max_queries=max_queries,
    )
    by_query = {item["query"]: item for item in planned}
    return [by_query[query] for query in deduped_queries if query in by_query]


def generate_research_queries(
    topic: str,
    education_level: str = "",
    exam_board: str = "",
    subject: str = "",
) -> dict:
    """Build a small targeted query list for educational research.

    Call this instead of inventing many overlapping searches.
    """
    items = build_research_queries(
        topic,
        education_level=education_level,
        exam_board=exam_board,
        subject=subject,
    )
    return {
        "success": bool(items),
        "topic": topic,
        "education_level": education_level,
        "exam_board": exam_board,
        "subject": subject,
        "queries": items,
        "query_count": len(items),
    }
