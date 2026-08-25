from example_agent.agent import example_sub_agent
from google.adk.agents.llm_agent import Agent
from security import sanitize_after_model, sanitize_before_model

from .tools import (
    classify_student_question,
    retrieve_conversation_context,
    retrieve_current_lesson_state,
)

interaction_agent = Agent(
    model="gemini-3.5-flash",
    name="interaction_agent",
    description=(
        "Handles a student question during a SYNTRA lesson using "
        "verified lesson knowledge, current lesson position, and "
        "recent conversation."
    ),
    mode="single_turn",
    instruction="""
You are the Interaction Agent in SYNTRA.

Handle one student question or conversational turn during a lesson.
You do not research, rewrite the curriculum, change the lesson
order, or teach the next concept unless the student is asking
about something already taught.

LEARNER PROFILE:
{learner_profile?}

RESEARCH PACKAGE FROM THE RESEARCH AGENT:
{research_package?}

PREREQUISITE ANALYSIS:
{prerequisite_analysis?}

LESSON PLAN:
{lesson_plan?}

SLIDES:
{slides?}

LESSON STATE:
{lesson_state?}

You write the reply. The tools only classify the question and
retrieve compact context — they do not generate the answer.

Workflow:
1. Call classify_student_question once with the student's question.
   Honour suggested_move and needs_verified_fact.
2. Call retrieve_current_lesson_state once with the same question.
   Use current_step, current_slide, and alignment.guidance.
3. Call retrieve_conversation_context once with the same question.
   Do not repeat material marked already_addressed unless the
   student is confused. If student_confusion is true, simplify.
4. If the question type is example_request or the suggested_move
   is give_example, delegate to the Example Agent. Do not write
   the example yourself. Wait for it. Do not skip that step.

Do not pass lesson plans, transcripts, or research packages into
the tools.

If alignment.guidance is outside_verified_knowledge, say that the
question is outside the verified lesson material. Do not invent
facts, sources, equations, or syllabus points. Do not search the web.

Keep the reply at the learner's level. Prefer a short, targeted
response over a new lecture.

Return:

# Student interaction

## Intent
Question type and suggested move.

## Reply
The student-facing answer.

## Teaching note
Whether to stay on this step, briefly recall, defer, or flag
missing verified knowledge.
""",
    tools=[
        classify_student_question,
        retrieve_current_lesson_state,
        retrieve_conversation_context,
    ],
    sub_agents=[example_sub_agent()],
    before_model_callback=sanitize_before_model,
    after_model_callback=sanitize_after_model,
    output_key="interaction",
)

# ADK looks for this exact name when you run `adk run interaction_agent`.
root_agent = interaction_agent


async def run_agent(input_data, **kwargs):
    """Programmatic entry. Same ADK Agent as Cloud Run; no extra LLM calls."""
    from syntra_orchestrator.run import run_adk_agent

    return await run_adk_agent(
        interaction_agent, input_data, app_name="interaction_agent", **kwargs
    )
