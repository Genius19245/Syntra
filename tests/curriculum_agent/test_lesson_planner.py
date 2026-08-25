from curriculum_agent.agent import curriculum_agent
from curriculum_agent.lesson_planner_agent.agent import lesson_planner_agent
from curriculum_agent.tools import instruction_template


def test_lesson_planner_runs_after_learning_objectives():
    names = [agent.name for agent in curriculum_agent.sub_agents]
    assert names == [
        "prerequisite_agent",
        "learning_objectives_agent",
        "lesson_planner_agent",
        "slide_agent",
    ]
    assert (
        names.index("lesson_planner_agent")
        == names.index("learning_objectives_agent") + 1
    )


def test_lesson_planner_reads_profile_and_objectives_from_state():
    instruction = instruction_template(lesson_planner_agent)
    assert "{learner_profile?}" in instruction
    assert "{learning_objectives?}" in instruction
    assert lesson_planner_agent.output_key == "lesson_plan"
    assert "lesson_sequence" in instruction
    assert not getattr(lesson_planner_agent, "tools", None)
    assert getattr(lesson_planner_agent, "mode", None) in {"single_turn", None} or str(
        lesson_planner_agent.mode
    ).endswith("single_turn")
