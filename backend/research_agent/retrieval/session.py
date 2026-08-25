"""Session helpers for duplicate query/URL suppression."""

from __future__ import annotations

from typing import Any

SEEN_QUERIES = "seen_queries"
SEEN_URLS = "seen_urls"
EVIDENCE_POOL = "evidence_pool"
RETRIEVAL_MODE = "retrieval_mode"
FRESHNESS_CLASS = "freshness_class"
CACHE_EXACT = "cache_exact"
STRICT_MODE = "strict_mode"
RAG_HITS = "rag_hits_cache"
USER_TEXT = "_user_text"


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


def set_cache_exact(container: Any, exact: bool) -> None:
    state = _state(container)
    if state is None:
        return
    state[CACHE_EXACT] = bool(exact)


def set_strict_mode(container: Any, enabled: bool) -> None:
    state = _state(container)
    if state is None:
        return
    state[STRICT_MODE] = bool(enabled)


def is_strict_mode(container: Any) -> bool:
    state = _state(container)
    if state is None:
        return False
    return bool(state.get(STRICT_MODE))


def web_blocked(container: Any) -> bool:
    """True when RAG_ONLY or an exact cache hit should skip live web research."""
    state = _state(container)
    if state is None:
        return False
    if bool(state.get(CACHE_EXACT)):
        return True
    return str(state.get(RETRIEVAL_MODE) or "") == "RAG_ONLY"


def claim_coverage_met(container: Any, needed: int = 3) -> bool:
    return len(_as_list(_state(container), EVIDENCE_POOL)) >= needed


def capture_strict_from_text(container: Any, text: str) -> bool:
    if not (text or "").strip():
        return is_strict_mode(container)
    enabled = "strict verification: yes" in text.lower()
    set_strict_mode(container, enabled)
    return enabled


def content_text(content: Any) -> str:
    if content is None:
        return ""
    if isinstance(content, str):
        return content
    parts = getattr(content, "parts", None)
    if parts is None and isinstance(content, dict):
        parts = content.get("parts")
    if not parts:
        text = getattr(content, "text", None)
        if text is None and isinstance(content, dict):
            text = content.get("text")
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


def remember_rag_hits(
    container: Any,
    key: tuple,
    cache_hits: list,
    local_hits: list,
    stored_k: int,
) -> None:
    """Keep the last Firestore/seed lookup so retrieve_knowledge can reuse it."""
    state = _state(container)
    if state is None:
        return
    state[RAG_HITS] = {
        "key": key,
        "cache_hits": cache_hits,
        "local_hits": local_hits,
        "k": int(stored_k),
    }


def recall_rag_hits(container: Any, key: tuple, k: int):
    """Return cached hits when the query/filters match and k is covered."""
    state = _state(container)
    if state is None:
        return None
    cached = state.get(RAG_HITS) if hasattr(state, "get") else None
    if not isinstance(cached, dict) or cached.get("key") != key:
        return None
    if int(cached.get("k") or 0) < int(k):
        return None
    return cached.get("cache_hits") or [], cached.get("local_hits") or []


def user_text(tool_context: Any) -> str:
    """Read the originating user message from an ADK tool context."""

    if tool_context is None:
        return ""
    state = _state(tool_context)
    if state is not None and hasattr(state, "get"):
        cached = state.get(USER_TEXT)
        if isinstance(cached, str) and cached:
            return cached
    found = ""
    for attr in ("user_content", "user_message"):
        value = getattr(tool_context, attr, None)
        text = content_text(value)
        if text:
            found = text
            break
    if not found:
        session = getattr(tool_context, "session", None)
        events = getattr(session, "events", None) if session is not None else None
        if events:
            for event in events:
                content = getattr(event, "content", None) or (
                    event.get("content") if isinstance(event, dict) else None
                )
                text = content_text(content)
                if text:
                    found = text
                    break
    if found and state is not None and hasattr(state, "__setitem__"):
        state[USER_TEXT] = found
    return found
