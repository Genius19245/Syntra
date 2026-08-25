from pathlib import Path

from google.adk.skills import load_skill_from_dir
from google.adk.tools.skill_toolset import SkillToolset

SKILLS_DIR = Path(__file__).resolve().parent / "skills"

SKILL_NAMES = (
    "source-evaluation",
    "research-query",
    "evidence-extraction",
    "citation",
    "curriculum-alignment",
)


def load_research_skills() -> SkillToolset:
    """Load reusable research methodology skills for the Research Agent."""
    skills = [load_skill_from_dir(SKILLS_DIR / name) for name in SKILL_NAMES]
    return SkillToolset(skills=skills)
