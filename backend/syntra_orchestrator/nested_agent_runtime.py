"""Keep SequentialAgent nested specialists on ADK's node runtime.

ADK 2.7 runs a SequentialAgent root on the legacy ``run_async`` path, which
never installs ``InvocationContext._event_queue``. Nested ``mode="single_turn"``
sub-agents are wrapped as tools that call ``ctx.run_node()``, and that path
requires the queue.

This module does two things without changing the agent tree:

1. Send SequentialAgent / ParallelAgent *roots* through
   ``Runner._run_node_async`` so the queue exists and is consumed.
   Nested ParallelAgent children still run via ADK's TaskGroup merger
   in ``ParallelAgent._run_async_impl`` — do not flatten them here.
2. Copy ``_event_queue`` across context copies, matching ADK's own
   ``prepare_llm_agent_context`` helper.
"""

from __future__ import annotations

from collections.abc import AsyncGenerator
from contextlib import aclosing

from google.adk.agents.base_agent import BaseAgent
from google.adk.agents.context import Context
from google.adk.agents.invocation_context import InvocationContext
from google.adk.agents.parallel_agent import ParallelAgent
from google.adk.agents.sequential_agent import SequentialAgent
from google.adk.events.event import Event
from google.adk.runners import Runner

_original_run_async = Runner.run_async
_original_create_invocation_context = BaseAgent._create_invocation_context
_original_get_invocation_context = Context.get_invocation_context
_original_model_copy = InvocationContext.model_copy


def _copy_event_queue(
    source: InvocationContext, dest: InvocationContext
) -> InvocationContext:
    if dest is source or getattr(dest, "_event_queue", None) is getattr(
        source, "_event_queue", None
    ):
        return dest
    dest._event_queue = source._event_queue
    return dest


def _create_invocation_context(
    self: BaseAgent, parent_context: InvocationContext
) -> InvocationContext:
    invocation_context = _original_create_invocation_context(self, parent_context)
    return _copy_event_queue(parent_context, invocation_context)


def _get_invocation_context(self: Context) -> InvocationContext:
    copied = _original_get_invocation_context(self)
    return _copy_event_queue(self._invocation_context, copied)


def _model_copy(self: InvocationContext, *args, **kwargs) -> InvocationContext:
    copied = _original_model_copy(self, *args, **kwargs)
    queue = getattr(self, "_event_queue", None)
    if queue is not None:
        copied._event_queue = queue
    return copied


async def _run_async(self: Runner, **kwargs) -> AsyncGenerator[Event, None]:
    agen = (
        self._run_node_async(**kwargs)
        if isinstance(self.agent, (SequentialAgent, ParallelAgent))
        else _original_run_async(self, **kwargs)
    )
    async with aclosing(agen) as stream:
        async for event in stream:
            yield event


def apply() -> None:
    """Install the SequentialAgent nested-runtime workaround."""
    from observability import setup_telemetry

    setup_telemetry()
    if getattr(Runner.run_async, "_syntra_nested_runtime", False):
        return

    _run_async._syntra_nested_runtime = True  # type: ignore[attr-defined]
    Runner.run_async = _run_async
    BaseAgent._create_invocation_context = _create_invocation_context
    Context.get_invocation_context = _get_invocation_context
    InvocationContext.model_copy = _model_copy


apply()
