"""Programmatic entry for SYNTRA ADK agents.

Cloud Run still serves ``root_agent`` via ``adk api_server``. This module
drives the same ``Agent`` objects through ADK's ``InMemoryRunner`` — it does
not add Gemini round-trips, wrap tools, or copy large research packages into
the user message when they already belong in session state.

Logging and research security stay on the ADK boundary
(``before_tool_callback`` / ``gate_research_tools``), not in RAG, slide, or
lesson-planner helpers.
"""

from __future__ import annotations

import json
from types import SimpleNamespace
from typing import Any

from google.adk.agents.base_agent import BaseAgent
from google.adk.runners import InMemoryRunner
from google.genai import types
from observability import get_tracer, setup_telemetry

from . import nested_agent_runtime as _nested_agent_runtime

_nested_agent_runtime.apply()

# Keys the hosted graph already reads from session state via {key?} templates.
_STATE_KEYS = frozenset(
    {
        "state",
        "learner_profile",
        "research_package",
        "research_brief",
        "prerequisite_analysis",
        "learning_objectives",
        "lesson_plan",
        "slides",
        "curriculum_plan",
        "explanation",
        "lesson_state",
        "conversation_history",
        "interaction",
        "performance",
        "learner_performance",
        "knowledge_gaps",
        "adaptation",
        "example",
    }
)


def prepare_input(
    input_data: Any,
    state: dict[str, Any] | None = None,
) -> tuple[types.Content, dict[str, Any] | None]:
    """Split a run payload into one user message plus session state.

    Large packages passed as known state keys stay in state only. They are
    not JSON-dumped into the prompt.
    """

    extra: dict[str, Any] = {}
    if state:
        extra.update(state)

    if isinstance(input_data, types.Content):
        return input_data, extra or None

    if isinstance(input_data, dict):
        nested = input_data.get("state")
        if isinstance(nested, dict):
            extra.update(nested)
        for key, value in input_data.items():
            if key in _STATE_KEYS and key != "state":
                extra[key] = value
        text = (
            input_data.get("text")
            or input_data.get("message")
            or input_data.get("prompt")
        )
        if text is None:
            leftover = {
                key: value
                for key, value in input_data.items()
                if key not in _STATE_KEYS and key not in {"text", "message", "prompt"}
            }
            text = json.dumps(leftover, ensure_ascii=False) if leftover else ""
        return _user_content(str(text)), extra or None

    return _user_content(str(input_data)), extra or None


def event_text(event: Any) -> str:
    content = getattr(event, "content", None)
    if content is None:
        return ""
    text = getattr(content, "text", None)
    if text:
        return text if isinstance(text, str) else str(text)
    parts = getattr(content, "parts", None)
    if not parts:
        return ""
    if len(parts) == 1:
        piece = getattr(parts[0], "text", None)
        if not piece:
            return ""
        return piece if isinstance(piece, str) else str(piece)
    chunks: list[str] = []
    for part in parts:
        piece = getattr(part, "text", None)
        if piece:
            chunks.append(piece if isinstance(piece, str) else str(piece))
    return "".join(chunks)


def _user_content(text: str) -> types.Content:
    body = text.strip() or "Run the agent."
    return types.Content(role="user", parts=[types.Part.from_text(text=body)])


def _session_state(session: Any) -> dict[str, Any]:
    raw = getattr(session, "state", None)
    if raw is None:
        return {}
    to_dict = getattr(raw, "to_dict", None)
    if callable(to_dict):
        return to_dict()
    if isinstance(raw, dict):
        return raw
    return {}


def _prompt_length(message: types.Content) -> int:
    return len(event_text(SimpleNamespace(content=message)))


async def run_adk_agent(
    agent: BaseAgent,
    input_data: Any,
    *,
    app_name: str | None = None,
    user_id: str = "user",
    session_id: str | None = None,
    state: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Run an existing ADK ``Agent`` once. No extra model calls."""

    setup_telemetry()
    message, initial_state = prepare_input(input_data, state)
    name = app_name or getattr(agent, "name", None) or "syntra"
    with get_tracer("syntra").start_as_current_span("syntra.run") as span:
        span.set_attribute("syntra.app", name)
        span.set_attribute("prompt.length", _prompt_length(message))
        async with InMemoryRunner(agent=agent, app_name=name) as runner:
            session = await runner.session_service.create_session(
                app_name=runner.app_name,
                user_id=user_id,
                session_id=session_id,
                state=initial_state,
            )
            text = ""
            async for event in runner.run_async(
                user_id=user_id,
                session_id=session.id,
                new_message=message,
            ):
                is_final = getattr(event, "is_final_response", None)
                final = callable(is_final) and is_final()
                if not final and text:
                    continue
                chunk = event_text(event)
                if chunk:
                    text = chunk
            return {
                "text": text,
                "state": _session_state(session),
                "session_id": session.id,
                "user_id": user_id,
            }


async def run_agent(input_data: Any, **kwargs: Any) -> dict[str, Any]:
    """Programmatic entry for the hosted SYNTRA orchestrator."""

    from .agent import root_agent

    return await run_adk_agent(
        root_agent,
        input_data,
        app_name="syntra_orchestrator",
        **kwargs,
    )
