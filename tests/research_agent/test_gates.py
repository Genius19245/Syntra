from research_agent.rag.gates import gate_research_tools
from research_agent.retrieval.session import (
    capture_strict_from_text,
    remember_evidence,
    set_cache_exact,
    set_retrieval_mode,
    user_text,
    web_blocked,
)


class _Tool:
    def __init__(self, name: str):
        self.name = name


def test_web_blocked_for_rag_only_and_exact_hit():
    state: dict = {}
    set_retrieval_mode(state, "HYBRID")
    assert web_blocked(state) is False
    set_retrieval_mode(state, "RAG_ONLY")
    assert web_blocked(state) is True
    hybrid: dict = {}
    set_retrieval_mode(hybrid, "HYBRID")
    set_cache_exact(hybrid, True)
    assert web_blocked(hybrid) is True


def test_gate_skips_gather_sources_on_rag_only():
    state: dict = {}
    set_retrieval_mode(state, "RAG_ONLY")
    result = gate_research_tools(_Tool("gather_sources"), {"query": "magnets"}, state)
    assert result["skipped"] is True
    assert "cache" in result["reason"].lower() or "RAG_ONLY" in result["reason"]


def test_gate_skips_source_researcher_transfer_on_exact_hit():
    state: dict = {}
    set_cache_exact(state, True)
    result = gate_research_tools(
        _Tool("transfer_to_agent"),
        {"agent_name": "source_researcher"},
        state,
    )
    assert result["skipped"] is True


def test_gate_skips_further_web_when_three_claims_covered():
    state: dict = {}
    set_retrieval_mode(state, "HYBRID")
    for index in range(3):
        remember_evidence(state, {"claim": f"claim {index}"})
    result = gate_research_tools(_Tool("search_web"), {"query": "magnets"}, state)
    assert result["skipped"] is True
    assert "three" in result["reason"].lower()


def test_gate_blocks_fact_checker_unless_strict():
    state: dict = {}
    blocked = gate_research_tools(
        _Tool("transfer_to_agent"),
        {"agent_name": "fact_checker"},
        state,
    )
    assert blocked["skipped"] is True
    capture_strict_from_text(state, "Strict verification: yes")
    allowed = gate_research_tools(
        _Tool("transfer_to_agent"),
        {"agent_name": "fact_checker"},
        state,
    )
    assert allowed is None


def test_capture_strict_ignores_empty_text():
    state: dict = {}
    capture_strict_from_text(state, "Strict verification: yes")
    capture_strict_from_text(state, "")
    assert state["strict_mode"] is True


def test_user_text_reads_message_parts():
    context = type(
        "Ctx",
        (),
        {
            "user_content": type(
                "Content",
                (),
                {"parts": [{"text": "Strict verification: yes"}]},
            )(),
            "session": None,
        },
    )()
    assert user_text(context) == "Strict verification: yes"
    assert user_text(None) == ""


def test_user_text_caches_on_session_state():
    events = [
        type(
            "Event",
            (),
            {"content": {"text": "Teach magnets. Strict verification: yes"}},
        )()
    ]
    session = type("Session", (), {"events": events})()
    context = type("Ctx", (), {"state": {}, "session": session, "user_content": None})()
    assert user_text(context) == "Teach magnets. Strict verification: yes"
    session.events = []
    assert user_text(context) == "Teach magnets. Strict verification: yes"
