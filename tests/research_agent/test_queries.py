from research_agent.retrieval.queries import (
    build_research_queries,
    dedupe_queries,
    generate_research_queries,
    normalize_query,
)
from research_agent.retrieval.session import remember_query, remember_url, seen_queries, seen_urls


def test_normalize_and_dedupe_queries():
    queries = [
        "Ionic bonding GCSE",
        "ionic bonding gcse",
        "Ionic bonding   GCSE",
        "Photosynthesis A-Level",
    ]
    unique = dedupe_queries(queries)
    assert unique == ["Ionic bonding GCSE", "Photosynthesis A-Level"]
    assert normalize_query("Ionic bonding   GCSE!") == "ionic bonding gcse"


def test_generate_queries_are_few_and_targeted():
    result = generate_research_queries(
        topic="photosynthesis",
        education_level="A-Level",
        exam_board="",
        subject="biology",
    )
    assert result["success"] is True
    assert 1 <= result["query_count"] <= 6
    queries = [item["query"].lower() for item in result["queries"]]
    assert any("photosynthesis" in query for query in queries)
    assert all("aqa" not in query and "edexcel" not in query for query in queries)


def test_named_exam_board_appears_only_when_specified():
    with_board = generate_research_queries(
        "electromagnetic induction",
        education_level="A-Level",
        exam_board="AQA",
        subject="physics",
    )
    joined = " ".join(item["query"] for item in with_board["queries"]).lower()
    assert "aqa" in joined


def test_session_skips_duplicate_queries_and_urls():
    state = {}
    assert remember_query(state, "ionic bonding GCSE") is True
    assert remember_query(state, "ionic bonding GCSE") is False
    assert seen_queries(state) == ["ionic bonding GCSE"]
    assert remember_url(state, "https://example.org/a") is True
    assert remember_url(state, "https://example.org/a") is False
    assert seen_urls(state) == ["https://example.org/a"]


def test_build_research_queries_respects_max():
    items = build_research_queries(
        "operating system scheduling",
        education_level="undergraduate",
        subject="computer science",
        max_queries=2,
    )
    assert len(items) <= 2
