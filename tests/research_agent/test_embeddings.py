from research_agent.rag.embeddings import (
    as_vector,
    cosine_similarity,
    default_embedder,
    embed_text,
    embeddings_enabled,
    reset_embedder,
)
from research_agent.rag.firebase_cache import (
    FirestoreBackend,
    MemoryBackend,
    ResearchCache,
)
from research_agent.rag.labels import label_prompt
from research_agent.schema import (
    ClaimVerification,
    PackageClaim,
    ResearchMethod,
    ResearchPackage,
    SourceRecord,
)

ALPHA = [1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
BETA = [0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]


class StubEmbedder:
    def __init__(self, mapping: dict[str, list[float]]):
        self.mapping = mapping
        self.default = [0.0] * 7 + [1.0]
        self.calls: list[str] = []

    def embed_texts(self, texts, *, task_type="RETRIEVAL_DOCUMENT"):
        vectors = []
        for text in texts:
            self.calls.append(task_type)
            lowered = (text or "").lower()
            matched = self.default
            for needle, vector in self.mapping.items():
                if needle.lower() in lowered:
                    matched = vector
                    break
            vectors.append(list(matched))
        return vectors


class BoomEmbedder:
    def embed_texts(self, texts, *, task_type="RETRIEVAL_DOCUMENT"):
        raise RuntimeError("vertex unavailable")


def _package(**overrides) -> ResearchPackage:
    data = {
        "topic": "Ohm's law",
        "subject": "physics",
        "education_level": "GCSE",
        "exam_board": "",
        "key_concepts": ["current", "voltage", "resistance"],
        "claims": [
            PackageClaim(
                claim="Ohm's law states that V = IR for an ohmic conductor.",
                evidence="Voltage is proportional to current at constant temperature.",
                sources=[
                    SourceRecord(
                        organisation="BBC Bitesize",
                        url="https://www.bbc.co.uk/bitesize/guides/ohms-law",
                        source_tier=3,
                    )
                ],
                verification=ClaimVerification(
                    verdict="VERIFIED",
                    confidence="HIGH",
                ),
            )
        ],
        "research_method": ResearchMethod(
            rag_used=False,
            web_used=True,
            fact_check_used=True,
            freshness="STABLE",
            retrieval_mode="WEB_ONLY",
        ),
    }
    data.update(overrides)
    return ResearchPackage.model_validate(data)


def test_cosine_similarity_ranks_aligned_vectors():
    assert cosine_similarity(ALPHA, ALPHA) == 1.0
    assert cosine_similarity(ALPHA, BETA) == 0.0
    assert cosine_similarity([], ALPHA) == 0.0


def test_memory_backend_skips_live_vertex():
    reset_embedder("unset")
    assert default_embedder() is None
    assert embed_text("magnets") is None


def test_store_writes_embedding_from_injected_embedder():
    stub = StubEmbedder({"ohm": ALPHA})
    cache = ResearchCache(MemoryBackend(), embedder=stub)
    stored = cache.store(_package())
    assert stored["stored"] is True
    labels = label_prompt("Ohm's law", "physics", "GCSE")
    doc = cache.backend.get(labels["prompt_key"])
    assert doc["embedding"] == ALPHA
    assert doc["embedding_model"]
    assert "RETRIEVAL_DOCUMENT" in stub.calls


def test_lookup_does_not_reembed_the_same_query():
    stub = StubEmbedder({"ohm": ALPHA})
    cache = ResearchCache(MemoryBackend(), embedder=stub)
    cache.store(_package())
    cache.lookup("Ohm's law", subject="physics", education_level="GCSE")
    after_first = stub.calls.count("RETRIEVAL_QUERY")
    assert after_first == 1
    cache.lookup("Ohm's law", subject="physics", education_level="GCSE")
    assert stub.calls.count("RETRIEVAL_QUERY") == after_first


def test_lookup_ranks_by_cosine_when_embeddings_exist():
    stub = StubEmbedder(
        {
            "alpha": ALPHA,
            "rutherford": ALPHA,
            "gold": ALPHA,
            "foil": ALPHA,
            "beta": BETA,
            "decay": BETA,
        }
    )
    cache = ResearchCache(MemoryBackend(), embedder=stub)
    cache.store(
        _package(
            topic="Alpha particle scattering",
            key_concepts=["nucleus", "deflection"],
            claims=[
                PackageClaim(
                    claim="Most alpha particles pass straight through gold foil.",
                    evidence="The atom is mostly empty space.",
                    sources=[
                        SourceRecord(
                            organisation="Institute of Physics",
                            url="https://www.iop.org/alpha-scattering",
                            source_tier=2,
                        )
                    ],
                    verification=ClaimVerification(
                        verdict="VERIFIED", confidence="HIGH"
                    ),
                )
            ],
        )
    )
    cache.store(
        _package(
            topic="Beta decay",
            key_concepts=["electron", "neutrino"],
            claims=[
                PackageClaim(
                    claim="Beta decay emits an electron from the nucleus.",
                    evidence="A neutron changes into a proton.",
                    sources=[
                        SourceRecord(
                            organisation="Institute of Physics",
                            url="https://www.iop.org/beta-decay",
                            source_tier=2,
                        )
                    ],
                    verification=ClaimVerification(
                        verdict="VERIFIED", confidence="HIGH"
                    ),
                )
            ],
        )
    )
    hits = cache.lookup(
        "Rutherford gold foil experiment",
        subject="physics",
        education_level="GCSE",
    )
    assert hits
    assert hits[0]["metadata"]["topic"] == "Alpha particle scattering"
    assert hits[0]["metadata"]["url"]
    assert hits[0]["metadata"]["source_tier"] == 2
    assert hits[0]["score"] < 0.95


def test_exact_key_still_wins_over_cosine():
    stub = StubEmbedder({"ohm": ALPHA, "magnet": ALPHA, "magnetism": ALPHA})
    cache = ResearchCache(MemoryBackend(), embedder=stub)
    cache.store(_package())
    cache.store(
        _package(
            topic="Permanent magnets",
            key_concepts=["poles", "field"],
            claims=[
                PackageClaim(
                    claim="A magnet has a north pole and a south pole.",
                    evidence="Opposite poles attract.",
                    sources=[
                        SourceRecord(
                            organisation="BBC Bitesize",
                            url="https://www.bbc.co.uk/bitesize/guides/magnets",
                            source_tier=3,
                        )
                    ],
                    verification=ClaimVerification(
                        verdict="VERIFIED", confidence="HIGH"
                    ),
                )
            ],
        )
    )
    hits = cache.lookup("Ohm's law", subject="physics", education_level="GCSE")
    assert hits
    assert hits[0]["metadata"]["exact"] is True
    assert hits[0]["metadata"]["topic"] == "Ohm's law"


def test_embedder_failure_falls_back_to_lexical():
    cache = ResearchCache(MemoryBackend(), embedder=BoomEmbedder())
    stored = cache.store(_package())
    assert stored["stored"] is True
    labels = label_prompt("Ohm's law", "physics", "GCSE")
    doc = cache.backend.get(labels["prompt_key"])
    assert not doc.get("embedding")
    hits = cache.lookup("Ohm's law", subject="physics", education_level="GCSE")
    assert hits
    assert hits[0]["metadata"]["exact"] is True


def test_disable_embeddings_with_env_flag(monkeypatch):
    monkeypatch.setenv("SYNTRA_EMBEDDINGS_ENABLED", "false")
    reset_embedder("unset")
    assert embeddings_enabled() is False
    stub = StubEmbedder({"ohm": ALPHA})
    cache = ResearchCache(MemoryBackend(), embedder=stub)
    cache.store(_package())
    labels = label_prompt("Ohm's law", "physics", "GCSE")
    doc = cache.backend.get(labels["prompt_key"])
    assert not doc.get("embedding")
    assert stub.calls == []


class RecordingBackend(MemoryBackend):
    def __init__(self) -> None:
        super().__init__()
        self.nearest_calls: list[tuple[list[float], str, str, int]] = []
        self.list_cluster_calls = 0
        self.fail_nearest: bool | str = False

    def list_clusters(self) -> list[dict]:
        self.list_cluster_calls += 1
        return super().list_clusters()

    def find_nearest(
        self,
        query_vector,
        *,
        subject="",
        topic_cluster="",
        limit=10,
    ):
        self.nearest_calls.append((list(query_vector), subject, topic_cluster, limit))
        if self.fail_nearest is True:
            raise RuntimeError("vector index unavailable")
        if self.fail_nearest == "empty":
            return []
        return super().find_nearest(
            query_vector, subject=subject, topic_cluster=topic_cluster, limit=limit
        )


class _FakeVector:
    def __init__(self, values):
        self._value = tuple(float(item) for item in values)


def test_as_vector_unpacks_firestore_vector():
    assert as_vector(_FakeVector(ALPHA)) == ALPHA
    assert as_vector(ALPHA) == ALPHA
    assert as_vector("not-a-vector") is None


def test_lookup_uses_mocked_vector_search():
    stub = StubEmbedder(
        {
            "alpha": ALPHA,
            "rutherford": ALPHA,
            "gold": ALPHA,
            "foil": ALPHA,
            "beta": BETA,
            "decay": BETA,
        }
    )
    backend = RecordingBackend()
    cache = ResearchCache(backend, embedder=stub)
    cache.store(
        _package(
            topic="Alpha particle scattering",
            key_concepts=["nucleus", "deflection"],
            claims=[
                PackageClaim(
                    claim="Most alpha particles pass straight through gold foil.",
                    evidence="The atom is mostly empty space.",
                    sources=[
                        SourceRecord(
                            organisation="Institute of Physics",
                            url="https://www.iop.org/alpha-scattering",
                            source_tier=2,
                        )
                    ],
                    verification=ClaimVerification(
                        verdict="VERIFIED", confidence="HIGH"
                    ),
                )
            ],
        )
    )
    cache.store(
        _package(
            topic="Beta decay",
            key_concepts=["electron", "neutrino"],
            claims=[
                PackageClaim(
                    claim="Beta decay emits an electron from the nucleus.",
                    evidence="A neutron changes into a proton.",
                    sources=[
                        SourceRecord(
                            organisation="Institute of Physics",
                            url="https://www.iop.org/beta-decay",
                            source_tier=2,
                        )
                    ],
                    verification=ClaimVerification(
                        verdict="VERIFIED", confidence="HIGH"
                    ),
                )
            ],
        )
    )
    hits = cache.lookup(
        "Rutherford gold foil experiment",
        subject="physics",
        education_level="GCSE",
    )
    assert backend.nearest_calls
    assert hits[0]["metadata"]["topic"] == "Alpha particle scattering"
    assert hits[0]["score"] < 0.95


def test_vector_search_failure_falls_back_to_lexical():
    stub = StubEmbedder({"ohm": ALPHA})
    backend = RecordingBackend()
    backend.fail_nearest = True
    cache = ResearchCache(backend, embedder=stub)
    cache.store(_package())
    hits = cache.lookup("Ohm's law", subject="physics", education_level="GCSE")
    assert backend.nearest_calls
    assert hits
    assert hits[0]["metadata"]["exact"] is True


def test_empty_vector_index_falls_back_to_subject_query():
    stub = StubEmbedder({"ohm": ALPHA})
    backend = RecordingBackend()
    backend.fail_nearest = "empty"
    cache = ResearchCache(backend, embedder=stub)
    cache.store(_package())
    hits = cache.lookup("Ohm's law", subject="physics", education_level="GCSE")
    assert backend.nearest_calls
    assert hits
    assert hits[0]["metadata"]["topic"] == "Ohm's law"


def test_firestore_backend_upsert_stores_vector_type():
    backend = FirestoreBackend.__new__(FirestoreBackend)
    stored: dict = {}

    class _Doc:
        def set(self, data, merge=True):
            stored.update(data)

    class _Coll:
        def document(self, key):
            return _Doc()

    backend.collection = _Coll()
    backend.upsert("key", {"embedding": ALPHA, "subject": "physics"})
    from google.cloud.firestore_v1.vector import Vector

    assert isinstance(stored["embedding"], Vector)
    assert list(stored["embedding"]) == ALPHA


def test_firestore_backend_find_nearest_uses_cosine():
    backend = FirestoreBackend.__new__(FirestoreBackend)
    captured: dict = {}

    class _Snap:
        id = "abc"

        def to_dict(self):
            return {
                "subject": "physics",
                "package": {"topic": "Ohm's law"},
                "raw_topic": "Ohm's law",
                "embedding": ALPHA,
            }

    class _Result:
        def stream(self):
            return [_Snap()]

    class _Coll:
        def find_nearest(self, **kwargs):
            captured.update(kwargs)
            return _Result()

        def where(self, *args, **kwargs):
            captured["filtered"] = True
            return self

    backend.collection = _Coll()
    hits = backend.find_nearest(ALPHA, subject="physics", limit=5)
    assert captured["vector_field"] == "embedding"
    assert captured["distance_measure"].name == "COSINE"
    assert captured["limit"] == 5
    assert captured.get("filtered") is True
    assert hits[0]["prompt_key"] == "abc"
    assert hits[0]["subject"] == "physics"


def test_known_cluster_passes_topic_cluster_into_find_nearest():
    stub = StubEmbedder({"magnet": ALPHA, "magnetism": ALPHA})
    backend = RecordingBackend()
    cache = ResearchCache(backend, embedder=stub)
    cache.store(_package(topic="magnets"))
    assert backend.list_cluster_calls == 0
    backend.nearest_calls.clear()
    cache.lookup("magnetic fields", subject="physics", education_level="GCSE")
    assert backend.list_cluster_calls == 0
    clustered = [call for call in backend.nearest_calls if call[2] == "magnetism"]
    unfiltered = [call for call in backend.nearest_calls if call[2] == ""]
    assert len(clustered) == 1
    assert unfiltered == []
    assert clustered[0][1] == "physics"


def test_unknown_cluster_does_not_filter_find_nearest_by_cluster():
    stub = StubEmbedder({"quokka": ALPHA})
    backend = RecordingBackend()
    cache = ResearchCache(backend, embedder=stub)
    cache.store(_package(topic="quokka taxonomy", subject="biology"))
    cache.lookup("quokka taxonomy", subject="biology", education_level="GCSE")
    assert backend.nearest_calls
    clusters = {call[2] for call in backend.nearest_calls}
    assert clusters == {""}


def test_cluster_index_failure_falls_back_to_subject_only():
    class ClusterFailBackend(RecordingBackend):
        def find_nearest(self, query_vector, *, subject="", topic_cluster="", limit=10):
            self.nearest_calls.append(
                (list(query_vector), subject, topic_cluster, limit)
            )
            if topic_cluster:
                raise RuntimeError("cluster vector index missing")
            return MemoryBackend.find_nearest(
                self,
                query_vector,
                subject=subject,
                topic_cluster="",
                limit=limit,
            )

    stub = StubEmbedder({"magnet": ALPHA, "magnetism": ALPHA})
    backend = ClusterFailBackend()
    cache = ResearchCache(backend, embedder=stub)
    cache.store(_package(topic="magnets"))
    hits = cache.lookup("magnets", subject="physics", education_level="GCSE")
    assert hits
    assert any(call[2] == "magnetism" for call in backend.nearest_calls)
    assert any(call[2] == "" and call[1] == "physics" for call in backend.nearest_calls)


def test_gcse_corpus_stays_narrow():
    from research_agent.rag.firebase_cache import _document_corpus
    from research_agent.rag.labels import label_prompt

    labels = label_prompt("magnets", "physics", "GCSE")
    corpus = _document_corpus(_package(topic="magnets"), labels).lower()
    assert "undergraduate" not in corpus
    assert "electromagnetic-induction" not in corpus
    assert "a-level" not in corpus
