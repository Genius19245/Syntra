from research_agent.fact_checker.schema import FactCheckReport, Verification
from research_agent.schema import (
    Confidence,
    Evidence,
    PackageClaim,
    ResearchPackage,
    SourceRecord,
)


def test_evidence_object_is_fact_checker_ready():
    evidence = Evidence(
        claim="Ionic bonding is the attraction between oppositely charged ions.",
        evidence="GCSE chemistry describes ionic bonding as electron transfer forming a lattice.",
        source="SYNTRA seed notes",
        url="https://syntra.local/knowledge/ionic-bonding",
        source_authority="educational_sample",
        source_tier=2,
        topic="ionic bonding",
        education_level="gcse",
        confidence=Confidence.HIGH,
        relevant_passage="Ionic bonding is the electrostatic attraction between oppositely charged ions",
    )
    payload = evidence.as_fact_check_input()
    assert payload["claim"] == evidence.claim
    assert payload["sources"][0]["url"] == evidence.url
    assert payload["confidence"] == "HIGH"


def test_research_package_requires_traceable_claims():
    package = ResearchPackage(
        topic="photosynthesis",
        subject="biology",
        education_level="a-level",
        exam_board="",
        claims=[
            PackageClaim(
                claim="Photosynthesis converts light energy into chemical energy.",
                evidence="Light-dependent reactions produce ATP and reduced NADP.",
                sources=[
                    SourceRecord(
                        organisation="SYNTRA seed notes",
                        url="https://syntra.local/knowledge/photosynthesis",
                        source_tier=2,
                    )
                ],
            )
        ],
        research_method={
            "rag_used": True,
            "web_used": False,
            "fact_check_used": True,
            "freshness": "STABLE",
            "retrieval_mode": "RAG_ONLY",
        },
    )
    dumped = package.model_dump()
    assert dumped["exam_board"] == ""
    assert dumped["claims"][0]["sources"][0]["url"]
    assert dumped["research_method"]["fact_check_used"] is True


def test_fact_check_report_includes_supporting_and_contradictory_sources():
    report = FactCheckReport.model_validate(
        {
            "claims": [
                {
                    "claim": "Faraday's law relates induced emf to changing flux.",
                    "evidence": "Independent page states emf = -N dΦ/dt.",
                    "verification": "VERIFIED",
                    "confidence": "HIGH",
                    "supporting_sources": [
                        {
                            "organisation": "SYNTRA seed notes",
                            "url": "https://syntra.local/knowledge/electromagnetic-induction",
                        }
                    ],
                    "contradictory_sources": [],
                    "notes": "Classroom definition matches retrieved text.",
                }
            ]
        }
    )
    assert report.claims[0].verification is Verification.VERIFIED
    assert report.claims[0].supporting_sources[0].url
    assert report.claims[0].contradictory_sources == []
