from types import SimpleNamespace

from curriculum_agent.agent import curriculum_agent
from curriculum_agent.lesson_planner_agent.agent import lesson_planner_agent
from curriculum_agent.prerequisite_agent.agent import prerequisite_agent
from curriculum_agent.slide_agent.agent import slide_agent
from curriculum_agent.tools import (
    MAX_CONTENT_PART_CHARS,
    MAX_CONTENTS_CHARS,
    MAX_PROMPT_FIELD_CHARS,
    MAX_RESEARCH_BRIEF_CHARS,
    compact_curriculum_llm_request,
    compact_research_for_prompt,
    ensure_research_brief,
    instruction_template,
    render_compact_instruction,
)
from google.genai import types
from learning_objectives_agent.agent import learning_objectives_agent
from security import sanitize_after_model, sanitize_before_model


def _huge_package() -> dict:
    return {
        "topic": "Forces",
        "subject": "Science",
        "education_level": "GCSE",
        "exam_board": "AQA",
        "research_method": {
            "rag_used": True,
            "web_used": False,
            "retrieval_mode": "RAG_ONLY",
        },
        "key_concepts": [f"concept-{i} " + ("mass " * 80) for i in range(80)],
        "claims": [
            {
                "claim": f"Claim {i}: " + ("force is a push or pull. " * 200),
                "evidence": "page dump " * 5000,
                "sources": [{"url": "https://example.com/" + ("x" * 400)}],
                "verification": {"verdict": "VERIFIED"},
            }
            for i in range(200)
        ],
        "misconceptions": ["Force is needed to keep moving."] * 40,
        "uncertainties": ["Exact friction model at GCSE."] * 20,
    }


def test_compact_research_for_prompt_is_bounded_for_huge_package():
    brief = compact_research_for_prompt(_huge_package())
    assert len(brief) <= MAX_RESEARCH_BRIEF_CHARS
    assert "Forces" in brief
    assert "page dump" not in brief
    assert brief.count("Claim") <= 12
    assert "{" not in brief
    assert "}" not in brief


def test_render_instruction_does_not_grow_with_research_package():
    template = instruction_template(curriculum_agent)
    assert "{research_package?}" not in template
    assert "{research_brief?}" in template
    huge = "verified extract " * 200_000
    rendered = render_compact_instruction(
        template,
        {
            "research_package": huge,
            "learner_profile": "GCSE Science",
            "prerequisite_analysis": "Need mass and acceleration. " * 20_000,
            "learning_objectives": "Explain resultant force. " * 20_000,
            "lesson_plan": '{"lesson_sequence": ['
            + ('{"title": "x"},' * 50_000)
            + "]}",
        },
    )
    assert huge not in rendered
    assert len(rendered) <= len(template) + MAX_RESEARCH_BRIEF_CHARS + (
        4 * MAX_PROMPT_FIELD_CHARS
    )
    assert len(rendered) < 100_000


def test_nested_curriculum_agents_use_research_brief_not_package():
    for agent in (
        curriculum_agent,
        prerequisite_agent,
        learning_objectives_agent,
        lesson_planner_agent,
        slide_agent,
    ):
        template = instruction_template(agent)
        assert "{research_package?}" not in template, agent.name
        assert "{research_brief?}" in template, agent.name
        callbacks = agent.before_model_callback
        if not isinstance(callbacks, list):
            callbacks = [callbacks]
        assert compact_curriculum_llm_request in callbacks
        assert sanitize_before_model in callbacks
        assert agent.after_model_callback is sanitize_after_model


def test_ensure_research_brief_leaves_full_package_in_state():
    package = _huge_package()
    state = {"research_package": package}
    ensure_research_brief(SimpleNamespace(state=state))
    assert state["research_package"] is package
    assert len(state["research_brief"]) <= MAX_RESEARCH_BRIEF_CHARS
    assert "Forces" in state["research_brief"]


def test_before_model_callback_truncates_research_history():
    dump = (
        '{"topic": "Forces", "research_method": {"rag_used": true},'
        ' "claims": [{"claim": "' + ("N " * 80_000) + '"}]}'
    )
    history = f"[research_agent] said: {dump}"
    assert len(history) > MAX_CONTENT_PART_CHARS
    request = SimpleNamespace(
        config=SimpleNamespace(system_instruction=None),
        contents=[
            types.Content(
                role="user",
                parts=[types.Part(text=history)],
            ),
            types.Content(
                role="user",
                parts=[types.Part(text="x" * (MAX_CONTENTS_CHARS + 50))],
            ),
        ],
    )
    compact_curriculum_llm_request(None, request)
    first = request.contents[0].parts[0].text
    second = request.contents[1].parts[0].text
    assert len(first) <= MAX_CONTENT_PART_CHARS
    assert "Forces" in first or "RESEARCH BRIEF" in first
    assert len(second) <= MAX_CONTENT_PART_CHARS
    assert len(first) + len(second) <= MAX_CONTENTS_CHARS
