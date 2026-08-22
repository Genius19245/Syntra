from research_agent.rag.router import plan_retrieval_mode
from research_agent.rag.store import default_store
from research_agent.retrieval.authority import contextual_sort_key, source_tier
from research_agent.retrieval.queries import generate_research_queries
from research_agent.schema import Evidence
from research_agent.skills import SKILL_NAMES, load_research_skills

SCENARIOS = [
    {
        "id": "a_level_physics",
        "question": "Teach me electromagnetic induction.",
        "subject": "physics",
        "education_level": "A-Level",
        "exam_board": "",
        "expected_freshness": "STABLE",
        "expected_mode": "RAG_ONLY",
        "topic": "electromagnetic induction",
        "allowed_levels": {"a-level"},
        "forbidden_levels": {"gcse", "undergraduate"},
    },
    {
        "id": "a_level_biology",
        "question": "Explain photosynthesis.",
        "subject": "biology",
        "education_level": "A-Level",
        "exam_board": "",
        "expected_freshness": "STABLE",
        "expected_mode": "RAG_ONLY",
        "topic": "photosynthesis",
        "allowed_levels": {"a-level"},
        "forbidden_levels": {"gcse", "undergraduate"},
    },
    {
        "id": "gcse_chemistry",
        "question": "Explain ionic bonding.",
        "subject": "chemistry",
        "education_level": "GCSE",
        "exam_board": "",
        "expected_freshness": "STABLE",
        "expected_mode": "RAG_ONLY",
        "topic": "ionic bonding",
        "allowed_levels": {"gcse"},
        "forbidden_levels": {"undergraduate", "postgraduate"},
    },
    {
        "id": "university_cs",
        "question": "Explain operating system scheduling algorithms.",
        "subject": "computer science",
        "education_level": "university",
        "exam_board": "",
        "expected_freshness": "STABLE",
        "expected_mode": "RAG_ONLY",
        "topic": "operating system scheduling algorithms",
        "allowed_levels": {"undergraduate"},
        "forbidden_levels": {"gcse", "primary"},
    },
    {
        "id": "history_wwi",
        "question": "Explain the causes of the First World War.",
        "subject": "history",
        "education_level": "",
        "exam_board": "",
        "expected_freshness": "STABLE",
        "expected_mode": "RAG_ONLY",
        "topic": "causes of the First World War",
        "allowed_levels": {"intermediate", ""},
        "forbidden_levels": {"undergraduate"},
    },
    {
        "id": "time_sensitive_ai",
        "question": "What is the latest major development in AI?",
        "subject": "",
        "education_level": "",
        "exam_board": "",
        "expected_freshness": "TIME_SENSITIVE",
        "expected_mode": "WEB_ONLY",
        "topic": None,
        "allowed_levels": set(),
        "forbidden_levels": set(),
    },
]


def test_skills_load_with_adk_names():
    toolset = load_research_skills()
    assert toolset is not None
    assert len(SKILL_NAMES) == 5


def test_research_agent_keeps_fact_checker_gated_until_strict_mode():
    from research_agent.agent import FACT_CHECKER_ENABLED, fact_checker, research_agent

    assert FACT_CHECKER_ENABLED is False
    assert fact_checker.name == "fact_checker"
    names = [agent.name for agent in research_agent.sub_agents]
    assert names == ["source_researcher", "fact_checker"]
    assert research_agent.output_key == "research_package"


def test_six_domain_hybrid_routing_and_depth():
    store = default_store()
    for scenario in SCENARIOS:
        plan = plan_retrieval_mode(
            scenario["question"],
            education_level=scenario["education_level"],
            exam_board=scenario["exam_board"],
            subject=scenario["subject"],
            store=store,
        )
        assert plan["freshness"] == scenario["expected_freshness"], scenario["id"]
        assert plan["mode"] == scenario["expected_mode"], scenario["id"]

        queries = generate_research_queries(
            scenario["topic"] or scenario["question"],
            education_level=scenario["education_level"],
            exam_board=scenario["exam_board"],
            subject=scenario["subject"],
        )
        assert queries["query_count"] <= 6, scenario["id"]
        if not scenario["exam_board"]:
            joined = " ".join(item["query"] for item in queries["queries"]).lower()
            assert "aqa" not in joined, scenario["id"]

        if scenario["expected_mode"] == "WEB_ONLY":
            assert plan["web_needed"] is True
            continue

        hits = store.retrieve(
            scenario["question"],
            filters={
                "subject": scenario["subject"],
                "education_level": scenario["education_level"],
                "exam_board": scenario["exam_board"],
            },
        )
        assert hits, scenario["id"]
        levels = {str(hit["metadata"].get("education_level") or "") for hit in hits}
        assert levels.isdisjoint(scenario["forbidden_levels"]), scenario["id"]
        evidence = Evidence(
            claim=hits[0]["text"].split(".")[0],
            evidence=hits[0]["text"][:240],
            source=str(hits[0]["metadata"].get("source") or ""),
            url=str(hits[0]["metadata"].get("url") or ""),
            source_tier=int(hits[0]["metadata"].get("source_tier") or 4),
            topic=str(hits[0]["metadata"].get("topic") or ""),
            education_level=str(hits[0]["metadata"].get("education_level") or ""),
            relevant_passage=hits[0]["text"][:180],
        )
        assert evidence.url.startswith("http")
        assert evidence.source
        assert 1 <= evidence.source_tier <= 5


def test_source_quality_ranking_is_contextual():
    aqa = "https://www.aqa.org.uk/subjects/physics"
    nasa = "https://www.nasa.gov/sun"
    bitesize = "https://www.bbc.co.uk/bitesize/articles/ionic-bonding"
    assert contextual_sort_key(
        aqa, exam_board="AQA", question_intent="curriculum"
    ) < contextual_sort_key(nasa, exam_board="AQA", question_intent="curriculum")
    assert source_tier(nasa) < source_tier(bitesize)
