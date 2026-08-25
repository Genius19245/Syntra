from types import SimpleNamespace

from adaptation_agent.agent import adaptation_agent
from adaptation_agent.tools import (
    decide_adaptation,
    identify_knowledge_gap,
    match_knowledge_gaps,
    recommend_adaptation,
    retrieve_learner_performance,
    summarise_performance,
)


def test_adaptation_agent_is_single_turn_local_tools():
    names = [
        getattr(tool, "__name__", getattr(tool, "name", None))
        for tool in adaptation_agent.tools
    ]
    assert adaptation_agent.name == "adaptation_agent"
    assert adaptation_agent.mode == "single_turn"
    assert adaptation_agent.output_key == "adaptation"
    assert names[:3] == [
        "retrieve_learner_performance",
        "identify_knowledge_gap",
        "recommend_adaptation",
    ]
    assert "example_agent" in names
    assert [agent.name for agent in adaptation_agent.sub_agents] == ["example_agent"]
    instruction = adaptation_agent.instruction
    assert "{prerequisite_analysis?}" in instruction
    assert "{lesson_state?}" in instruction
    assert "Do not pass a" in instruction
    assert "performance blob" in instruction


def test_identify_knowledge_gap_handles_missing_demonstrated_list():
    result = identify_knowledge_gap(
        required_concepts=["Flux", "EMF"],
        demonstrated_concepts=None,
    )
    assert result["missing_concepts"] == ["Flux", "EMF"]
    assert result["gap_count"] == 2
    assert result["mastered_concepts"] == []


def test_match_knowledge_gaps_parses_json_and_prerequisite_analysis():
    result = match_knowledge_gaps(
        required_concepts='["Flux", "EMF"]',
        demonstrated_concepts=["flux"],
        prerequisite_analysis={"missing": ["Right-hand rule"], "mastered": ["Flux"]},
    )
    assert result["mastered_concepts"] == ["Flux"]
    assert "EMF" in result["missing_concepts"]
    assert "Right-hand rule" in result["missing_concepts"]


def test_summarise_performance_is_compact_and_flags_confusion():
    result = summarise_performance(
        performance={"score": 2, "total": 10, "checks_failed": 2, "checks_passed": 0},
        conversation_history=[{"role": "student", "text": "I don't understand flux."}],
    )
    assert result["status"] == "success"
    assert result["score"] == 0.2
    assert result["confusion"] is True
    assert "low_score" in result["signals"]
    assert "performance" not in result
    assert result["checks_failed"] == 2


def test_retrieve_learner_performance_reads_session_state():
    context = SimpleNamespace(
        state={
            "performance": {"correct": 4, "total": 5},
            "interaction": {"student_confusion": False, "repeated_question": False},
        }
    )
    result = retrieve_learner_performance(tool_context=context)
    assert result["score"] == 0.8
    assert "high_score" in result["signals"]
    assert context.state["learner_performance"]["score"] == 0.8


def test_recommend_adaptation_infers_struggling_from_evidence():
    context = SimpleNamespace(
        state={
            "performance": {"score": 20, "max": 100, "last_check": "fail"},
            "lesson_state": {"current_step": 2},
            "conversation_history": "I'm confused",
        }
    )
    result = recommend_adaptation(tool_context=context)
    assert result["learner_state"] == "struggling"
    assert result["action"] in {"simplify", "slow_down", "provide_analogy"}
    assert result["stay_on_step"] is True
    assert result["increase_difficulty"] is False


def test_recommend_adaptation_missing_prerequisite_beats_stretch():
    result = decide_adaptation(
        learner_state="ready for increased difficulty",
        performance={"status": "success", "signals": ["high_score"], "score": 0.9},
        gaps={"missing_concepts": ["Magnetic field"], "gap_count": 1},
    )
    assert result["learner_state"] == "missing_prerequisite"
    assert result["action"] == "revisit_prerequisite"
    assert result["revisit_concepts"] == ["Magnetic field"]


def test_recommend_adaptation_unknown_asks_diagnostic():
    result = recommend_adaptation()
    assert result["learner_state"] == "unknown"
    assert result["action"] == "ask_diagnostic"
    assert result["stay_on_step"] is True


def test_recommend_adaptation_accepts_explicit_mastering():
    result = decide_adaptation(
        learner_state="mastering",
        performance={"status": "success", "signals": ["high_score"], "score": 0.95},
        gaps={"missing_concepts": [], "gap_count": 0},
    )
    assert result["action"] == "move_forward"
    assert result["stay_on_step"] is False
