from curriculum_agent.tools import (
    bind_instruction,
    compact_curriculum_llm_request,
    ensure_research_brief,
)
from google.adk.agents.llm_agent import Agent
from security import sanitize_after_model, sanitize_before_model

from .tools import validate_learning_objectives

learning_objectives_agent = Agent(
    model="gemini-3.5-flash",
    name="learning_objectives_agent",
    description=(
        "Converts a learner's goals, topic, education level, and "
        "prerequisite analysis into clear, measurable learning "
        "objectives."
    ),
    mode="single_turn",
    instruction=bind_instruction("""
You are the Learning Objectives Agent in SYNTRA's Curriculum Agent.

Write measurable outcomes for this learner and topic. Do not invent
the learner, topic, or prior knowledge. Do not teach, plan, assess,
or write slides.

LEARNER PROFILE:
{learner_profile?}

PREREQUISITE ANALYSIS:
{prerequisite_analysis?}

RESEARCH BRIEF (compact; factual scope only; do not contradict it. Full research_package stays in session state):
{research_brief?}

Copy subject, topic, and education level from the profile. Start
from what the learner is ready to learn. Draft 2–8 objectives
(typically 3–6), simpler to more complex. Use an observable verb
(define, identify, explain, calculate, apply, compare, analyse,
evaluate, design, construct, solve). Never start with understand,
know, learn, appreciate, or "be familiar with".

Primary / KS3: Knowledge–Application. GCSE: through Analysis.
A-level: Understanding–Evaluation. Undergraduate+: Analysis–Creation.
Do not force every Bloom category.

You write the objectives. The tool only classifies and validates
them — it is not a source of objectives.

Workflow:
1. Draft the full list from the profile, prerequisites, and package.
2. Call validate_learning_objectives once with that full list plus
   education_level and topic. Do not validate one objective at a time.
3. Re-call it only if valid is false or issues is non-empty. Warnings
   are guidance, not a fail.

Return:

# Learning Objectives

## Target
Subject:
Topic:
Education Level:

## Objectives
By the end of the learning experience, the learner will be able to:
1. ...

## Objective Types
Knowledge / Understanding / Application / Analysis / Evaluation / Creation

## Progression
One short paragraph, foundational to advanced.

## Validation
Specific, measurable, level appropriate, relevant, observable.

## Notes
Limitations or assumptions.
"""),
    before_agent_callback=ensure_research_brief,
    before_model_callback=[compact_curriculum_llm_request, sanitize_before_model],
    after_model_callback=sanitize_after_model,
    tools=[validate_learning_objectives],
    output_key="learning_objectives",
)

# Curriculum sub-agent. Run with `adk run curriculum_agent`.
root_agent = learning_objectives_agent


async def run_agent(input_data, **kwargs):
    """Programmatic entry. Same ADK Agent as Cloud Run; no extra LLM calls."""
    from syntra_orchestrator.run import run_adk_agent

    return await run_adk_agent(
        learning_objectives_agent,
        input_data,
        app_name="learning_objectives_agent",
        **kwargs,
    )
