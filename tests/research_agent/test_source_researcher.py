import inspect
import re

from research_agent.source_researcher.agent import source_researcher
from research_agent.source_researcher.tools import gather_sources


def test_instruction_escapes_adk_template_braces():
    instruction = source_researcher.instruction
    assert "{{topic}}" in instruction
    assert "{{level}}" in instruction
    unescaped = re.findall(r"(?<!\{)\{([^{}]+)\}(?!\})", instruction)
    assert "topic" not in unescaped
    assert "level" not in unescaped


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
