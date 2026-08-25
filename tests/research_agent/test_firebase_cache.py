from datetime import datetime, timedelta, timezone

from research_agent.rag.firebase_cache import (
    MemoryBackend,
    ResearchCache,
    default_cache,
)
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

    names = [
        getattr(tool, "__name__", None) or getattr(tool, "name", None)
        for tool in research_agent.tools
    ]
    assert "label_prompt" in names
    assert [agent.name for agent in research_agent.sub_agents] == [
        "source_researcher",
        "fact_checker",
    ]


def test_retrieve_knowledge_reuses_plan_lookup(monkeypatch):
    from research_agent.rag.firebase_cache import ResearchCache
    from research_agent.rag.tools import plan_retrieval, retrieve_knowledge

    cache = default_cache()
    assert cache.store(_package())["stored"] is True
    lookups = {"n": 0}
    real = ResearchCache.lookup

    def counting(self, *args, **kwargs):
        lookups["n"] += 1
        return real(self, *args, **kwargs)

    monkeypatch.setattr(ResearchCache, "lookup", counting)
    ctx = type("Ctx", (), {"state": {}})()
    plan = plan_retrieval(
        "Ohm's law",
        education_level="GCSE",
        subject="physics",
        tool_context=ctx,
    )
    assert plan["cache_exact"] is True
    after_plan = lookups["n"]
    assert after_plan >= 1
    result = retrieve_knowledge(
        "Ohm's law",
        education_level="GCSE",
        subject="physics",
        tool_context=ctx,
    )
    assert result["cache_hit_count"] >= 1
    assert lookups["n"] == after_plan


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


class BoomEmbedder:
    def embed_texts(self, texts, *, task_type="RETRIEVAL_DOCUMENT"):
        raise RuntimeError("vertex unavailable")


def test_list_hits_orders_by_hit_count():
    cache = ResearchCache(MemoryBackend(), embedder=None)
    magnets = cache.store(_package(topic="magnets"))
    ohms = cache.store(_package(topic="Ohm's law"))
    osmosis = cache.store(
        _package(topic="osmosis", subject="biology", exam_board="AQA")
    )
    assert magnets["stored"] and ohms["stored"] and osmosis["stored"]
    for _ in range(3):
        cache.backend.bump_hits(osmosis["prompt_key"])
    cache.backend.bump_hits(magnets["prompt_key"])

    rows = cache.list_hits(limit=10)
    assert [row["topic"] for row in rows[:3]] == ["osmosis", "magnets", "Ohm's law"]
    assert rows[0]["hits"] == 3
    assert rows[0]["subject"] == "biology"
    assert rows[0]["level"] == "gcse"
    assert rows[0]["board"] == "aqa"
    assert rows[1]["hits"] == 1
    assert rows[2]["hits"] == 0
    assert "updated_at" in rows[0]
    assert rows[0]["updated_at"]


def test_list_hits_respects_limit_and_is_read_only():
    cache = ResearchCache(MemoryBackend(), embedder=None)
    first = cache.store(_package(topic="magnets"))
    second = cache.store(_package(topic="osmosis", subject="biology"))
    cache.backend.bump_hits(second["prompt_key"])
    cache.backend.bump_hits(second["prompt_key"])
    before = cache.backend.get(first["prompt_key"])["hit_count"]
    rows = cache.list_hits(limit=1)
    assert len(rows) == 1
    assert rows[0]["topic"] == "osmosis"
    assert rows[0]["hits"] == 2
    assert cache.backend.get(first["prompt_key"])["hit_count"] == before
    assert cache.list_hits(limit=0) == []


def test_list_hits_omits_package_bodies():
    cache = ResearchCache(MemoryBackend(), embedder=BoomEmbedder())
    stored = cache.store(_package())
    assert stored["stored"] is True
    rows = cache.list_hits(limit=5)
    assert rows
    for row in rows:
        assert "package" not in row
        assert "claims" not in row
        assert "evidence" not in row
        assert "embedding" not in row
        assert set(row) == {
            "topic",
            "subject",
            "level",
            "board",
            "hits",
            "updated_at",
        }


def test_default_cache_list_hits_uses_memory_backend():
    cache = default_cache()
    stored = cache.store(_package(topic="ionic bonding"))
    assert stored["stored"] is True
    cache.backend.bump_hits(stored["prompt_key"])
    rows = cache.list_hits(limit=5)
    topics = {row["topic"] for row in rows}
    assert "ionic bonding" in topics
    assert any(row["hits"] >= 1 for row in rows if row["topic"] == "ionic bonding")


def test_cache_hits_script_prints_table_without_package(capsys):
    import importlib.util
    from pathlib import Path

    cache = ResearchCache(MemoryBackend(), embedder=None)
    stored = cache.store(_package(topic="magnets", exam_board="OCR"))
    cache.backend.bump_hits(stored["prompt_key"])
    spec = importlib.util.spec_from_file_location(
        "cache_hits",
        Path(__file__).resolve().parents[2] / "scripts" / "cache_hits.py",
    )
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    code = module.run(limit=5, cache=cache)
    captured = capsys.readouterr()
    assert code == 0
    assert "HITS" in captured.out
    assert "magnets" in captured.out
    assert "ocr" in captured.out
    assert "Ohm's law states" not in captured.out
    assert "package" not in captured.out.lower()


def _age_cache_doc(cache: ResearchCache, prompt_key: str, *, days: int) -> None:
    stamped = datetime.now(timezone.utc) - timedelta(days=days)
    doc = cache.backend.docs[prompt_key]
    doc["updated_at"] = stamped
    doc["created_at"] = stamped


def test_fresh_exact_lookup_skips_web(tmp_path, monkeypatch):
    monkeypatch.setenv("SYNTRA_CACHE_TTL_DAYS", "30")
    cache = ResearchCache(MemoryBackend())
    stored = cache.store(_package())
    assert stored["stored"] is True
    hits = cache.lookup("Ohm's law", subject="physics", education_level="GCSE")
    assert hits
    assert hits[0]["metadata"]["exact"] is True
    assert hits[0]["metadata"]["stale"] is False

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
    assert plan["refresh_cache"] is False


def test_stale_exact_lookup_allows_web(tmp_path, monkeypatch):
    monkeypatch.setenv("SYNTRA_CACHE_TTL_DAYS", "30")
    cache = ResearchCache(MemoryBackend())
    stored = cache.store(_package())
    _age_cache_doc(cache, stored["prompt_key"], days=45)

    hits = cache.lookup("Ohm's law", subject="physics", education_level="GCSE")
    assert hits
    assert hits[0]["metadata"]["exact"] is False
    assert hits[0]["metadata"]["stale"] is True
    assert hits[0]["metadata"]["stale_exact"] is True

    plan = plan_retrieval_mode(
        "Ohm's law",
        education_level="GCSE",
        subject="physics",
        store=KnowledgeStore(root=tmp_path, documents=[]),
        cache=cache,
    )
    assert plan["cache_exact"] is False
    assert plan["cache_stale"] is True
    assert plan["web_needed"] is True
    assert plan["mode"] != "RAG_ONLY"
    assert plan["mode"] in {"HYBRID", "WEB_ONLY"}


def test_refresh_bypasses_fresh_exact_hit(tmp_path, monkeypatch):
    monkeypatch.setenv("SYNTRA_CACHE_TTL_DAYS", "30")
    cache = ResearchCache(MemoryBackend())
    cache.store(_package())

    hits = cache.lookup(
        "Ohm's law",
        subject="physics",
        education_level="GCSE",
        refresh=True,
    )
    assert hits
    assert hits[0]["metadata"]["exact"] is False

    plan = plan_retrieval_mode(
        "Ohm's law",
        education_level="GCSE",
        subject="physics",
        store=KnowledgeStore(root=tmp_path, documents=[]),
        cache=cache,
        refresh_cache=True,
    )
    assert plan["refresh_cache"] is True
    assert plan["cache_exact"] is False
    assert plan["web_needed"] is True
    assert plan["mode"] != "RAG_ONLY"

    via_text = plan_retrieval_mode(
        "Ohm's law\nRefresh cache: yes",
        education_level="GCSE",
        subject="physics",
        store=KnowledgeStore(root=tmp_path, documents=[]),
        cache=cache,
    )
    assert via_text["refresh_cache"] is True
    assert via_text["cache_exact"] is False
    assert via_text["web_needed"] is True
    assert via_text["mode"] != "RAG_ONLY"


def test_osmosis_and_magnets_are_known_clusters():
    magnets = label_prompt("magnets")
    osmosis = label_prompt("osmosis in cells")
    unique = label_prompt("quokka taxonomy")
    assert magnets["cluster_known"] is True
    assert magnets["topic_cluster"] == "magnetism"
    assert magnets["cluster_id"] == "magnetism"
    assert magnets["level_band"] is None
    assert osmosis["cluster_known"] is True
    assert osmosis["topic_cluster"] == "osmosis"
    assert unique["cluster_known"] is False
    assert unique["topic_cluster"] != "osmosis"
    gcse = label_prompt("magnets", "physics", "GCSE")
    assert gcse["level_band"] == 1


def test_store_writes_level_band_and_merges_cluster_doc():
    backend = MemoryBackend()
    cache = ResearchCache(backend, embedder=None)
    backend.clusters["magnetism"] = {
        "cluster_id": "magnetism",
        "related_clusters": ["electromagnetic-induction"],
        "aliases": ["magnetism"],
        "levels_seen": [],
        "subject": "",
    }
    stored = cache.store(_package(topic="magnets"))
    assert stored["stored"] is True
    doc = backend.get(stored["prompt_key"])
    assert doc["cluster_id"] == "magnetism"
    assert doc["level_band"] == 1
    assert doc["topic_cluster"] == "magnetism"
    cluster = backend.get_cluster("magnetism")
    assert cluster is not None
    assert "magnets" in cluster["aliases"]
    assert "magnetism" in cluster["aliases"]
    assert "gcse" in cluster["levels_seen"]
    assert cluster["subject"] == "physics"
    assert cluster["related_clusters"] == ["electromagnetic-induction"]


def test_catalog_alias_overlay_joins_variant_titles():
    from research_agent.rag.firebase_cache import _catalog_from_backend
    from research_agent.rag.labels import label_prompt, set_catalog_aliases

    backend = MemoryBackend()
    cache = ResearchCache(backend, embedder=None)
    assert cache.store(_package(topic="osmosis", subject="biology"))["stored"] is True
    backend.upsert_cluster(
        "osmosis",
        {
            "cluster_id": "osmosis",
            "subject": "biology",
            "aliases": ["osmosis", "hypertonic"],
        },
    )
    set_catalog_aliases(_catalog_from_backend(backend))
    labels = label_prompt("hypertonic solutions", subject="biology")
    assert labels["cluster_known"] is True
    assert labels["topic_cluster"] == "osmosis"


def test_gcse_lookup_does_not_return_undergraduate_same_cluster():
    cache = ResearchCache(MemoryBackend(), embedder=None)
    cache.store(_package(topic="magnets", education_level="GCSE"))
    cache.store(_package(topic="magnets", education_level="undergraduate"))
    hits = cache.lookup("magnets", subject="physics", education_level="GCSE")
    levels = {str(hit["metadata"].get("education_level") or "") for hit in hits}
    assert "undergraduate" not in levels
    assert "gcse" in levels


def test_backfill_writes_level_band_and_clusters_flag_remaps():
    class FakeEmbedder:
        def embed_texts(self, texts, *, task_type="RETRIEVAL_DOCUMENT"):
            return [[0.1, 0.2, 0.3] for _ in texts]

    backend = MemoryBackend()
    cache = ResearchCache(backend, embedder=FakeEmbedder())
    stored = cache.store(_package(topic="magnets"))
    key = stored["prompt_key"]
    doc = backend.docs[key]
    doc["topic_cluster"] = "magnets-gcse-lesson"
    doc["cluster_id"] = "magnets-gcse-lesson"
    doc.pop("level_band", None)
    backend.docs[key] = doc
    result = cache.backfill_embeddings(clusters=True)
    assert result["success"] is True
    assert result["updated"] >= 1
    updated = backend.get(key)
    assert updated["level_band"] == 1
    assert updated["topic_cluster"] == "magnetism"
    assert updated["cluster_id"] == "magnetism"
    assert backend.get_cluster("magnetism") is not None
