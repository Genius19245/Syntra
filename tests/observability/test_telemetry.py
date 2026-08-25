import os
from types import SimpleNamespace

from google.genai import types
from observability import (
    apply_privacy_env,
    reset_for_tests,
    resolve_exporter,
    setup_telemetry,
)
from opentelemetry import trace
from opentelemetry.trace import ProxyTracerProvider


def test_privacy_env_blocks_message_content():
    apply_privacy_env()
    assert os.environ["ADK_CAPTURE_MESSAGE_CONTENT_IN_SPANS"] == "false"
    assert (
        os.environ["OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT"] == "NO_CONTENT"
    )


def test_resolve_exporter_off_and_cloud_run(monkeypatch):
    monkeypatch.setenv("SYNTRA_OTEL_EXPORTER", "off")
    assert resolve_exporter() == "off"
    monkeypatch.delenv("SYNTRA_OTEL_EXPORTER", raising=False)
    monkeypatch.setenv("K_SERVICE", "syntra-orchestrator")
    assert resolve_exporter() == "gcp"
    monkeypatch.delenv("K_SERVICE", raising=False)
    monkeypatch.setenv("SYNTRA_OTEL_EXPORTER", "console")
    assert resolve_exporter() == "console"


def test_setup_off_does_not_install_a_provider(monkeypatch):
    monkeypatch.setenv("SYNTRA_OTEL_EXPORTER", "off")
    reset_for_tests()
    setup_telemetry()
    assert isinstance(trace.get_tracer_provider(), ProxyTracerProvider)


def test_setup_does_not_replace_an_existing_provider(monkeypatch):
    monkeypatch.setenv("SYNTRA_OTEL_EXPORTER", "console")
    reset_for_tests()
    sentinel = object()
    monkeypatch.setattr(trace, "get_tracer_provider", lambda: sentinel)
    monkeypatch.setattr(
        "observability._provider_already_set",
        lambda: True,
    )
    called = {"set": False}
    monkeypatch.setattr(
        trace,
        "set_tracer_provider",
        lambda *_args, **_kwargs: called.__setitem__("set", True),
    )
    setup_telemetry()
    assert called["set"] is False


def test_run_adk_agent_records_safe_span_attrs(monkeypatch):
    import asyncio

    from syntra_orchestrator.run import run_adk_agent

    class _FakeSession:
        def __init__(self, session_id, state):
            self.id = session_id
            self.state = dict(state or {})

    class _FakeSessionService:
        async def create_session(self, **kwargs):
            return _FakeSession(
                kwargs.get("session_id") or "session-1",
                kwargs.get("state"),
            )

    class _FakeRunner:
        def __init__(self, agent, *, app_name=None, **kwargs):
            self.agent = agent
            self.app_name = app_name
            self.session_service = _FakeSessionService()

        async def run_async(self, **kwargs):
            part = SimpleNamespace(text="ok")
            yield SimpleNamespace(
                content=SimpleNamespace(parts=[part], text=None),
                is_final_response=lambda: True,
            )

        async def __aenter__(self):
            return self

        async def __aexit__(self, *args):
            return False

    captured = {}

    class _Span:
        def set_attribute(self, key, value):
            captured[key] = value

        def __enter__(self):
            return self

        def __exit__(self, *args):
            return False

    class _Tracer:
        def start_as_current_span(self, name):
            captured["span"] = name
            return _Span()

    monkeypatch.setattr("syntra_orchestrator.run.InMemoryRunner", _FakeRunner)
    monkeypatch.setattr("syntra_orchestrator.run.get_tracer", lambda _name: _Tracer())
    result = asyncio.run(
        run_adk_agent(
            SimpleNamespace(name="curriculum_agent"),
            {"text": "Write the curriculum.", "research_package": {"topic": "x"}},
            app_name="curriculum_agent",
        )
    )
    assert result["text"] == "ok"
    assert captured["span"] == "syntra.run"
    assert captured["syntra.app"] == "curriculum_agent"
    assert captured["prompt.length"] == len("Write the curriculum.")
    assert "Write the curriculum." not in captured
    assert "research_package" not in captured


def test_user_content_is_not_copied_onto_spans():
    message = types.Content(
        role="user",
        parts=[types.Part.from_text(text="secret student question")],
    )
    from syntra_orchestrator.run import _prompt_length

    assert _prompt_length(message) == len("secret student question")
