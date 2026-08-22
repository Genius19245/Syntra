"""Shared Firestore research cache. Admin SDK only; clients cannot write."""

from __future__ import annotations

import os
from datetime import datetime, timezone
from typing import Any, Protocol

from .embeddings import (
    as_vector,
    cosine_similarity,
    default_embedder,
    embed_text,
    embedding_model_name,
    embeddings_enabled,
)

VECTOR_FIELD = "embedding"
VECTOR_CANDIDATE_LIMIT = 24
VECTOR_QUERY_LIMIT_MAX = 100
from .labels import label_prompt
from .store import _compatible_level, normalize_level
from .writer import storable_claims, should_persist
from ..schema import ResearchPackage

# All SYNTRA project data lives under this collection tree.
WORKSPACE_COLLECTION = "syntra"
WORKSPACE_ID = "workspace"
CACHE_COLLECTION = "research_cache"
PROJECT_ID = os.environ.get("GOOGLE_CLOUD_PROJECT", "agenticsai2026")
MIN_CACHE_SCORE = 0.35
EXACT_CACHE_SCORE = 0.95
# Keep vector scores strictly below an exact prompt-key hit.
VECTOR_SCORE_CAP = 0.94
CLUSTER_BONUS = 0.08
KEYWORD_BONUS = 0.07
EXAM_BOARD_BONUS = 0.05


class CacheBackend(Protocol):
    def get(self, prompt_key: str) -> dict[str, Any] | None: ...
    def query_subject(self, subject: str, limit: int = 40) -> list[dict[str, Any]]: ...
    def find_nearest(
        self,
        query_vector: list[float],
        *,
        subject: str = "",
        limit: int = 10,
    ) -> list[dict[str, Any]]: ...
    def upsert(self, prompt_key: str, data: dict[str, Any]) -> None: ...
    def bump_hits(self, prompt_key: str) -> None: ...


class MemoryBackend:
    def __init__(self) -> None:
        self.docs: dict[str, dict[str, Any]] = {}

    def get(self, prompt_key: str) -> dict[str, Any] | None:
        data = self.docs.get(prompt_key)
        return dict(data) if data else None

    def query_subject(self, subject: str, limit: int = 40) -> list[dict[str, Any]]:
        subject = (subject or "").lower()
        hits = [
            dict(doc)
            for doc in self.docs.values()
            if str(doc.get("subject") or "").lower() == subject
        ]
        return hits[:limit]

    def find_nearest(
        self,
        query_vector: list[float],
        *,
        subject: str = "",
        limit: int = 10,
    ) -> list[dict[str, Any]]:
        subject = (subject or "").lower()
        scored: list[tuple[float, dict[str, Any]]] = []
        for doc in self.docs.values():
            if subject and str(doc.get("subject") or "").lower() != subject:
                continue
            entry_vec = as_vector(doc.get("embedding"))
            if not entry_vec:
                continue
            scored.append((cosine_similarity(query_vector, entry_vec), dict(doc)))
        scored.sort(key=lambda item: item[0], reverse=True)
        return [doc for _, doc in scored[: max(1, int(limit or 10))]]

    def upsert(self, prompt_key: str, data: dict[str, Any]) -> None:
        existing = self.docs.get(prompt_key, {})
        merged = dict(existing)
        merged.update(data)
        merged["prompt_key"] = prompt_key
        self.docs[prompt_key] = merged

    def bump_hits(self, prompt_key: str) -> None:
        doc = self.docs.get(prompt_key)
        if not doc:
            return
        doc["hit_count"] = int(doc.get("hit_count") or 0) + 1


class FirestoreBackend:
    def __init__(self, client: Any):
        self.client = client
        self.workspace = client.collection(WORKSPACE_COLLECTION).document(WORKSPACE_ID)
        self.collection = self.workspace.collection(CACHE_COLLECTION)
        ensure_workspace(self.workspace)

    def get(self, prompt_key: str) -> dict[str, Any] | None:
        snap = self.collection.document(prompt_key).get()
        if not snap.exists:
            return None
        data = snap.to_dict() or {}
        data["prompt_key"] = snap.id
        return data

    def query_subject(self, subject: str, limit: int = 40) -> list[dict[str, Any]]:
        try:
            from google.cloud.firestore_v1.base_query import FieldFilter

            query = self.collection.where(
                filter=FieldFilter("subject", "==", subject)
            ).limit(limit)
        except Exception:
            query = self.collection.where("subject", "==", subject).limit(limit)
        hits: list[dict[str, Any]] = []
        for snap in query.stream():
            hits.append(_doc_from_snapshot(snap))
        return hits

    def find_nearest(
        self,
        query_vector: list[float],
        *,
        subject: str = "",
        limit: int = 10,
    ) -> list[dict[str, Any]]:
        from google.cloud.firestore_v1.base_vector_query import DistanceMeasure

        if not hasattr(self.collection, "find_nearest"):
            raise RuntimeError("Firestore client does not support find_nearest.")
        vector = _as_firestore_vector(query_vector)
        if vector is None:
            return []
        capped = max(1, min(int(limit or 10), VECTOR_QUERY_LIMIT_MAX))
        query = self._subject_query(subject)
        try:
            docs = _stream_nearest(query, vector, capped, DistanceMeasure.COSINE)
        except Exception:
            if query is self.collection:
                raise
            docs = _stream_nearest(
                self.collection, vector, capped, DistanceMeasure.COSINE
            )
        hits: list[dict[str, Any]] = []
        subject_key = (subject or "").strip().lower()
        for snap in docs:
            data = _doc_from_snapshot(snap)
            if (
                subject_key
                and subject_key != "general"
                and str(data.get("subject") or "").strip().lower() != subject_key
            ):
                continue
            hits.append(data)
        return hits

    def _subject_query(self, subject: str) -> Any:
        subject_key = (subject or "").strip()
        if not subject_key or subject_key == "general":
            return self.collection
        try:
            from google.cloud.firestore_v1.base_query import FieldFilter

            return self.collection.where(filter=FieldFilter("subject", "==", subject_key))
        except Exception:
            try:
                return self.collection.where("subject", "==", subject_key)
            except Exception:
                return self.collection

    def upsert(self, prompt_key: str, data: dict[str, Any]) -> None:
        payload = dict(data)
        vector = _as_firestore_vector(payload.get("embedding"))
        if vector is not None:
            payload["embedding"] = vector
        self.collection.document(prompt_key).set(payload, merge=True)

    def bump_hits(self, prompt_key: str) -> None:
        from google.cloud.firestore import Increment

        self.collection.document(prompt_key).update(
            {"hit_count": Increment(1), "updated_at": _now()}
        )


def ensure_workspace(workspace_ref: Any) -> None:
    """Create the SYNTRA workspace document if this project has none yet."""
    try:
        snap = workspace_ref.get()
        now = _now()
        if snap.exists:
            return
        workspace_ref.set(
            {
                "name": "SYNTRA",
                "project": PROJECT_ID,
                "description": (
                    "Canonical SYNTRA workspace. Verified lesson research "
                    "is stored in the research_cache subcollection."
                ),
                "created_at": now,
                "updated_at": now,
            }
        )
    except Exception:
        return


def _doc_from_snapshot(snap: Any) -> dict[str, Any]:
    data = snap.to_dict() or {}
    data["prompt_key"] = snap.id
    return data


def _as_firestore_vector(value: Any) -> Any | None:
    vector = as_vector(value)
    if not vector:
        return None
    try:
        from google.cloud.firestore_v1.vector import Vector

        return Vector(vector)
    except Exception:
        return vector


def _stream_nearest(query: Any, query_vector: Any, limit: int, distance_measure: Any) -> Any:
    vector_query = query.find_nearest(
        vector_field=VECTOR_FIELD,
        query_vector=query_vector,
        distance_measure=distance_measure,
        limit=limit,
    )
    if hasattr(vector_query, "stream"):
        return vector_query.stream()
    return vector_query.get()


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _lexical_score(labels: dict[str, Any], entry: dict[str, Any]) -> float:
    query_cluster = str(labels.get("topic_cluster") or "")
    entry_cluster = str(entry.get("topic_cluster") or "")
    query_words = set(labels.get("keywords") or [])
    entry_words = set(entry.get("keywords") or [])
    score = 0.0
    if query_cluster and query_cluster == entry_cluster:
        score += 0.55
    if query_words and entry_words:
        score += 0.45 * (len(query_words & entry_words) / len(query_words))
    if labels.get("exam_board") and labels["exam_board"] == entry.get("exam_board"):
        score += 0.1
    return score


def _keyword_overlap(labels: dict[str, Any], entry: dict[str, Any]) -> float:
    query_words = set(labels.get("keywords") or [])
    entry_words = set(entry.get("keywords") or [])
    if not query_words or not entry_words:
        return 0.0
    return len(query_words & entry_words) / len(query_words)


def _score_entry(
    labels: dict[str, Any],
    entry: dict[str, Any],
    query_embedding: list[float] | None = None,
) -> float:
    if labels.get("prompt_key") and entry.get("prompt_key") == labels["prompt_key"]:
        return EXACT_CACHE_SCORE
    entry_vec = as_vector(entry.get("embedding"))
    if query_embedding and entry_vec:
        cosine = max(0.0, cosine_similarity(query_embedding, entry_vec))
        score = cosine
        if str(labels.get("topic_cluster") or "") and labels.get(
            "topic_cluster"
        ) == entry.get("topic_cluster"):
            score += CLUSTER_BONUS
        score += KEYWORD_BONUS * _keyword_overlap(labels, entry)
        if labels.get("exam_board") and labels["exam_board"] == entry.get("exam_board"):
            score += EXAM_BOARD_BONUS
        return min(VECTOR_SCORE_CAP, score)
    return _lexical_score(labels, entry)


class ResearchCache:
    def __init__(self, backend: CacheBackend | None = None, embedder: Any | None = None):
        self.backend = backend if backend is not None else _default_backend()
        self.embedder = embedder if embedder is not None else default_embedder()

    def lookup(
        self,
        topic: str,
        subject: str = "",
        education_level: str = "",
        exam_board: str = "",
        k: int = 5,
    ) -> list[dict[str, Any]]:
        if self.backend is None:
            return []
        labels = label_prompt(topic, subject, education_level, exam_board)
        hits: list[dict[str, Any]] = []
        query_embedding = _query_embedding(topic, self.embedder)
        candidates = _collect_candidates(
            self.backend, labels, query_embedding=query_embedding
        )
        seen: set[str] = set()
        eligible: list[dict[str, Any]] = []
        for entry in candidates:
            if not entry:
                continue
            key = str(entry.get("prompt_key") or "")
            if not key or key in seen or key.startswith("_"):
                continue
            seen.add(key)
            if entry.get("bootstrap") or not entry.get("package"):
                continue
            if not _compatible_level(
                normalize_level(education_level) or education_level,
                normalize_level(str(entry.get("education_level") or "")),
            ):
                continue
            if str(entry.get("freshness") or "") == "TIME_SENSITIVE":
                continue
            eligible.append(entry)
        scored: list[tuple[float, dict[str, Any]]] = []
        for entry in eligible:
            score = _score_entry(labels, entry, query_embedding=query_embedding)
            if score < MIN_CACHE_SCORE:
                continue
            scored.append((score, entry))
        scored.sort(key=lambda item: item[0], reverse=True)
        for score, entry in scored[:k]:
            try:
                self.backend.bump_hits(str(entry["prompt_key"]))
            except Exception:
                pass
            hits.append(_as_retrieval_hit(entry, score))
        return hits

    def store(self, package: ResearchPackage, labels: dict[str, Any] | None = None) -> dict[str, Any]:
        if self.backend is None:
            return {"success": True, "stored": False, "reason": "Firestore cache unavailable."}
        ok, reason = should_persist(package)
        if not ok:
            return {"success": True, "stored": False, "reason": reason}
        labels = labels or label_prompt(
            package.topic,
            package.subject,
            package.education_level,
            package.exam_board,
        )
        freshness = ""
        if package.research_method and package.research_method.freshness:
            freshness = str(package.research_method.freshness.value)
        claims = storable_claims(package)
        payload = {
            "prompt_key": labels["prompt_key"],
            "raw_topic": labels.get("raw_topic") or package.topic,
            "subject": labels["subject"],
            "education_level": labels.get("education_level") or "",
            "exam_board": labels.get("exam_board") or "",
            "topic_cluster": labels["topic_cluster"],
            "keywords": list(labels.get("keywords") or [])[:24],
            "labels": labels.get("labels") or {},
            "package": package.model_dump(mode="json"),
            "freshness": freshness or "STABLE",
            "source_tier": 2,
            "claim_count": len(claims),
            "hit_count": 0,
            "updated_at": _now(),
        }
        vector = _document_embedding(package, labels, self.embedder)
        if vector:
            payload["embedding"] = vector
            payload["embedding_model"] = embedding_model_name()
        existing = None
        try:
            existing = self.backend.get(labels["prompt_key"])
        except Exception:
            existing = None
        if not existing:
            payload["created_at"] = _now()
        try:
            self.backend.upsert(labels["prompt_key"], payload)
        except Exception as exc:
            return {
                "success": False,
                "stored": False,
                "reason": f"Firestore write failed: {exc}",
            }
        return {
            "success": True,
            "stored": True,
            "reason": "Verified research saved to Firestore cache.",
            "prompt_key": labels["prompt_key"],
            "exact": True,
        }


def _document_corpus(package: ResearchPackage, labels: dict[str, Any]) -> str:
    parts = [
        str(labels.get("raw_topic") or package.topic or ""),
        str(package.subject or ""),
        str(package.education_level or ""),
        " ".join(package.key_concepts or []),
    ]
    for claim in storable_claims(package):
        parts.append(claim.claim)
        parts.append(claim.evidence)
    return "\n".join(part for part in parts if part)


def _document_embedding(
    package: ResearchPackage,
    labels: dict[str, Any],
    embedder: Any | None,
) -> list[float] | None:
    if not embeddings_enabled() or embedder is None:
        return None
    try:
        return embed_text(
            _document_corpus(package, labels),
            task_type="RETRIEVAL_DOCUMENT",
            embedder=embedder,
        )
    except Exception:
        return None


def _collect_candidates(
    backend: CacheBackend,
    labels: dict[str, Any],
    query_embedding: list[float] | None,
) -> list[dict[str, Any]]:
    """Exact key, then Firestore vector search, then subject/lexical download."""
    candidates: list[dict[str, Any]] = []
    try:
        exact = backend.get(labels["prompt_key"])
    except Exception:
        exact = None
    if exact:
        candidates.append(exact)

    nearest: list[dict[str, Any]] = []
    vector_used = False
    find_nearest = getattr(backend, "find_nearest", None)
    subject_key = str(labels.get("subject") or "")
    if query_embedding and callable(find_nearest):
        try:
            nearest = (
                find_nearest(
                    query_embedding,
                    subject="" if not subject_key or subject_key == "general" else subject_key,
                    limit=VECTOR_CANDIDATE_LIMIT,
                )
                or []
            )
            vector_used = bool(nearest)
        except Exception:
            nearest = []
            vector_used = False
    candidates.extend(nearest)

    if not vector_used and subject_key and subject_key != "general":
        try:
            candidates.extend(backend.query_subject(subject_key))
        except Exception:
            pass
    return candidates


def _query_embedding(
    topic: str,
    embedder: Any | None,
) -> list[float] | None:
    if not embeddings_enabled() or embedder is None:
        return None
    try:
        return embed_text(topic, task_type="RETRIEVAL_QUERY", embedder=embedder)
    except Exception:
        return None


def _first_url(package: dict[str, Any]) -> str:
    for source in package.get("sources") or []:
        if isinstance(source, dict) and source.get("url"):
            return str(source["url"])
    for claim in package.get("claims") or []:
        if not isinstance(claim, dict):
            continue
        for source in claim.get("sources") or []:
            if isinstance(source, dict) and source.get("url"):
                return str(source["url"])
    return ""


def _as_timestamp(value: Any) -> str:
    if value is None:
        return ""
    if hasattr(value, "isoformat"):
        try:
            return str(value.isoformat())
        except Exception:
            return ""
    return str(value)


def _as_retrieval_hit(entry: dict[str, Any], score: float) -> dict[str, Any]:
    package = entry.get("package") or {}
    text_parts = [
        str(entry.get("raw_topic") or ""),
        str(package.get("topic") or ""),
    ]
    for claim in package.get("claims") or []:
        if isinstance(claim, dict):
            text_parts.append(str(claim.get("claim") or ""))
            text_parts.append(str(claim.get("evidence") or ""))
    publication_date = _as_timestamp(entry.get("created_at"))
    last_checked = _as_timestamp(entry.get("updated_at")) or publication_date
    return {
        "score": round(score, 4),
        "path": f"firestore:{entry.get('prompt_key')}",
        "title": entry.get("raw_topic") or package.get("topic") or "Cached research",
        "text": "\n".join(part for part in text_parts if part),
        "metadata": {
            "source": "firestore_cache",
            "subject": entry.get("subject"),
            "education_level": entry.get("education_level"),
            "exam_board": entry.get("exam_board"),
            "topic": entry.get("raw_topic"),
            "topic_cluster": entry.get("topic_cluster"),
            "content_type": "previous_research",
            "prompt_key": entry.get("prompt_key"),
            "exact": score >= EXACT_CACHE_SCORE,
            "source_tier": entry.get("source_tier"),
            "publication_date": publication_date,
            "last_checked": last_checked,
            "url": _first_url(package),
        },
        "package": package,
    }


_BACKEND: CacheBackend | None | str = "unset"


def _firestore_client() -> Any | None:
    try:
        import firebase_admin
        from firebase_admin import firestore as admin_firestore

        if not firebase_admin._apps:
            firebase_admin.initialize_app(options={"projectId": PROJECT_ID})
        return admin_firestore.client()
    except Exception:
        return None


def _default_backend() -> CacheBackend | None:
    global _BACKEND
    if _BACKEND != "unset":
        return _BACKEND  # type: ignore[return-value]
    if os.environ.get("SYNTRA_FIRESTORE_BACKEND") == "memory":
        _BACKEND = MemoryBackend()
        return _BACKEND
    client = _firestore_client()
    _BACKEND = FirestoreBackend(client) if client is not None else None
    return _BACKEND


def reset_cache_backend(backend: CacheBackend | None | str = "unset") -> None:
    global _BACKEND
    _BACKEND = backend


def default_cache() -> ResearchCache:
    return ResearchCache()
