from types import SimpleNamespace

from example_agent.agent import example_agent
from example_agent.tools import (
    check_example,
    choose_example_type,
    match_example_context,
    retrieve_example_context,
    select_example_type,
    validate_example,
)


def _package():
    return {
        "topic": "electromagnetic induction",
        "key_concepts": ["magnetic flux", "induced emf", "Faraday's law"],
        "misconceptions": ["A magnet sitting still on a coil still induces a current."],
        "claims": [
            {
                "claim": "Magnetic flux measures how much field passes through a surface.",
                "evidence": "GCSE notes define flux as BA for a uniform field.",
            },
            {
                "claim": "Faraday's law relates induced emf to changing flux.",
                "evidence": "emf = -N dΦ/dt.",
            },
            {
                "claim": "Photosynthesis converts light energy into chemical energy.",
                "evidence": "Unrelated biology claim.",
            },
        ],
    }


def test_example_agent_is_single_turn_local_tools():
    names = [
        getattr(tool, "__name__", getattr(tool, "name", None))
        for tool in example_agent.tools
    ]
    assert example_agent.name == "example_agent"
    assert example_agent.mode == "single_turn"
    assert example_agent.output_key == "example"
    assert names == [
        "select_example_type",
        "retrieve_example_context",
        "validate_example",
    ]
    instruction = example_agent.instruction
    assert "{research_package?}" in instruction
    assert "{learner_profile?}" in instruction
    assert "Do not pass" in instruction


def test_select_example_type_uses_education_band_not_exact_gcse():
    result = choose_example_type("Year 11 GCSE Combined Science")
    assert result["education_band"] == "gcse"
    assert result["example_type"] == "conceptual"
    assert result["allow_numbers"] is True


def test_select_example_type_promotes_maths_at_a_level_to_worked():
    result = choose_example_type("A-Level Physics", concept_type="mathematical")
    assert result["example_type"] == "worked"
    assert result["require_units"] is True


def test_select_example_type_blocks_numbers_at_primary():
    result = choose_example_type("Year 4 primary", concept_type="numerical")
    assert result["example_type"] == "conceptual"
    assert result["allow_numbers"] is False


def test_select_example_type_reads_learner_profile_from_state():
    context = SimpleNamespace(state={"learner_profile": {"level": "A-Level"}})
    result = select_example_type(concept_type="practical", tool_context=context)
    assert result["example_type"] == "exam_application"


def test_retrieve_example_context_is_compact_and_finds_equations():
    result = match_example_context("Faraday's law", research_package=_package())
    assert result["status"] == "success"
    assert result["context"] is None
    assert any("emf" in snippet.lower() for snippet in result["equations"])
    claims = [item["claim"] for item in result["claims"]]
    assert all("photosynthesis" not in claim.lower() for claim in claims)


def test_retrieve_example_context_requires_session_state():
    result = retrieve_example_context("flux")
    assert result["status"] == "error"
    assert "session state" in result["message"]


def test_validate_example_handles_empty_and_missing_concept():
    empty = validate_example(None, "flux")  # type: ignore[arg-type]
    assert empty["valid"] is False
    assert any("empty" in issue.lower() for issue in empty["issues"])
    missing = check_example(
        "A coil and a magnet can show induction in the lab.",
        "",
    )
    assert missing["valid"] is False


def test_validate_example_requires_analogy_limit_and_concept_mention():
    weak = check_example(
        "Flux is like water flowing through a pipe.",
        "magnetic flux",
        example_type="analogy",
    )
    assert weak["valid"] is False
    assert any("stops being accurate" in issue for issue in weak["issues"])
    ok = check_example(
        "Magnetic flux is like water through a pipe, but the analogy "
        "breaks down because flux does not literally flow.",
        "magnetic flux",
        example_type="analogy",
        research_package=_package(),
    )
    assert ok["valid"] is True
    assert ok["mentions_concept"] is True
