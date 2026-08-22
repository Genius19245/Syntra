"""In-memory lexical knowledge store with metadata filters."""

from __future__ import annotations

import re
from pathlib import Path
from typing import Any

from .indexer import KNOWLEDGE_ROOT, KnowledgeDocument, chunk_document, index_knowledge

_TOKEN = re.compile(r"[a-z0-9]+")

_LEVEL_ALIASES = {
    "gcse": "gcse",
    "ks4": "gcse",
    "ks3": "gcse",
    "a-level": "a-level",
    "alevel": "a-level",
    "a level": "a-level",
    "as-level": "a-level",
    "as level": "a-level",
    "undergraduate": "undergraduate",
    "university": "undergraduate",
    "undergrad": "undergraduate",
    "bachelor": "undergraduate",
    "bachelor's": "undergraduate",
    "bachelors": "undergraduate",
    "master": "postgraduate",
    "master's": "postgraduate",
    "masters": "postgraduate",
    "postgraduate": "postgraduate",
    "beginner": "beginner",
    "intermediate": "intermediate",
    "advanced": "advanced",
    "primary": "primary",
    "ks2": "primary",
    "ks1": "primary",
}

_BAND = {
    "primary": 0,
    "beginner": 0,
    "gcse": 1,
    "intermediate": 1,
    "a-level": 2,
    "advanced": 2,
    "undergraduate": 3,
    "postgraduate": 4,
}

_STOPWORDS = {
    "about",
    "and",
    "explain",
    "for",
    "from",
    "into",
    "me",
    "the",
    "teach",
    "what",
    "with",
}


def normalize_level(value: str | None) -> str:
    text = " ".join((value or "").lower().replace("_", " ").split())
    return _LEVEL_ALIASES.get(text, text)


def _tokens(text: str) -> set[str]:
    return {
        token
        for token in _TOKEN.findall((text or "").lower())
        if len(token) > 2 and token not in _STOPWORDS
    }


def _compatible_level(query_level: str, doc_level: str) -> bool:
    if not query_level or not doc_level:
        return True
    q_band = _BAND.get(query_level)
    d_band = _BAND.get(doc_level)
    if q_band is None or d_band is None:
        return query_level == doc_level
    school = {0, 1, 2}
    university = {3, 4}
    if q_band in university and d_band in school:
        return False
    if q_band in school and d_band in university:
        return False
    return abs(q_band - d_band) <= 1


class KnowledgeStore:
    def __init__(
        self, root: Path | None = None, documents: list[KnowledgeDocument] | None = None
    ):
        self.root = Path(root) if root is not None else KNOWLEDGE_ROOT
        self.documents = (
            documents if documents is not None else index_knowledge(self.root)
        )

    def reload(self) -> int:
        self.documents = index_knowledge(self.root)
        return len(self.documents)

    def upsert(self, document: KnowledgeDocument) -> int:
        """Replace any chunks for this path, then add freshly chunked docs."""
        base_path = document.path.split("#", 1)[0]
        self.documents = [
            item
            for item in self.documents
            if item.path != base_path and not item.path.startswith(base_path + "#")
        ]
        chunks = chunk_document(document)
        self.documents.extend(chunks)
        return len(chunks)

    def retrieve(
        self,
        query: str,
        filters: dict[str, Any] | None = None,
        k: int = 5,
    ) -> list[dict[str, Any]]:
        filters = filters or {}
        query_tokens = _tokens(query)
        subject = str(filters.get("subject") or "").strip().lower()
        exam_board = str(filters.get("exam_board") or "").strip().lower()
        education_level = normalize_level(str(filters.get("education_level") or ""))

        scored: list[tuple[float, KnowledgeDocument]] = []
        for document in self.documents:
            meta = document.metadata
            doc_subject = str(meta.get("subject") or "").strip().lower()
            doc_level = normalize_level(str(meta.get("education_level") or ""))
            doc_board = str(meta.get("exam_board") or "").strip().lower()

            if (
                subject
                and doc_subject
                and subject not in doc_subject
                and doc_subject not in subject
            ):
                continue
            if not _compatible_level(education_level, doc_level):
                continue
            if exam_board and doc_board and exam_board != doc_board:
                continue

            haystack = _tokens(
                " ".join(
                    [
                        document.title,
                        document.body,
                        str(meta.get("topic") or ""),
                        doc_subject,
                    ]
                )
            )
            if not query_tokens:
                overlap = 0.0
            else:
                overlap = len(query_tokens & haystack) / len(query_tokens)

            if overlap <= 0:
                continue

            score = overlap
            if education_level and doc_level == education_level:
                score += 0.35
            if exam_board and doc_board and exam_board == doc_board:
                score += 0.4
            elif exam_board and doc_board and exam_board != doc_board:
                score -= 0.15
            if subject and doc_subject and subject == doc_subject:
                score += 0.2
            try:
                tier = int(meta.get("source_tier") or 4)
            except (TypeError, ValueError):
                tier = 4
            score += max(0, 6 - tier) * 0.03
            scored.append((score, document))

        scored.sort(key=lambda item: item[0], reverse=True)
        hits: list[dict[str, Any]] = []
        for score, document in scored[:k]:
            hits.append(
                {
                    "score": round(score, 4),
                    "path": document.path,
                    "title": document.title,
                    "text": document.body,
                    "metadata": dict(document.metadata),
                }
            )
        return hits


_DEFAULT_STORE: KnowledgeStore | None = None


def default_store() -> KnowledgeStore:
    global _DEFAULT_STORE
    if _DEFAULT_STORE is None:
        _DEFAULT_STORE = KnowledgeStore()
    return _DEFAULT_STORE


def reset_default_store() -> None:
    global _DEFAULT_STORE
    _DEFAULT_STORE = None
