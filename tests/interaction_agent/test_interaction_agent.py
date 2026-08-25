from types import SimpleNamespace

from interaction_agent.agent import interaction_agent
from interaction_agent.tools import (
    classify_student_question,
    match_conversation_context,
    match_lesson_state,
    retrieve_conversation_context,
    retrieve_current_lesson_state,
)


def _plan():
    return {
        "lesson_sequence": [
            {
                "step": 1,
                "title": "Recall magnetic fields",
                "purpose": "Activate prior knowledge",
                "concepts": ["magnetic field"],
            },
            {
                "step": 2,
                "title": "Define magnetic flux",
                "purpose": "Introduce flux",
                "concepts": ["magnetic flux"],
            },
            {
                "step": 3,
                "title": "Faraday's law",
                "purpose": "Relate emf to changing flux",
                "concepts": ["Faraday's law", "induced emf"],
            },
        ]
    }


def _package():
    return {
        "topic": "electromagnetic induction",
        "key_concepts": ["magnetic flux", "induced emf", "Faraday's law"],
        "claims": [
            {"claim": "Magnetic flux measures how much field passes through a surface."}
        ],
    }


def test_interaction_agent_is_single_turn_local_tools():
    names = [
        getattr(tool, "__name__", getattr(tool, "name", None))
        for tool in interaction_agent.tools
    ]
    assert interaction_agent.name == "interaction_agent"
    assert interaction_agent.mode == "single_turn"
    assert interaction_agent.output_key == "interaction"
    assert names[:3] == [
        "classify_student_question",
        "retrieve_current_lesson_state",
        "retrieve_conversation_context",
    ]
    assert "example_agent" in names
    assert [agent.name for agent in interaction_agent.sub_agents] == ["example_agent"]
    instruction = interaction_agent.instruction
    assert "{research_package?}" in instruction
    assert "{lesson_plan?}" in instruction
    assert "{lesson_state?}" in instruction
    assert "Do not pass lesson plans" in instruction


def test_classify_does_not_treat_show_me_as_how():
    result = classify_student_question("Can you show me an example of flux?")
    assert result["type"] == "example_request"
    assert result["suggested_move"] == "give_example"
    assert "how" not in result["cues"]


def test_classify_difference_question_is_comparison_not_definition():
    result = classify_student_question("What is the difference between flux and field?")
    assert result["type"] == "comparison"
    assert result["needs_verified_fact"] is True


def test_classify_empty_question():
    result = classify_student_question("   ")
    assert result["type"] == "empty"
    assert result["suggested_move"] == "ask_student_to_restate"


def test_match_lesson_state_is_compact_and_aligns_question():
    result = match_lesson_state(
        question="What is magnetic flux?",
        lesson_state={"current_step": 2},
        lesson_plan=_plan(),
        research_package=_package(),
        learner_profile={"level": "GCSE"},
    )
    assert result["status"] == "success"
    assert result["current_step"]["title"] == "Define magnetic flux"
    assert result["completed_steps"] == 1
    assert result["remaining_steps"] == 1
    assert "lesson_sequence" not in result
    assert result["alignment"]["in_current_step"] is True
    assert result["alignment"]["guidance"] == "answer_here"
    assert result["education_level"] == "GCSE"


def test_match_lesson_state_flags_outside_verified_knowledge():
    result = match_lesson_state(
        question="What is osmosis?",
        lesson_state={"current_step": 1},
        lesson_plan=_plan(),
        research_package=_package(),
    )
    assert result["alignment"]["in_package"] is False
    assert result["alignment"]["guidance"] == "outside_verified_knowledge"


def test_retrieve_current_lesson_state_reads_session_not_full_plan():
    context = SimpleNamespace(
        state={
            "lesson_state": {"current_step": 1},
            "lesson_plan": _plan(),
            "research_package": _package(),
        }
    )
    result = retrieve_current_lesson_state(
        "What is Faraday's law?", tool_context=context
    )
    assert result["current_step"]["step"] == 1
    assert result["alignment"]["in_upcoming"] is True
    assert result["alignment"]["guidance"] == "preview_lightly_or_defer"


def test_retrieve_conversation_context_handles_missing_history():
    result = retrieve_conversation_context("What is flux?")
    assert result["status"] == "success"
    assert result["recent_interactions"] == []
    assert result["already_addressed"] is False


def test_match_conversation_skips_live_question_and_detects_repeat():
    result = match_conversation_context(
        question="What is flux?",
        conversation_history=[
            {
                "role": "teacher",
                "text": "Flux is how much field passes through a surface.",
            },
            {"role": "student", "text": "What is flux?"},
        ],
    )
    assert [item["role"] for item in result["recent_interactions"]] == ["teacher"]
    assert result["already_addressed"] is True
    assert result["repeated_question"] is False
