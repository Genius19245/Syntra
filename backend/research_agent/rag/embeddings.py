"""Vertex text embeddings for research-cache retrieval.

Lazy ADC init. The Research Agent must not import Vertex except here.
Callers that cannot reach Vertex fall back to lexical ranking.
"""

from __future__ import annotations

import math
import os
from collections.abc import Sequence
from typing import Protocol

_CORE_FAIL_SOFT: tuple[type[BaseException], ...] = (
    AttributeError,
    ImportError,
    LookupError,
    OSError,
    OverflowError,
    RuntimeError,
    TypeError,
    ValueError,
)


def _sdk_fail_soft() -> tuple[type[BaseException], ...]:
    extra: list[type[BaseException]] = []
    for module_name, attr in (
        ("firebase_admin.exceptions", "FirebaseError"),
        ("google.api_core.exceptions", "GoogleAPIError"),
        ("google.auth.exceptions", "GoogleAuthError"),
        ("google.genai.errors", "APIError"),
    ):
        try:
            extra.append(getattr(__import__(module_name, fromlist=[attr]), attr))
        except (AttributeError, ImportError):
            continue
    return tuple(extra)


FAIL_SOFT: tuple[type[BaseException], ...] = _CORE_FAIL_SOFT + _sdk_fail_soft()

PROJECT_ID = os.environ.get("GOOGLE_CLOUD_PROJECT", "agenticsai2026")
LOCATION = (
    os.environ.get("GOOGLE_CLOUD_LOCATION")
    or os.environ.get("VERTEX_LOCATION")
    or "us-central1"
)
EMBEDDING_MODEL = os.environ.get("SYNTRA_EMBEDDING_MODEL", "text-embedding-004")
EMBEDDING_DIMENSION = 768
MAX_EMBED_CHARS = 8000
_FALSEY = {"0", "false", "no", "off"}

_UNSET: str = "unset"
_EMBEDDER: Embedder | None | str = _UNSET


class Embedder(Protocol):
    def embed_texts(
        self,
        texts: Sequence[str],
        *,
        task_type: str = "RETRIEVAL_DOCUMENT",
    ) -> list[list[float] | None]: ...


def embeddings_enabled() -> bool:
    flag = os.environ.get("SYNTRA_EMBEDDINGS_ENABLED", "true").strip().lower()
    return flag not in _FALSEY


def embedding_model_name() -> str:
    return os.environ.get("SYNTRA_EMBEDDING_MODEL", EMBEDDING_MODEL)


def cosine_similarity(left: Sequence[float], right: Sequence[float]) -> float:
    if not left or not right or len(left) != len(right):
        return 0.0
    dot = 0.0
    left_norm = 0.0
    right_norm = 0.0
    for x, y in zip(left, right):
        dot += x * y
        left_norm += x * x
        right_norm += y * y
    if left_norm <= 0.0 or right_norm <= 0.0:
        return 0.0
    return dot / math.sqrt(left_norm * right_norm)


def as_vector(value: object) -> list[float] | None:
    """Unpack a list, tuple, or Firestore Vector into floats."""
    if value is None or isinstance(value, (str, bytes, dict)):
        return None
    raw = getattr(value, "_value", None)
    if isinstance(raw, (list, tuple)):
        value = raw
    if not isinstance(value, (list, tuple)) or len(value) < 2:
        return None
    try:
        vector = [float(item) for item in value]
    except (TypeError, ValueError):
        return None
    return vector


class VertexEmbedder:
    """Vertex AI text embeddings via Application Default Credentials."""

    def __init__(self) -> None:
        self._client = None

    def _client_or_raise(self):
        if self._client is not None:
            return self._client
        from google.genai import Client

        self._client = Client(
            vertexai=True,
            project=PROJECT_ID,
            location=LOCATION,
        )
        return self._client

    def embed_texts(
        self,
        texts: Sequence[str],
        *,
        task_type: str = "RETRIEVAL_DOCUMENT",
    ) -> list[list[float] | None]:
        client = self._client_or_raise()
        model = embedding_model_name()
        clipped_items = [(text or "").strip()[:MAX_EMBED_CHARS] for text in texts]
        nonempty = [item for item in clipped_items if item]
        if not nonempty:
            return [None] * len(clipped_items)

        def _one(clipped: str) -> list[float] | None:
            response = client.models.embed_content(
                model=model,
                contents=clipped,
                config={"task_type": task_type},
            )
            embeddings = getattr(response, "embeddings", None) or []
            if not embeddings:
                return None
            raw = getattr(embeddings[0], "values", None) or []
            return [float(item) for item in raw] or None

        by_text: dict[str, list[float] | None] = {}
        if len(nonempty) == 1:
            by_text[nonempty[0]] = _one(nonempty[0])
        else:
            try:
                response = client.models.embed_content(
                    model=model,
                    contents=nonempty,
                    config={"task_type": task_type},
                )
                embeddings = getattr(response, "embeddings", None) or []
                if len(embeddings) != len(nonempty):
                    raise ValueError("embedding count mismatch")
                for text, emb in zip(nonempty, embeddings):
                    raw = getattr(emb, "values", None) or []
                    by_text[text] = [float(item) for item in raw] or None
            except FAIL_SOFT:
                for text in nonempty:
                    try:
                        by_text[text] = _one(text)
                    except FAIL_SOFT:
                        by_text[text] = None
        return [by_text.get(item) if item else None for item in clipped_items]


def _live_vertex_allowed() -> bool:
    if not embeddings_enabled():
        return False
    # Memory-backed tests must never call Vertex; inject a fake embedder instead.
    return os.environ.get("SYNTRA_FIRESTORE_BACKEND") != "memory"


def default_embedder() -> Embedder | None:
    global _EMBEDDER
    if _EMBEDDER != _UNSET:
        return _EMBEDDER  # type: ignore[return-value]
    if not _live_vertex_allowed():
        _EMBEDDER = None
        return None
    _EMBEDDER = VertexEmbedder()
    return _EMBEDDER


def reset_embedder(embedder: Embedder | None | str = _UNSET) -> None:
    global _EMBEDDER
    _EMBEDDER = embedder


def embed_texts(
    texts: Sequence[str],
    *,
    task_type: str = "RETRIEVAL_DOCUMENT",
    embedder: Embedder | None = None,
) -> list[list[float] | None]:
    items = list(texts)
    if not embeddings_enabled():
        return [None] * len(items)
    owner = embedder if embedder is not None else default_embedder()
    if owner is None:
        return [None] * len(items)
    try:
        return owner.embed_texts(items, task_type=task_type)
    except TypeError:
        return owner.embed_texts(items)  # type: ignore[call-arg]
    except FAIL_SOFT:
        return [None] * len(items)


def embed_text(
    text: str,
    *,
    task_type: str = "RETRIEVAL_QUERY",
    embedder: Embedder | None = None,
) -> list[float] | None:
    vectors = embed_texts([text], task_type=task_type, embedder=embedder)
    return vectors[0] if vectors else None
