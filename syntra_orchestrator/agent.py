import warnings

warnings.filterwarnings("ignore", message=r"\[EXPERIMENTAL\]", category=UserWarning)
warnings.filterwarnings(
    "ignore",
    message=r"SequentialAgent is deprecated",
    category=DeprecationWarning,
)

from google.adk.agents.sequential_agent import SequentialAgent

from . import nested_agent_runtime as _nested_agent_runtime

_nested_agent_runtime.apply()

from curriculum_agent.agent import curriculum_agent
from research_agent.agent import research_agent

syntra_orchestrator = SequentialAgent(
    name="syntra_orchestrator",
    description=(
        "Coordinates SYNTRA by running the Research Agent first, "
        "then passing that research package to the Curriculum Agent."
    ),
    sub_agents=[
        research_agent,
        curriculum_agent,
    ],
)

# ADK looks for this exact name when you run `adk run syntra_orchestrator`.
root_agent = syntra_orchestrator
