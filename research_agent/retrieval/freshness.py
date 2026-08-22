"""Classify whether a research question needs fresh web evidence."""

from __future__ import annotations

import re

from ..schema import FreshnessClass

_TIME_SENSITIVE = (
    r"\blatest\b",
    r"\bcurrent\b",
    r"\btoday\b",
    r"\bthis year\b",
    r"\brecently\b",
    r"\bright now\b",
    r"\bbreaking\b",
    r"\bnews\b",
    r"\bpolicy\b",
    r"\bpolicies\b",
    r"\belection\b",
    r"\boutbreak\b",
    r"\bupdate(?:s)?\b",
    r"\bannounc(?:e|ed|ement)\b",
    r"\bas of 20\d{2}\b",
    r"\b20(2[4-9]|3\d)\b",
    r"\bipcc assessment\b",
    r"\bcurrent affairs\b",
    r"\bmajor development\b",
    r"\bwhat happened\b",
)

_RECENT = (
    r"\brecent\b",
    r"\bnew research\b",
    r"\bdevelopments?\b",
    r"\blast year\b",
    r"\bthis decade\b",
    r"\bemerging\b",
)

_STABLE = (
    r"\bexplain\b",
    r"\bteach\b",
    r"\bdefine\b",
    r"\bdefinition\b",
    r"\blaw[s]?\b",
    r"\btheorem\b",
    r"\bmechanism\b",
    r"\bprocess of\b",
    r"\bcauses of\b",
    r"\bhow does\b",
    r"\bhow do\b",
)


def _matches(patterns: tuple[str, ...], text: str) -> bool:
    return any(re.search(pattern, text) for pattern in patterns)


def classify_freshness(question: str) -> FreshnessClass:
    """Heuristic freshness class for hybrid RAG vs web routing."""
    text = (question or "").strip().lower()
    if not text:
        return FreshnessClass.STABLE

    time_sensitive = _matches(_TIME_SENSITIVE, text)
    recent = _matches(_RECENT, text)
    stable = _matches(_STABLE, text)

    if time_sensitive and stable:
        return FreshnessClass.MIXED
    if time_sensitive:
        return FreshnessClass.TIME_SENSITIVE
    if recent and stable:
        return FreshnessClass.MIXED
    if recent:
        return FreshnessClass.RECENT
    return FreshnessClass.STABLE
