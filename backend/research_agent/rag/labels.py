"""Deterministic labels for the shared research cache."""

from __future__ import annotations

import hashlib
import re
from collections.abc import Callable
from typing import Any

from .embeddings import FAIL_SOFT
from .store import level_band, normalize_level
from .writer import slugify

_TOKEN = re.compile(r"[a-z0-9]+")

# Tiny alias map: token → (cluster, optional inferred subject)
_ALIASES: dict[str, tuple[str, str]] = {
    "magnet": ("magnetism", "physics"),
    "magnets": ("magnetism", "physics"),
    "magnetic": ("magnetism", "physics"),
    "magnetism": ("magnetism", "physics"),
    "electromagnet": ("electromagnetic-induction", "physics"),
    "electromagnetic": ("electromagnetic-induction", "physics"),
    "induction": ("electromagnetic-induction", "physics"),
    "ohm": ("ohms-law", "physics"),
    "ohms": ("ohms-law", "physics"),
    "newton": ("newtons-laws", "physics"),
    "photosynthesis": ("photosynthesis", "biology"),
    "osmosis": ("osmosis", "biology"),
    "ionic": ("ionic-bonding", "chemistry"),
    "bonding": ("ionic-bonding", "chemistry"),
    "scheduling": ("os-scheduling", "computer science"),
    "ww1": ("first-world-war", "history"),
    "wwi": ("first-world-war", "history"),
}

_CatalogLoader = Callable[[], dict[str, tuple[str, str]]]
_catalog_loader: _CatalogLoader | None = None
_catalog_cache: dict[str, tuple[str, str]] | None = None


def set_catalog_loader(loader: _CatalogLoader | None) -> None:
    """Register a process-level cluster-catalog loader. Fail-open if unset."""
    global _catalog_loader, _catalog_cache
    _catalog_loader = loader
    _catalog_cache = None


def clear_catalog_cache() -> None:
    global _catalog_cache
    _catalog_cache = None


def set_catalog_aliases(mapping: dict[str, tuple[str, str]] | None) -> None:
    """Install an in-memory alias overlay. None restores loader-based cache."""
    global _catalog_cache
    _catalog_cache = None if mapping is None else dict(mapping)


def extend_catalog_aliases(entries: dict[str, tuple[str, str]]) -> None:
    """Merge aliases into an already-loaded catalog. No-op if cache is cold."""
    if not entries or _catalog_cache is None:
        return
    _catalog_cache.update(entries)


def _load_catalog() -> dict[str, tuple[str, str]]:
    global _catalog_cache
    if _catalog_cache is not None:
        return _catalog_cache
    extra: dict[str, tuple[str, str]] = {}
    if _catalog_loader is not None:
        try:
            extra = dict(_catalog_loader() or {})
        except FAIL_SOFT:
            extra = {}
    _catalog_cache = extra
    return extra


def _tokens(text: str) -> list[str]:
    return [token for token in _TOKEN.findall((text or "").lower()) if len(token) > 2]


def prompt_key(
    topic: str,
    subject: str = "",
    education_level: str = "",
    exam_board: str = "",
) -> str:
    parts = [
        slugify(topic, "topic"),
        slugify(subject, "general"),
        slugify(normalize_level(education_level) or education_level, "unspecified"),
        slugify(exam_board, "none"),
    ]
    digest = hashlib.sha256("|".join(parts).encode("utf-8")).hexdigest()
    return digest[:32]


def label_prompt(
    topic: str,
    subject: str = "",
    education_level: str = "",
    exam_board: str = "",
) -> dict[str, Any]:
    """Label an intake so similar lessons can share a research base.

    Example: magnets → subject physics, cluster magnetism.
    Call this before plan_retrieval.
    """
    topic = " ".join((topic or "").split())
    provided_subject = " ".join((subject or "").split()).lower()
    level = normalize_level(education_level) or " ".join(
        (education_level or "").split()
    )
    board = " ".join((exam_board or "").split()).lower()
    tokens = _tokens(topic)
    keywords: list[str] = []
    cluster = slugify(topic, "topic")
    inferred_subject = provided_subject
    cluster_known = False
    mapped_tokens: list[str] = []

    def _apply_alias(token: str, alias: tuple[str, str]) -> None:
        nonlocal cluster, inferred_subject, cluster_known
        alias_cluster, alias_subject = alias
        cluster = alias_cluster
        cluster_known = True
        if token not in mapped_tokens:
            mapped_tokens.append(token)
        if not inferred_subject:
            inferred_subject = alias_subject
        if alias_cluster.replace("-", " ") not in " ".join(keywords):
            keywords.append(alias_cluster.replace("-", " "))

    for token in tokens:
        if token not in keywords:
            keywords.append(token)
        alias = _ALIASES.get(token)
        if alias:
            _apply_alias(token, alias)

    # Catalog I/O only when static aliases missed. Known topics stay in-process.
    if not cluster_known:
        catalog = _load_catalog()
        if catalog:
            for token in tokens:
                alias = catalog.get(token)
                if alias:
                    _apply_alias(token, alias)

    if not inferred_subject:
        inferred_subject = "general"

    band = level_band(level)
    labels = {
        "topic": topic,
        "subject": inferred_subject,
        "education_level": level,
        "exam_board": board,
        "topic_cluster": cluster,
        "cluster_id": cluster,
        "cluster_known": cluster_known,
        "level_band": band,
        "keywords": keywords[:24],
        "mapped_tokens": mapped_tokens,
    }
    return {
        "success": True,
        "prompt_key": prompt_key(topic, inferred_subject, level, board),
        "raw_topic": topic,
        **labels,
        "labels": labels,
    }
