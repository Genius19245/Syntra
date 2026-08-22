from research_agent.rag.firebase_cache import MemoryBackend, ResearchCache, default_cache
from research_agent.rag.labels import label_prompt
from research_agent.rag.router import plan_retrieval_mode
from research_agent.rag.store import KnowledgeStore
from research_agent.rag.tools import retrieve_knowledge
from research_agent.schema import (
    ClaimVerification,
    PackageClaim,
    ResearchMethod,
    ResearchPackage,
    SourceRecord,
)


def _package(**overrides) -> ResearchPackage:
    data = dict(
        topic="Ohm's law",
        subject="physics",
        education_level="GCSE",
        exam_board="",
        key_concepts=["current", "voltage", "resistance"],
        claims=[
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
        research_method=ResearchMethod(
            rag_used=False,
            web_used=True,
            fact_check_used=True,
            freshness="STABLE",
            retrieval_mode="WEB_ONLY",
        ),
    )
    data.update(overrides)
    return ResearchPackage.model_validate(data)


def test_magnets_label_as_physics():
    labels = label_prompt("magnets")
    assert labels["success"] is True
    assert labels["subject"] == "physics"
    assert labels["topic_cluster"] == "magnetism"
    assert "magnetism" in labels["keywords"]
    assert labels["prompt_key"]


def test_exact_cache_hit_skips_web(tmp_path):
    cache = ResearchCache(MemoryBackend())
    stored = cache.store(_package())
    assert stored["stored"] is True

    plan = plan_retrieval_mode(
        "Ohm's law",
        education_level="GCSE",
        subject="physics",
        store=KnowledgeStore(root=tmp_path, documents=[]),
        cache=cache,
    )
    assert plan["mode"] == "RAG_ONLY"
    assert plan["web_needed"] is False
    assert plan["cache_exact"] is True
    assert plan["cache_hit_count"] >= 1


def test_cache_miss_still_researches(tmp_path):
    plan = plan_retrieval_mode(
        "Explain quokka taxonomy",
        education_level="GCSE",
        subject="biology",
        store=KnowledgeStore(root=tmp_path, documents=[]),
        cache=ResearchCache(MemoryBackend()),
    )
    assert plan["mode"] == "WEB_ONLY"
    assert plan["web_needed"] is True
    assert plan["cache_exact"] is False
    assert plan["cache_hit_count"] == 0


def test_time_sensitive_packages_are_not_cached():
    cache = ResearchCache(MemoryBackend())
    package = _package(
        research_method=ResearchMethod(
            rag_used=False,
            web_used=True,
            fact_check_used=True,
            freshness="TIME_SENSITIVE",
            retrieval_mode="WEB_ONLY",
        )
    )
    result = cache.store(package)
    assert result["stored"] is False
    assert "Time-sensitive" in result["reason"]
    labels = label_prompt(package.topic, package.subject, package.education_level)
    assert cache.backend.get(labels["prompt_key"]) is None


def test_research_agent_exposes_label_prompt():
    from research_agent.agent import research_agent

    names = [getattr(tool, "__name__", None) or getattr(tool, "name", None) for tool in research_agent.tools]
    assert "label_prompt" in names
    assert [agent.name for agent in research_agent.sub_agents] == [
        "source_researcher",
        "fact_checker",
    ]


def test_retrieve_knowledge_uses_cache_before_seed_files():
    cache = default_cache()
    stored = cache.store(_package())
    assert stored["stored"] is True
    result = retrieve_knowledge("Ohm's law", subject="physics", education_level="GCSE")
    assert result["cache_hit_count"] >= 1
    assert result["hit_count"] >= 1
    sources = {hit["metadata"].get("source") for hit in result["hits"]}
    assert sources == {"firestore_cache"}


def test_named_exam_board_does_not_return_other_board_cache():
    cache = ResearchCache(MemoryBackend())
    cache.store(_package(exam_board="OCR", topic="magnets"))
    cache.store(_package(exam_board="AQA", topic="magnets"))
    hits = cache.lookup(
        "magnets",
        subject="physics",
        education_level="GCSE",
        exam_board="AQA",
    )
    boards = {str(hit["metadata"].get("exam_board") or "").lower() for hit in hits}
    assert "ocr" not in boards
    assert "aqa" in boards


def test_backfill_embeddings_writes_missing_vectors():
    class FakeEmbedder:
        def embed_texts(self, texts, *, task_type="RETRIEVAL_DOCUMENT"):
            return [[0.1, 0.2, 0.3] for _ in texts]

    cache = ResearchCache(MemoryBackend(), embedder=None)
    stored = cache.store(_package())
    assert stored["stored"] is True
    key = stored["prompt_key"]
    doc = cache.backend.get(key)
    assert doc is not None
    doc.pop("embedding", None)
    cache.backend.docs[key] = doc
    cache.embedder = FakeEmbedder()
    result = cache.backfill_embeddings()
    assert result["success"] is True
    assert result["updated"] >= 1
    assert cache.backend.get(key).get("embedding") == [0.1, 0.2, 0.3]


def test_retrieve_knowledge_falls_back_to_seed_markdown():
    result = retrieve_knowledge(
        "Teach me electromagnetic induction.",
        subject="physics",
        education_level="A-Level",
    )
    assert result["cache_hit_count"] == 0
    assert result["hit_count"] >= 1
    assert result["hits"][0]["metadata"]["topic"] == "electromagnetic induction"

