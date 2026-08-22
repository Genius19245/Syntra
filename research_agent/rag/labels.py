"""Deterministic labels for the shared research cache."""

from __future__ import annotations

import hashlib
import re
from typing import Any

from .store import normalize_level
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
    "ionic": ("ionic-bonding", "chemistry"),
    "bonding": ("ionic-bonding", "chemistry"),
    "scheduling": ("os-scheduling", "computer science"),
    "ww1": ("first-world-war", "history"),
    "wwi": ("first-world-war", "history"),
}


def _tokens(text: str) -> list[str]:
    return [
        token
        for token in _TOKEN.findall((text or "").lower())
        if len(token) > 2
    ]


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
    level = normalize_level(education_level) or " ".join((education_level or "").split())
    board = " ".join((exam_board or "").split()).lower()
    tokens = _tokens(topic)
    keywords: list[str] = []
    cluster = slugify(topic, "topic")
    inferred_subject = provided_subject

    for token in tokens:
        if token not in keywords:
            keywords.append(token)
        alias = _ALIASES.get(token)
        if alias:
            alias_cluster, alias_subject = alias
            cluster = alias_cluster
            if not inferred_subject:
                inferred_subject = alias_subject
            if alias_cluster.replace("-", " ") not in " ".join(keywords):
                keywords.append(alias_cluster.replace("-", " "))

    if not inferred_subject:
        inferred_subject = "general"

    labels = {
        "topic": topic,
        "subject": inferred_subject,
        "education_level": level,
        "exam_board": board,
        "topic_cluster": cluster,
        "keywords": keywords[:24],
    }
    return {
        "success": True,
        "prompt_key": prompt_key(topic, inferred_subject, level, board),
        "raw_topic": topic,
        **labels,
        "labels": labels,
    }
