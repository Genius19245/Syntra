from types import SimpleNamespace

from adaptation_agent.agent import adaptation_agent
from example_agent.agent import example_agent
from example_agent.tools import choose_example_type, select_example_type
from explanation_agent.agent import explanation_agent
from interaction_agent.agent import interaction_agent
from teacher_agent.agent import teacher_agent


def test_teacher_graph_matches_specialist_then_example():
    names = [agent.name for agent in teacher_agent.sub_agents]
    assert names == [
        "explanation_agent",
        "interaction_agent",
        "adaptation_agent",
    ]
    assert "example_agent" not in names
    for specialist in teacher_agent.sub_agents:
        child_names = [agent.name for agent in specialist.sub_agents]
        assert child_names == ["example_agent"]
        assert specialist.sub_agents[0] is not example_agent
        assert specialist.sub_agents[0].output_key == "example"
    assert explanation_agent.parent_agent is teacher_agent
    assert interaction_agent.parent_agent is teacher_agent
    assert adaptation_agent.parent_agent is teacher_agent
    assert example_agent.parent_agent is None


def test_teacher_reads_upstream_state_and_forbids_calling_example():
    instruction = teacher_agent.instruction
    for key in (
        "{learner_profile?}",
        "{research_package?}",
        "{lesson_plan?}",
        "{slides?}",
        "{explanation?}",
        "{interaction?}",
        "{adaptation?}",
        "{example?}",
    ):
        assert key in instruction
    assert "Do not call the Example Agent" in instruction
    assert teacher_agent.name == "teacher_agent"
    assert teacher_agent.before_model_callback is not None
    assert teacher_agent.after_model_callback is not None


def test_example_agent_reads_specialist_outputs():
    instruction = example_agent.instruction
    assert "{explanation?}" in instruction
    assert "{interaction?}" in instruction
    assert "{adaptation?}" in instruction
    assert "AFTER Explanation, Interaction, or Adaptation" in instruction


def test_select_example_type_honours_adaptation_action_from_state():
    context = SimpleNamespace(
        state={
            "learner_profile": {"level": "GCSE"},
            "adaptation": {"action": "provide_analogy"},
        }
    )
    result = select_example_type(tool_context=context)
    assert result["example_type"] == "analogy"
    assert result["require_analogy_limit"] is True


def test_choose_example_type_honours_interaction_example_request():
    result = choose_example_type(
        learner_level="GCSE",
        interaction={"type": "example_request", "suggested_move": "give_example"},
    )
    assert result["example_type"] == "conceptual"
