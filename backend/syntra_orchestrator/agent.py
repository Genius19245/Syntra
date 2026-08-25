import warnings

warnings.filterwarnings("ignore", message=r"\[EXPERIMENTAL\]", category=UserWarning)
warnings.filterwarnings(
    "ignore",
    message=r"SequentialAgent is deprecated",
    category=DeprecationWarning,
)
warnings.filterwarnings(
    "ignore",
    message=r"ParallelAgent is deprecated",
    category=DeprecationWarning,
)

from google.adk.agents.parallel_agent import ParallelAgent
from google.adk.agents.sequential_agent import SequentialAgent

from . import nested_agent_runtime as _nested_agent_runtime

_nested_agent_runtime.apply()

from curriculum_agent.agent import curriculum_agent
from curriculum_agent.learner_profiler.agent import learner_profiler_agent
from research_agent.agent import research_agent

research_and_profile = ParallelAgent(
    name="research_and_profile",
    description=("Researches the topic and profiles the learner at the same time."),
    sub_agents=[
        research_agent,
        learner_profiler_agent,
    ],
)

syntra_orchestrator = SequentialAgent(
    name="syntra_orchestrator",
    description=(
        "Coordinates SYNTRA by researching and profiling in parallel, "
        "then passing both results to the Curriculum Agent."
    ),
    sub_agents=[
        research_and_profile,
        curriculum_agent,
    ],
)

# ADK looks for this exact name when you run `adk run syntra_orchestrator`.
root_agent = syntra_orchestrator
