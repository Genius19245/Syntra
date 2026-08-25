import asyncio
import inspect
from types import SimpleNamespace

from google.genai import types
from syntra_orchestrator.run import event_text, prepare_input, run_adk_agent


class _FakeSession:
    def __init__(self, session_id: str, state: dict | None):
        self.id = session_id
        self.state = dict(state or {})

    def to_dict(self):
        return dict(self.state)


class _FakeSessionService:
    def __init__(self):
        self.created = []

    async def create_session(self, **kwargs):
        session = _FakeSession(
            kwargs.get("session_id") or "session-1",
            kwargs.get("state"),
        )
        self.created.append({"kwargs": kwargs, "session": session})
        return session


class _FakeRunner:
    last = None

    def __init__(self, agent, *, app_name=None, **kwargs):
        self.agent = agent
        self.app_name = app_name
        self.session_service = _FakeSessionService()
        self.kwargs = kwargs
        _FakeRunner.last = self

    async def run_async(self, **kwargs):
        self.run_kwargs = kwargs
        part = SimpleNamespace(text=f"ok:{self.agent.name}")
        event = SimpleNamespace(
            content=SimpleNamespace(parts=[part], text=None),
            is_final_response=lambda: True,
        )
        yield event

    async def __aenter__(self):
        return self

    async def __aexit__(self, *args):
        return False


def test_prepare_input_keeps_research_package_out_of_the_prompt():
    package = {"topic": "magnets", "claims": ["x" * 50]}
    message, state = prepare_input(
        {
            "text": "Write the curriculum.",
            "research_package": package,
            "learner_profile": "# Learner Profile",
        }
    )
    assert state["research_package"] is package
    assert state["learner_profile"] == "# Learner Profile"
    prompt = message.parts[0].text
    assert prompt == "Write the curriculum."
    assert "claims" not in prompt


def test_prepare_input_string_has_no_session_state():
    message, state = prepare_input("A-Level Physics: magnets")
    assert state is None
    assert message.parts[0].text == "A-Level Physics: magnets"


def test_event_text_reads_parts():
    event = SimpleNamespace(
        content=SimpleNamespace(parts=[SimpleNamespace(text="hello")], text=None)
    )
    assert event_text(event) == "hello"


def test_run_adk_agent_drives_the_given_agent(monkeypatch):
    monkeypatch.setattr("syntra_orchestrator.run.InMemoryRunner", _FakeRunner)
    agent = SimpleNamespace(name="curriculum_agent")
    package = {"topic": "osmosis"}
    result = asyncio.run(
        run_adk_agent(
            agent,
            {"text": "Design the lesson.", "research_package": package},
            app_name="curriculum_agent",
        )
    )
    runner = _FakeRunner.last
    assert runner.agent is agent
    assert runner.app_name == "curriculum_agent"
    created = runner.session_service.created[0]
    assert created["kwargs"]["state"]["research_package"] is package
    message = runner.run_kwargs["new_message"]
    assert isinstance(message, types.Content)
    assert message.parts[0].text == "Design the lesson."
    assert result["text"] == "ok:curriculum_agent"
    assert result["state"]["research_package"] is package


def test_prepare_input_leftover_json_excludes_state_keys():
    package = {"topic": "magnets", "claims": ["huge-claim-body"]}
    message, state = prepare_input(
        {
            "research_package": package,
            "lesson_plan": {"lesson_sequence": [1, 2, 3]},
            "other": "keep-this",
        }
    )
    assert state["research_package"] is package
    assert state["lesson_plan"] == {"lesson_sequence": [1, 2, 3]}
    prompt = message.parts[0].text
    assert "keep-this" in prompt
    assert "huge-claim-body" not in prompt
    assert "lesson_sequence" not in prompt


def test_prepare_input_nested_state_keeps_package_identity():
    package = {"topic": "osmosis"}
    message, state = prepare_input(
        {
            "text": "Write objectives.",
            "state": {
                "research_package": package,
                "prerequisite_analysis": "# Gaps",
            },
        }
    )
    assert state["research_package"] is package
    assert state["prerequisite_analysis"] == "# Gaps"
    assert message.parts[0].text == "Write objectives."


def test_prepare_input_content_passthrough():
    content = types.Content(
        role="user",
        parts=[types.Part.from_text(text="Run the curriculum.")],
    )
    message, state = prepare_input(content, state={"learner_profile": "# Profile"})
    assert message is content
    assert state == {"learner_profile": "# Profile"}


def test_orchestrator_keeps_research_and_profile_parallel():
    from google.adk.agents.parallel_agent import ParallelAgent
    from google.adk.agents.sequential_agent import SequentialAgent
    from syntra_orchestrator.agent import research_and_profile, syntra_orchestrator

    assert isinstance(syntra_orchestrator, SequentialAgent)
    assert isinstance(research_and_profile, ParallelAgent)
    assert syntra_orchestrator.sub_agents[0] is research_and_profile
    assert [agent.name for agent in research_and_profile.sub_agents] == [
        "research_agent",
        "learner_profiler_agent",
    ]
    assert [agent.name for agent in syntra_orchestrator.sub_agents] == [
        "research_and_profile",
        "curriculum_agent",
    ]


def test_nested_runtime_does_not_flatten_parallel_impl():
    from google.adk.agents.parallel_agent import ParallelAgent
    from syntra_orchestrator.nested_agent_runtime import apply

    apply()
    source = inspect.getsource(ParallelAgent._run_async_impl)
    assert "_merge_agent_run" in source
    assert "for sub_agent in self.sub_agents" in source


def test_packages_export_run_agent():
    from curriculum_agent import run_agent as run_curriculum
    from curriculum_agent.lesson_planner_agent import run_agent as run_lesson
    from curriculum_agent.slide_agent import run_agent as run_slides
    from learning_objectives_agent import run_agent as run_objectives
    from research_agent import run_agent as run_research
    from syntra_orchestrator import run_agent as run_orchestrator

    for fn in (
        run_curriculum,
        run_lesson,
        run_slides,
        run_objectives,
        run_research,
        run_orchestrator,
    ):
        assert inspect.iscoroutinefunction(fn)
        assert fn.__name__ == "run_agent"
        params = list(inspect.signature(fn).parameters)
        assert params[0] == "input_data"
