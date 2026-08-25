from research_agent.rag.store import KnowledgeStore
from research_agent.rag.writer import persist_research_package, should_persist
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


def test_persist_roundtrip_is_retrievable(tmp_path):
    store = KnowledgeStore(root=tmp_path, documents=[])
    result = persist_research_package(_package(), store=store, root=tmp_path)
    assert result["stored"] is True
    assert result["path"].startswith("previous_research/")
    written = tmp_path / result["path"]
    assert written.is_file()
    hits = store.retrieve(
        "Explain Ohm's law.",
        filters={"subject": "physics", "education_level": "GCSE"},
    )
    assert hits
    assert "ohm" in hits[0]["text"].lower()
    assert hits[0]["metadata"]["content_type"] == "previous_research"


def test_unverified_claims_are_not_stored(tmp_path):
    package = _package(
        claims=[
            PackageClaim(
                claim="An unverified classroom claim.",
                evidence="None",
                verification=ClaimVerification(
                    verdict="UNVERIFIED",
                    confidence="LOW",
                ),
            )
        ]
    )
    ok, reason = should_persist(package)
    assert ok is False
    result = persist_research_package(
        package, store=KnowledgeStore(root=tmp_path, documents=[]), root=tmp_path
    )
    assert result["stored"] is False
    assert "verified" in reason.lower()


def test_time_sensitive_packages_are_not_stored(tmp_path):
    package = _package(
        research_method=ResearchMethod(
            rag_used=False,
            web_used=True,
            fact_check_used=True,
            freshness="TIME_SENSITIVE",
            retrieval_mode="WEB_ONLY",
        )
    )
    result = persist_research_package(
        package,
        store=KnowledgeStore(root=tmp_path, documents=[]),
        root=tmp_path,
    )
    assert result["stored"] is False
    assert "Time-sensitive" in result["reason"]


def test_upsert_replaces_previous_version(tmp_path):
    store = KnowledgeStore(root=tmp_path, documents=[])
    first = persist_research_package(_package(), store=store, root=tmp_path)
    updated = _package(
        claims=[
            PackageClaim(
                claim="Potential difference equals current multiplied by resistance.",
                evidence="Updated verified wording.",
                sources=[
                    SourceRecord(
                        organisation="AQA",
                        url="https://www.aqa.org.uk/ohms-law",
                        source_tier=1,
                    )
                ],
                verification=ClaimVerification(verdict="VERIFIED", confidence="HIGH"),
            )
        ]
    )
    second = persist_research_package(updated, store=store, root=tmp_path)
    assert first["path"] == second["path"]
    hits = store.retrieve("Ohm's law resistance", filters={"subject": "physics"})
    joined = " ".join(hit["text"] for hit in hits)
    assert "Updated verified wording" in joined
    assert "BBC Bitesize" not in joined
