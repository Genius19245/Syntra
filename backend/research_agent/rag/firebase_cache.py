"""Shared Firestore research cache. Admin SDK only; clients cannot write."""

from __future__ import annotations

import os
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
from typing import Any, Protocol

from .embeddings import (
    FAIL_SOFT,
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
from ..schema import ResearchPackage
from .labels import (
    extend_catalog_aliases,
    label_prompt,
    set_catalog_aliases,
    set_catalog_loader,
)
from .store import _compatible_level, level_band, normalize_level
from .writer import should_persist, storable_claims

# All SYNTRA project data lives under this collection tree.
WORKSPACE_COLLECTION = "syntra"
WORKSPACE_ID = "workspace"
CACHE_COLLECTION = "research_cache"
CLUSTER_COLLECTION = "topic_clusters"
PROJECT_ID = os.environ.get("GOOGLE_CLOUD_PROJECT", "agenticsai2026")
MIN_CACHE_SCORE = 0.35
EXACT_CACHE_SCORE = 0.95
# Keep vector scores strictly below an exact prompt-key hit.
VECTOR_SCORE_CAP = 0.94
CLUSTER_BONUS = 0.08
KEYWORD_BONUS = 0.07
EXAM_BOARD_BONUS = 0.05
HIT_LIST_SCAN_LIMIT = 400
HIT_LIST_SCAN_CAP = 1000
DEFAULT_CACHE_TTL_DAYS = 30


class CacheBackend(Protocol):
    def get(self, prompt_key: str) -> dict[str, Any] | None: ...
    def query_subject(self, subject: str, limit: int = 40) -> list[dict[str, Any]]: ...
    def find_nearest(
        self,
        query_vector: list[float],
        *,
        subject: str = "",
        topic_cluster: str = "",
        limit: int = 10,
    ) -> list[dict[str, Any]]: ...
    def upsert(self, prompt_key: str, data: dict[str, Any]) -> None: ...
    def bump_hits(self, prompt_key: str) -> None: ...


class MemoryBackend:
    def __init__(self) -> None:
        self.docs: dict[str, dict[str, Any]] = {}
        self.clusters: dict[str, dict[str, Any]] = {}

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
        topic_cluster: str = "",
        limit: int = 10,
    ) -> list[dict[str, Any]]:
        subject = (subject or "").lower()
        cluster = (topic_cluster or "").strip()
        scored: list[tuple[float, dict[str, Any]]] = []
        for doc in self.docs.values():
            if subject and str(doc.get("subject") or "").lower() != subject:
                continue
            if (
                cluster
                and str(doc.get("topic_cluster") or doc.get("cluster_id") or "")
                != cluster
            ):
                continue
            entry_vec = as_vector(doc.get("embedding"))
            if not entry_vec:
                continue
            scored.append((cosine_similarity(query_vector, entry_vec), dict(doc)))
        scored.sort(key=lambda item: item[0], reverse=True)
        return [doc for _, doc in scored[: max(1, int(limit or 10))]]

    def get_cluster(self, cluster_id: str) -> dict[str, Any] | None:
        data = self.clusters.get(cluster_id)
        return dict(data) if data else None

    def upsert_cluster(self, cluster_id: str, data: dict[str, Any]) -> None:
        existing = dict(self.clusters.get(cluster_id) or {})
        incoming = dict(data)
        incoming.pop("related_clusters", None)
        incoming.pop("related_clusters", None)
        aliases = {
            str(item).strip().lower()
            for item in (existing.get("aliases") or [])
            if item
        }
        aliases.update(
            str(item).strip().lower()
            for item in (incoming.pop("aliases", None) or [])
            if item
        )
        levels = [str(item) for item in (existing.get("levels_seen") or []) if item]
        for item in incoming.pop("levels_seen", None) or []:
            level = str(item)
            if level and level not in levels:
                levels.append(level)
        subject = str(existing.get("subject") or "").strip()
        incoming_subject = str(incoming.pop("subject", "") or "").strip()
        if not subject and incoming_subject and incoming_subject != "general":
            subject = incoming_subject
        existing.update(incoming)
        existing["cluster_id"] = cluster_id
        existing["aliases"] = sorted(aliases)
        existing["levels_seen"] = levels
        if subject:
            existing["subject"] = subject
        self.clusters[cluster_id] = existing

    def list_clusters(self) -> list[dict[str, Any]]:
        return [dict(doc) for doc in self.clusters.values()]

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
        doc["updated_at"] = _now()

    def list_docs(
        self, limit: int = 400, *, order_by_hits: bool = False
    ) -> list[dict[str, Any]]:
        docs = [dict(doc) for doc in self.docs.values()]
        if order_by_hits:
            docs.sort(key=_hit_count_sort_key, reverse=True)
        return docs[: max(0, int(limit or 0))]


class FirestoreBackend:
    def __init__(self, client: Any):
        self.client = client
        self.workspace = client.collection(WORKSPACE_COLLECTION).document(WORKSPACE_ID)
        self.collection = self.workspace.collection(CACHE_COLLECTION)
        self.clusters = self.workspace.collection(CLUSTER_COLLECTION)
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
        except FAIL_SOFT:
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
        topic_cluster: str = "",
        limit: int = 10,
    ) -> list[dict[str, Any]]:
        from google.cloud.firestore_v1.base_vector_query import DistanceMeasure

        if not hasattr(self.collection, "find_nearest"):
            raise RuntimeError("Firestore client does not support find_nearest.")
        vector = _as_firestore_vector(query_vector)
        if vector is None:
            return []
        capped = max(1, min(int(limit or 10), VECTOR_QUERY_LIMIT_MAX))
        cluster_key = (topic_cluster or "").strip()
        cluster_applied = bool(cluster_key)
        query = self._filtered_query(subject, cluster_key)
        try:
            docs = _stream_nearest(query, vector, capped, DistanceMeasure.COSINE)
        except FAIL_SOFT:
            if cluster_applied:
                cluster_applied = False
                query = self._filtered_query(subject, "")
                try:
                    docs = _stream_nearest(
                        query, vector, capped, DistanceMeasure.COSINE
                    )
                except FAIL_SOFT:
                    if query is self.collection:
                        raise
                    docs = _stream_nearest(
                        self.collection, vector, capped, DistanceMeasure.COSINE
                    )
            elif query is self.collection:
                raise
            else:
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
            if cluster_applied:
                entry_cluster = str(
                    data.get("topic_cluster") or data.get("cluster_id") or ""
                )
                if entry_cluster != cluster_key:
                    continue
            hits.append(data)
        return hits

    def _where_eq(self, query: Any, field: str, value: str) -> Any:
        try:
            from google.cloud.firestore_v1.base_query import FieldFilter

            return query.where(filter=FieldFilter(field, "==", value))
        except FAIL_SOFT:
            try:
                return query.where(field, "==", value)
            except FAIL_SOFT:
                return query

    def _filtered_query(self, subject: str, topic_cluster: str = "") -> Any:
        query = self.collection
        subject_key = (subject or "").strip()
        cluster_key = (topic_cluster or "").strip()
        if subject_key and subject_key != "general":
            query = self._where_eq(query, "subject", subject_key)
        if cluster_key:
            query = self._where_eq(query, "topic_cluster", cluster_key)
        return query

    def _subject_query(self, subject: str) -> Any:
        return self._filtered_query(subject)

    def get_cluster(self, cluster_id: str) -> dict[str, Any] | None:
        snap = self.clusters.document(cluster_id).get()
        if not snap.exists:
            return None
        data = snap.to_dict() or {}
        data["cluster_id"] = snap.id
        return data

    def upsert_cluster(self, cluster_id: str, data: dict[str, Any]) -> None:
        payload = dict(data)
        payload.pop("related_clusters", None)
        payload.pop("related_clusters", None)
        aliases = [
            str(item).strip().lower() for item in (payload.get("aliases") or []) if item
        ]
        levels = [str(item) for item in (payload.get("levels_seen") or []) if item]
        try:
            from google.cloud.firestore import ArrayUnion

            if aliases:
                payload["aliases"] = ArrayUnion(aliases)
            if levels:
                payload["levels_seen"] = ArrayUnion(levels)
        except FAIL_SOFT:
            if aliases:
                payload["aliases"] = aliases
            if levels:
                payload["levels_seen"] = levels
        subject = str(payload.get("subject") or "").strip()
        if not subject or subject == "general":
            payload.pop("subject", None)
        self.clusters.document(cluster_id).set(payload, merge=True)

    def list_clusters(self) -> list[dict[str, Any]]:
        hits: list[dict[str, Any]] = []
        for snap in self.clusters.stream():
            data = snap.to_dict() or {}
            data["cluster_id"] = snap.id
            hits.append(data)
        return hits

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

    def list_docs(
        self, limit: int = 400, *, order_by_hits: bool = False
    ) -> list[dict[str, Any]]:
        capped = max(1, min(int(limit or 400), 1000))
        query = self.collection
        if order_by_hits:
            try:
                from google.cloud.firestore import Query

                query = query.order_by("hit_count", direction=Query.DESCENDING)
            except FAIL_SOFT:
                order_by_hits = False
        hits: list[dict[str, Any]] = []
        try:
            for snap in query.limit(capped).stream():
                hits.append(_doc_from_snapshot(snap))
        except FAIL_SOFT:
            if query is self.collection:
                raise
            hits = []
            for snap in self.collection.limit(capped).stream():
                hits.append(_doc_from_snapshot(snap))
            hits.sort(key=_hit_count_sort_key, reverse=True)
        return hits


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
    except FAIL_SOFT:
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
    except FAIL_SOFT:
        return vector


def _stream_nearest(
    query: Any, query_vector: Any, limit: int, distance_measure: Any
) -> Any:
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


def cache_ttl_days() -> int:
    raw = os.environ.get("SYNTRA_CACHE_TTL_DAYS", str(DEFAULT_CACHE_TTL_DAYS))
    try:
        return int(str(raw).strip())
    except (TypeError, ValueError):
        return DEFAULT_CACHE_TTL_DAYS


def _parse_datetime(value: Any) -> datetime | None:
    if value is None:
        return None
    if isinstance(value, datetime):
        if value.tzinfo is None:
            return value.replace(tzinfo=timezone.utc)
        return value
    timestamp = getattr(value, "timestamp", None)
    if callable(timestamp):
        try:
            return datetime.fromtimestamp(float(timestamp()), tz=timezone.utc)
        except FAIL_SOFT:
            if not isinstance(value, str):
                return None
    if isinstance(value, str):
        text = value.strip()
        if not text:
            return None
        try:
            parsed = datetime.fromisoformat(text.replace("Z", "+00:00"))
        except ValueError:
            return None
        if parsed.tzinfo is None:
            return parsed.replace(tzinfo=timezone.utc)
        return parsed
    return None


def entry_timestamp(entry: dict[str, Any]) -> datetime | None:
    return _parse_datetime(entry.get("updated_at")) or _parse_datetime(
        entry.get("created_at")
    )


def is_cache_entry_stale(
    entry: dict[str, Any],
    *,
    now: datetime | None = None,
    ttl_days: int | None = None,
) -> bool:
    """True when updated_at/created_at is older than SYNTRA_CACHE_TTL_DAYS.

    TTL <= 0 disables expiry. Missing timestamps are treated as stale so
    undated packages cannot lock RAG_ONLY.
    """
    days = cache_ttl_days() if ttl_days is None else int(ttl_days)
    if days <= 0:
        return False
    stamped = entry_timestamp(entry)
    if stamped is None:
        return True
    current = now or _now()
    if current.tzinfo is None:
        current = current.replace(tzinfo=timezone.utc)
    return current - stamped > timedelta(days=days)


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
    def __init__(
        self, backend: CacheBackend | None = None, embedder: Any | None = None
    ):
        self.backend = backend if backend is not None else _default_backend()
        self.embedder = embedder if embedder is not None else default_embedder()

    def lookup(
        self,
        topic: str,
        subject: str = "",
        education_level: str = "",
        exam_board: str = "",
        k: int = 5,
        refresh: bool = False,
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
            query_board = (
                str(exam_board or labels.get("exam_board") or "").strip().lower()
            )
            entry_board = str(entry.get("exam_board") or "").strip().lower()
            if query_board and entry_board and query_board != entry_board:
                continue
            eligible.append(entry)
        scored: list[tuple[float, dict[str, Any], bool, bool]] = []
        query_key = str(labels.get("prompt_key") or "")
        for entry in eligible:
            score = _score_entry(labels, entry, query_embedding=query_embedding)
            stale = is_cache_entry_stale(entry)
            key_match = (
                bool(query_key) and str(entry.get("prompt_key") or "") == query_key
            )
            if (stale or refresh) and score >= EXACT_CACHE_SCORE:
                score = VECTOR_SCORE_CAP
            if score < MIN_CACHE_SCORE:
                continue
            scored.append((score, entry, stale, key_match))
        scored.sort(key=lambda item: item[0], reverse=True)
        chosen = scored[:k]
        to_bump = [
            str(entry["prompt_key"])
            for _score, entry, stale, key_match in chosen
            if not stale and not (refresh and key_match)
        ]
        _bump_hits(self.backend, to_bump)
        for score, entry, stale, key_match in chosen:
            exact = (not stale) and (not refresh) and score >= EXACT_CACHE_SCORE
            hits.append(
                _as_retrieval_hit(
                    entry,
                    score,
                    stale=stale,
                    exact=exact,
                    stale_exact=stale and key_match,
                )
            )
        return hits

    def store(
        self, package: ResearchPackage, labels: dict[str, Any] | None = None
    ) -> dict[str, Any]:
        if self.backend is None:
            return {
                "success": True,
                "stored": False,
                "reason": "Firestore cache unavailable.",
            }
        claims = storable_claims(package)
        ok, reason = should_persist(package, claims=claims)
        if not ok:
            return {"success": True, "stored": False, "reason": reason}
        labels = labels or _label_with_backend(package, self.backend)
        freshness = ""
        if package.research_method and package.research_method.freshness:
            freshness = str(package.research_method.freshness.value)
        payload = {
            "prompt_key": labels["prompt_key"],
            "raw_topic": labels.get("raw_topic") or package.topic,
            "subject": labels["subject"],
            "education_level": labels.get("education_level") or "",
            "exam_board": labels.get("exam_board") or "",
            "topic_cluster": labels["topic_cluster"],
            "cluster_id": labels.get("cluster_id") or labels["topic_cluster"],
            "keywords": list(labels.get("keywords") or [])[:24],
            "labels": labels.get("labels") or {},
            "package": package.model_dump(mode="json"),
            "freshness": freshness or "STABLE",
            "source_tier": 2,
            "claim_count": len(claims),
            "hit_count": 0,
            "updated_at": _now(),
        }
        band = labels.get("level_band")
        if band is None:
            band = level_band(labels.get("education_level") or package.education_level)
        if band is not None:
            payload["level_band"] = band
        vector = _document_embedding(package, labels, self.embedder, claims=claims)
        if vector:
            payload["embedding"] = vector
            payload["embedding_model"] = embedding_model_name()
        existing = None
        try:
            existing = self.backend.get(labels["prompt_key"])
        except FAIL_SOFT:
            existing = None
        if not existing:
            payload["created_at"] = _now()
        try:
            self.backend.upsert(labels["prompt_key"], payload)
        except FAIL_SOFT as exc:
            return {
                "success": False,
                "stored": False,
                "reason": f"Firestore write failed: {exc}",
            }
        _merge_cluster_doc(self.backend, labels)
        return {
            "success": True,
            "stored": True,
            "reason": "Verified research saved to Firestore cache.",
            "prompt_key": labels["prompt_key"],
            "exact": True,
        }

    def backfill_embeddings(
        self, *, limit: int = 400, dry_run: bool = False, clusters: bool = False
    ) -> dict[str, Any]:
        """Embed cache docs that were stored before vector search existed.

        Always backfills level_band. With clusters=True, remaps topic_cluster
        where aliases/catalog resolve a stable id and merges the cluster doc.
        """
        list_docs = getattr(self.backend, "list_docs", None)
        if not callable(list_docs):
            return {
                "success": False,
                "scanned": 0,
                "missing": 0,
                "updated": 0,
                "reason": "Cache backend cannot list documents.",
            }
        docs = list_docs(limit) or []
        missing = [doc for doc in docs if not as_vector(doc.get("embedding"))]
        updated = 0
        skipped = 0
        catalog = _catalog_from_backend(self.backend)
        for doc in docs:
            package_data = doc.get("package")
            package = None
            labels = None
            if isinstance(package_data, dict):
                try:
                    package = ResearchPackage.model_validate(package_data)
                except FAIL_SOFT:
                    package = None
            if package is not None:
                set_catalog_aliases(catalog)
                labels = label_prompt(
                    package.topic,
                    package.subject,
                    package.education_level,
                    package.exam_board,
                )
            patch: dict[str, Any] = {}
            needs_vector = not as_vector(doc.get("embedding"))
            if needs_vector:
                if package is None or labels is None:
                    skipped += 1
                else:
                    vector = _document_embedding(package, labels, self.embedder)
                    if not vector:
                        skipped += 1
                    else:
                        patch["embedding"] = vector
                        patch["embedding_model"] = embedding_model_name()
            band = doc.get("level_band")
            if not isinstance(band, int):
                source_level = ""
                if labels:
                    source_level = str(labels.get("education_level") or "")
                if not source_level:
                    source_level = str(doc.get("education_level") or "")
                computed = level_band(source_level)
                if computed is not None:
                    patch["level_band"] = computed
            if clusters and labels is not None and labels.get("cluster_known"):
                cluster_id = str(
                    labels.get("cluster_id") or labels.get("topic_cluster") or ""
                )
                if cluster_id and str(doc.get("topic_cluster") or "") != cluster_id:
                    patch["topic_cluster"] = cluster_id
                    patch["cluster_id"] = cluster_id
                if cluster_id and not dry_run:
                    _merge_cluster_doc(self.backend, labels)
                    cluster_subject = str(labels.get("subject") or "")
                    if cluster_subject == "general":
                        cluster_subject = ""
                    catalog[cluster_id] = (cluster_id, cluster_subject)
                    for token in labels.get("mapped_tokens") or []:
                        token_key = str(token).strip().lower()
                        if token_key:
                            catalog[token_key] = (cluster_id, cluster_subject)
            if not patch:
                continue
            patch["updated_at"] = _now()
            if not dry_run:
                key = str(
                    doc.get("prompt_key") or (labels or {}).get("prompt_key") or ""
                )
                if not key:
                    skipped += 1
                    continue
                self.backend.upsert(key, patch)
            updated += 1
        return {
            "success": True,
            "scanned": len(docs),
            "missing": len(missing),
            "updated": updated,
            "skipped": skipped,
            "dry_run": dry_run,
            "clusters": clusters,
        }

    def list_hits(self, *, limit: int = 20) -> list[dict[str, Any]]:
        """Rank cache docs by hit_count. Read-only; no embeddings or package dump."""
        if self.backend is None:
            return []
        capped = max(0, int(limit or 0))
        if capped == 0:
            return []
        list_docs = getattr(self.backend, "list_docs", None)
        if not callable(list_docs):
            return []
        scan = min(max(capped, HIT_LIST_SCAN_LIMIT), HIT_LIST_SCAN_CAP)
        try:
            docs = list_docs(scan, order_by_hits=True) or []
        except TypeError:
            docs = list_docs(scan) or []
        except FAIL_SOFT:
            return []
        ranked = sorted(docs, key=_hit_count_sort_key, reverse=True)
        return [_hit_row(doc) for doc in ranked[:capped]]


def _document_corpus(
    package: ResearchPackage,
    labels: dict[str, Any],
    claims: list | None = None,
) -> str:
    parts = [
        str(labels.get("raw_topic") or package.topic or ""),
        str(package.subject or ""),
        str(package.education_level or ""),
        " ".join(package.key_concepts or []),
    ]
    for claim in claims if claims is not None else storable_claims(package):
        parts.append(claim.claim)
        parts.append(claim.evidence)
    return "\n".join(part for part in parts if part)


def _document_embedding(
    package: ResearchPackage,
    labels: dict[str, Any],
    embedder: Any | None,
    claims: list | None = None,
) -> list[float] | None:
    if not embeddings_enabled() or embedder is None:
        return None
    try:
        return embed_text(
            _document_corpus(package, labels, claims=claims),
            task_type="RETRIEVAL_DOCUMENT",
            embedder=embedder,
        )
    except FAIL_SOFT:
        return None


def _bump_hits(backend: CacheBackend, keys: list[str]) -> None:
    if not keys:
        return

    def _one(key: str) -> None:
        try:
            backend.bump_hits(key)
        except FAIL_SOFT:
            return

    if len(keys) == 1:
        _one(keys[0])
        return
    with ThreadPoolExecutor(max_workers=min(4, len(keys))) as pool:
        list(pool.map(_one, keys))


def _label_with_backend(package: ResearchPackage, backend: Any) -> dict[str, Any]:
    return label_prompt(
        package.topic,
        package.subject,
        package.education_level,
        package.exam_board,
    )


def _catalog_from_backend(backend: Any) -> dict[str, tuple[str, str]]:
    list_clusters = getattr(backend, "list_clusters", None)
    if not callable(list_clusters):
        return {}
    try:
        docs = list_clusters() or []
    except FAIL_SOFT:
        return {}
    mapping: dict[str, tuple[str, str]] = {}
    for doc in docs:
        cluster_id = str(doc.get("cluster_id") or "").strip()
        subject = str(doc.get("subject") or "").strip()
        if cluster_id:
            mapping[cluster_id] = (cluster_id, subject)
        for alias in doc.get("aliases") or []:
            token = str(alias or "").strip().lower()
            if token and cluster_id:
                mapping[token] = (cluster_id, subject)
    return mapping


def _merge_cluster_doc(backend: Any, labels: dict[str, Any]) -> None:
    upsert_cluster = getattr(backend, "upsert_cluster", None)
    if not callable(upsert_cluster):
        return
    cluster_id = str(
        labels.get("cluster_id") or labels.get("topic_cluster") or ""
    ).strip()
    if not cluster_id:
        return
    aliases = {cluster_id}
    for token in labels.get("mapped_tokens") or []:
        token_key = str(token).strip().lower()
        if token_key:
            aliases.add(token_key)
    level = str(labels.get("education_level") or "").strip()
    incoming = str(labels.get("subject") or "").strip()
    payload: dict[str, Any] = {
        "cluster_id": cluster_id,
        "aliases": sorted(aliases),
        "updated_at": _now(),
    }
    if level:
        payload["levels_seen"] = [level]
    if incoming and incoming != "general":
        payload["subject"] = incoming
    try:
        upsert_cluster(cluster_id, payload)
    except FAIL_SOFT:
        return
    subject_key = incoming if incoming != "general" else ""
    entries = {cluster_id: (cluster_id, subject_key)}
    for token in aliases:
        entries[token] = (cluster_id, subject_key)
    extend_catalog_aliases(entries)


def _process_catalog_loader() -> dict[str, tuple[str, str]]:
    try:
        backend = _default_backend()
    except FAIL_SOFT:
        return {}
    if backend is None:
        return {}
    return _catalog_from_backend(backend)


def _collect_candidates(
    backend: CacheBackend,
    labels: dict[str, Any],
    query_embedding: list[float] | None,
) -> list[dict[str, Any]]:
    """Exact key, then Firestore vector search, then subject/lexical download."""
    candidates: list[dict[str, Any]] = []
    try:
        exact = backend.get(labels["prompt_key"])
    except FAIL_SOFT:
        exact = None
    if exact:
        candidates.append(exact)

    nearest: list[dict[str, Any]] = []
    vector_used = False
    find_nearest = getattr(backend, "find_nearest", None)
    subject_key = str(labels.get("subject") or "")
    cluster_key = (
        str(labels.get("topic_cluster") or "") if labels.get("cluster_known") else ""
    )
    subject_arg = "" if not subject_key or subject_key == "general" else subject_key
    if query_embedding and callable(find_nearest):

        def _nearest(topic_cluster: str) -> list[dict[str, Any]]:
            try:
                return (
                    find_nearest(
                        query_embedding,
                        subject=subject_arg,
                        topic_cluster=topic_cluster,
                        limit=VECTOR_CANDIDATE_LIMIT,
                    )
                    or []
                )
            except TypeError:
                return (
                    find_nearest(
                        query_embedding,
                        subject=subject_arg,
                        limit=VECTOR_CANDIDATE_LIMIT,
                    )
                    or []
                )

        try:
            nearest = _nearest(cluster_key)
        except FAIL_SOFT:
            nearest = []
            if cluster_key:
                try:
                    nearest = _nearest("")
                except FAIL_SOFT:
                    nearest = []
        vector_used = bool(nearest)
    candidates.extend(nearest)

    if not vector_used and subject_key and subject_key != "general":
        try:
            extra = backend.query_subject(subject_key)
        except FAIL_SOFT:
            extra = []
        candidates.extend(extra)
    return candidates


_QUERY_EMBED_CACHE: dict[tuple[str, int], list[float]] = {}
_QUERY_EMBED_CACHE_MAX = 64


def _query_embedding(
    topic: str,
    embedder: Any | None,
) -> list[float] | None:
    if not embeddings_enabled() or embedder is None:
        return None
    cache_key = (topic, id(embedder))
    cached = _QUERY_EMBED_CACHE.get(cache_key)
    if cached is not None:
        return cached
    try:
        vector = embed_text(topic, task_type="RETRIEVAL_QUERY", embedder=embedder)
    except FAIL_SOFT:
        return None
    if vector:
        if len(_QUERY_EMBED_CACHE) >= _QUERY_EMBED_CACHE_MAX:
            _QUERY_EMBED_CACHE.pop(next(iter(_QUERY_EMBED_CACHE)))
        _QUERY_EMBED_CACHE[cache_key] = vector
    return vector


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
        except FAIL_SOFT:
            return ""
    return str(value)


def _hit_count_sort_key(doc: dict[str, Any]) -> tuple[int, str]:
    try:
        hits = int(doc.get("hit_count") or 0)
    except (TypeError, ValueError):
        hits = 0
    return (hits, _as_timestamp(doc.get("updated_at")))


def _hit_row(doc: dict[str, Any]) -> dict[str, Any]:
    """Admin summary only. Never copy package bodies or claim text."""
    package = doc.get("package") if isinstance(doc.get("package"), dict) else {}
    topic = str(doc.get("raw_topic") or package.get("topic") or "").strip()
    try:
        hits = int(doc.get("hit_count") or 0)
    except (TypeError, ValueError):
        hits = 0
    return {
        "topic": topic,
        "subject": str(doc.get("subject") or "").strip(),
        "level": str(doc.get("education_level") or "").strip(),
        "board": str(doc.get("exam_board") or "").strip(),
        "hits": hits,
        "updated_at": _as_timestamp(doc.get("updated_at")),
    }


def _as_retrieval_hit(
    entry: dict[str, Any],
    score: float,
    *,
    stale: bool = False,
    exact: bool | None = None,
    stale_exact: bool = False,
) -> dict[str, Any]:
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
    is_exact = (
        bool(exact) if exact is not None else (score >= EXACT_CACHE_SCORE and not stale)
    )
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
            "exact": is_exact,
            "stale": bool(stale),
            "stale_exact": bool(stale_exact),
            "source_tier": entry.get("source_tier"),
            "hit_count": int(entry.get("hit_count") or 0),
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
    except FAIL_SOFT:
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


set_catalog_loader(_process_catalog_loader)
