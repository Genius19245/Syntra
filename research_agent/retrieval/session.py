"""Session helpers for duplicate query/URL suppression."""

from __future__ import annotations

from typing import Any

SEEN_QUERIES = "seen_queries"
SEEN_URLS = "seen_urls"
EVIDENCE_POOL = "evidence_pool"
RETRIEVAL_MODE = "retrieval_mode"
FRESHNESS_CLASS = "freshness_class"


def _state(container: Any) -> Any:
    if container is None:
        return None
    if isinstance(container, dict):
        return container
    state = getattr(container, "state", None)
    if state is None and hasattr(container, "get") and hasattr(container, "setdefault"):
        return container
    return state


def _as_list(state: Any, key: str) -> list:
    if state is None:
        return []
    value = state.get(key) if hasattr(state, "get") else None
    if value is None:
        return []
    if isinstance(value, list):
        return value
    return list(value)


def seen_queries(container: Any) -> list[str]:
    return [str(item) for item in _as_list(_state(container), SEEN_QUERIES)]


def seen_urls(container: Any) -> list[str]:
    return [str(item) for item in _as_list(_state(container), SEEN_URLS)]


def remember_query(container: Any, query: str) -> bool:
    """Record a query. Return True if it is new."""
    query = " ".join((query or "").split())
    if not query:
        return False
    state = _state(container)
    if state is None:
        return True
    items = _as_list(state, SEEN_QUERIES)
    key = query.lower()
    if any(str(existing).lower() == key for existing in items):
        return False
    items.append(query)
    state[SEEN_QUERIES] = items
    return True


def remember_url(container: Any, url: str) -> bool:
    """Record a URL. Return True if it is new."""
    url = (url or "").strip()
    if not url:
        return False
    state = _state(container)
    if state is None:
        return True
    items = _as_list(state, SEEN_URLS)
    if url in items:
        return False
    items.append(url)
    state[SEEN_URLS] = items
    return True


def remember_evidence(container: Any, evidence: dict) -> None:
    state = _state(container)
    if state is None:
        return
    items = _as_list(state, EVIDENCE_POOL)
    items.append(evidence)
    state[EVIDENCE_POOL] = items


def set_retrieval_mode(container: Any, mode: str, freshness: str | None = None) -> None:
    state = _state(container)
    if state is None:
        return
    state[RETRIEVAL_MODE] = mode
    if freshness:
        state[FRESHNESS_CLASS] = freshness
