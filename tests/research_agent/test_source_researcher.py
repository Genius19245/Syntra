import asyncio
import inspect
import re
from types import SimpleNamespace

import pytest
from google.adk.agents.readonly_context import ReadonlyContext
from google.adk.utils.instructions_utils import inject_session_state
from research_agent.source_researcher.agent import source_researcher
from research_agent.source_researcher.tools import gather_sources


def _empty_session_context() -> ReadonlyContext:
    return ReadonlyContext(SimpleNamespace(session=SimpleNamespace(state={})))


def test_adk_treats_double_braces_as_required_session_keys():
    """Regression lock: ADK's regex treats {{topic}} as required `topic`."""
    ctx = _empty_session_context()
    with pytest.raises(KeyError, match="topic"):
        asyncio.run(inject_session_state("{{topic}} example", ctx))


def test_instruction_renders_when_session_has_no_topic():
    instruction = source_researcher.instruction
    assert "{{topic}}" not in instruction
    assert "{topic}" not in instruction
    assert "<topic>" in instruction
    rendered = asyncio.run(
        inject_session_state(instruction, _empty_session_context())
    )
    assert "gather_sources" in rendered
    assert "{topic}" not in rendered


def test_nested_research_nodes_render_without_session_topic():
    from research_agent.fact_checker.agent import fact_checker

    ctx = _empty_session_context()
    for agent in (source_researcher, fact_checker):
        instruction = agent.instruction
        assert isinstance(instruction, str)
        asyncio.run(inject_session_state(instruction, ctx))


def test_instruction_batches_gather_sources_in_one_turn():
    instruction = re.sub(r"\s+", " ", source_researcher.instruction.lower())
    assert "once per query, in order" not in instruction
    assert "in one turn" in instruction
    assert "single gather_sources call" in instruction


def test_gather_sources_keeps_single_query_signature(monkeypatch):
    from research_agent.source_researcher import tools

    calls: list[str] = []

    def fake_search(query: str) -> str:
        calls.append(query)
        slug = query.replace(" ", "-")
        return (
            f"1. {query}\n"
            f"   Organisation: example.org\n"
            f"   Source tier: 1\n"
            f"   URL: https://example.org/{slug}\n"
            f"   Snippet: snippet"
        )

    monkeypatch.setattr(tools, "search_web", fake_search)
    monkeypatch.setattr(
        tools, "fetch_page", lambda url: f"Title: page\nURL: {url}\n\nbody"
    )

    result = gather_sources("ionic bonding GCSE")
    assert calls == ["ionic bonding GCSE"]
    assert result.startswith("SEARCH RESULTS\n")
    assert "FETCHED PAGES" in result
    assert "https://example.org/ionic-bonding-GCSE" in result

    params = inspect.signature(gather_sources).parameters
    assert params["query"].annotation is str
    assert "queries" in params


def test_gather_sources_runs_query_list_in_one_call(monkeypatch):
    from research_agent.source_researcher import tools

    calls: list[str] = []

    def fake_search(query: str) -> str:
        calls.append(query)
        slug = query.replace(" ", "-")
        return (
            f"1. {query}\n"
            f"   Organisation: example.org\n"
            f"   Source tier: 1\n"
            f"   URL: https://example.org/{slug}\n"
            f"   Snippet: snippet"
        )

    monkeypatch.setattr(tools, "search_web", fake_search)
    monkeypatch.setattr(
        tools, "fetch_page", lambda url: f"Title: page\nURL: {url}\n\nbody"
    )

    result = gather_sources(
        query="ionic bonding GCSE",
        queries=["ionic bonding GCSE", "dot and cross diagrams GCSE"],
    )
    assert calls == ["ionic bonding GCSE", "dot and cross diagrams GCSE"]
    assert "QUERY: ionic bonding GCSE" in result
    assert "QUERY: dot and cross diagrams GCSE" in result
    assert "SEARCH RESULTS" in result
    assert "FETCHED PAGES" in result
    assert "https://example.org/ionic-bonding-GCSE" in result
    assert "https://example.org/dot-and-cross-diagrams-GCSE" in result


def test_gather_sources_skips_when_cache_already_covered():
    state = {"retrieval_mode": "RAG_ONLY"}
    result = gather_sources("ionic bonding GCSE", tool_context=state)
    assert "Skipped web research" in result
