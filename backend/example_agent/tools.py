from __future__ import annotations

import json
import re
from typing import Any

from google.adk.tools.tool_context import ToolContext

EXAMPLE_TYPES = (
    "conceptual",
    "real_world",
    "worked",
    "numerical",
    "analogy",
    "counterexample",
    "exam_application",
)

_CONCEPT_TYPE_ALIASES: tuple[tuple[str, tuple[str, ...]], ...] = (
    (
        "numerical",
        (
            "mathematical",
            "maths",
            "quantitative",
            "numerical",
            "calculation",
            "equation",
        ),
    ),
    ("worked", ("worked", "step by step", "derivation")),
    (
        "real_world",
        ("practical", "application", "real-world", "real world", "everyday"),
    ),
    ("analogy", ("analogy", "metaphor")),
    ("counterexample", ("counter", "misconception", "false", "not always")),
    ("exam_application", ("exam", "exam-style", "past paper", "mark scheme")),
    ("conceptual", ("conceptual", "qualitative", "idea")),
)
_ANALOGY_LIMIT_RE = re.compile(
    r"\b(unlike|breaks? down|does not|doesn't|limit|fails?|not the same|"
    r"analogy stops|only as far)\b",
    re.IGNORECASE,
)
_EQUATION_RE = re.compile(
    r"(=|≈|\\frac|d[Φφ]/dt|-N\b|\b[A-Za-z]\s*=)",
)
_DIGIT_RE = re.compile(r"\d")
_UNIT_RE = re.compile(
    r"\b(m|s|kg|n|v|a|w|j|t|wb|hz|c|k|n/c|v/m)\b",
    re.IGNORECASE,
)
_BAND_DEFAULT_TYPE: dict[str, str] = {
    "primary": "conceptual",
    "lower_secondary": "conceptual",
    "gcse": "conceptual",
    "a_level": "exam_application",
    "undergraduate": "real_world",
    "postgraduate": "worked",
    "unspecified": "conceptual",
}
_STOP = frozenset(
    {
        "the",
        "a",
        "an",
        "of",
        "and",
        "or",
        "to",
        "in",
        "on",
        "for",
        "is",
        "be",
        "as",
        "at",
        "by",
        "with",
        "from",
        "that",
        "this",
        "it",
    }
)
_WORD_RE = re.compile(r"[a-z0-9]+(?:'[a-z]+)?", re.IGNORECASE)


def _normalise(value: Any) -> str:
    return " ".join(str(value or "").split()).strip()


def _tokens(text: str) -> set[str]:
    return {
        match.group(0).lower()
        for match in _WORD_RE.finditer(text)
        if match.group(0).lower() not in _STOP and len(match.group(0)) > 2
    }


def _as_data(value: Any) -> Any:
    if value is None:
        return None
    dump = getattr(value, "model_dump", None)
    if callable(dump):
        return dump()
    if isinstance(value, str):
        stripped = value.strip()
        if stripped.startswith(("{", "[")):
            try:
                return json.loads(stripped)
            except json.JSONDecodeError:
                return value
        return value
    return value


def _session_state(tool_context: Any) -> dict[str, Any]:
    if tool_context is None:
        return {}
    state = getattr(tool_context, "state", None)
    if isinstance(state, dict):
        return state
    session = getattr(tool_context, "session", None)
    nested = getattr(session, "state", None) if session is not None else None
    return nested if isinstance(nested, dict) else {}


def _profile_level(learner_profile: Any) -> str:
    data = _as_data(learner_profile)
    if isinstance(data, dict):
        for key in ("education_level", "level", "Education Level", "Level"):
            text = _normalise(data.get(key))
            if text:
                return text
    return _normalise(data)


def _requested_type(concept_type: str) -> str:
    text = _normalise(concept_type).lower()
    if not text:
        return ""
    if text in EXAMPLE_TYPES:
        return text
    for example_type, aliases in _CONCEPT_TYPE_ALIASES:
        for alias in aliases:
            if re.search(rf"\b{re.escape(alias)}\b", text):
                return example_type
    return ""


def _concept_type_from_upstream(
    adaptation: Any = None,
    interaction: Any = None,
    explanation: Any = None,
) -> str:
    """Closed-set hint from specialist outputs already in session state."""

    chunks: list[str] = []
    for blob in (adaptation, interaction, explanation):
        data = _as_data(blob)
        if isinstance(data, dict):
            chunks.append(_normalise(data.get("action")))
            chunks.append(_normalise(data.get("suggested_move")))
            chunks.append(_normalise(data.get("type")))
            chunks.append(_normalise(data.get("intent")))
        chunks.append(_normalise(data))
    text = " ".join(chunk for chunk in chunks if chunk).lower()
    if not text:
        return ""
    if re.search(r"\bprovide_analogy\b", text):
        return "analogy"
    if re.search(
        r"\b(provide_example|give_example|example_request|worked example)\b",
        text,
    ):
        if "worked" in text:
            return "worked"
        return "conceptual"
    return ""


def choose_example_type(
    learner_level: str = "",
    concept_type: str = "",
    learner_profile: Any = None,
    adaptation: Any = None,
    interaction: Any = None,
    explanation: Any = None,
) -> dict[str, Any]:
    """Pick a closed-set example format for this learner. Does not write the example."""

    level_text = _normalise(learner_level) or _profile_level(learner_profile)
    from explanation_agent.tools import get_explanation_level

    guidance = get_explanation_level(level_text)
    band = guidance["education_band"]
    requested = _requested_type(concept_type) or _concept_type_from_upstream(
        adaptation=adaptation,
        interaction=interaction,
        explanation=explanation,
    )
    example_type = requested or _BAND_DEFAULT_TYPE.get(band, "conceptual")

    if example_type in {"numerical", "worked"} and not guidance["allow_equations"]:
        example_type = "conceptual"
    if example_type == "analogy" and not guidance["prefer_analogies"]:
        example_type = "conceptual"
    if requested == "numerical" and band in {
        "a_level",
        "undergraduate",
        "postgraduate",
    }:
        example_type = "worked"
    if requested == "real_world" and band == "a_level":
        example_type = "exam_application"

    return {
        "example_type": example_type,
        "education_level": guidance["education_level"] or level_text,
        "education_band": band,
        "allow_numbers": guidance["allow_equations"],
        "require_units": example_type in {"numerical", "worked"},
        "require_analogy_limit": example_type == "analogy",
        "style": guidance["style"],
    }


def select_example_type(
    learner_level: str = "",
    concept_type: str = "",
    tool_context: ToolContext | None = None,
) -> dict[str, Any]:
    """
    Determine an appropriate example format from the learner's level.

    Reads learner_profile from session when learner_level is omitted.
    """

    state = _session_state(tool_context)
    return choose_example_type(
        learner_level=learner_level,
        concept_type=concept_type,
        learner_profile=state.get("learner_profile"),
        adaptation=state.get("adaptation"),
        interaction=state.get("interaction"),
        explanation=state.get("explanation"),
    )


def _equation_snippets(claims: list[dict[str, Any]]) -> list[str]:
    snippets: list[str] = []
    seen: set[str] = set()
    for item in claims:
        blob = " ".join(_normalise(item.get(key)) for key in ("claim", "evidence"))
        if not blob or not _EQUATION_RE.search(blob):
            continue
        key = blob.lower()
        if key in seen:
            continue
        seen.add(key)
        snippets.append(blob)
        if len(snippets) == 4:
            break
    return snippets


def match_example_context(
    concept: str,
    research_package: Any = None,
    lesson_plan: Any = None,
    prerequisite_analysis: Any = None,
) -> dict[str, Any]:
    """Compact verified excerpts for building an example. Does not invent one."""

    from explanation_agent.tools import match_concept_context

    matched = match_concept_context(
        concept,
        research_package=research_package,
        lesson_plan=lesson_plan,
        prerequisite_analysis=prerequisite_analysis,
    )
    if matched.get("status") != "success":
        return matched
    package = _as_data(research_package)
    packaged_examples = []
    if isinstance(package, dict):
        for raw in package.get("examples") or []:
            text = _normalise(
                raw
                if not isinstance(raw, dict)
                else raw.get("text") or raw.get("example")
            )
            if text:
                packaged_examples.append(text)
    return {
        **matched,
        "equations": _equation_snippets(matched.get("claims") or []),
        "packaged_examples": packaged_examples[:4],
        "context": None,
    }


def retrieve_example_context(
    concept: str,
    tool_context: ToolContext | None = None,
) -> dict[str, Any]:
    """
    Pull compact verified material for one concept from session state.

    Does not return the full research package.
    """

    state = _session_state(tool_context)
    if not any(
        state.get(key)
        for key in ("research_package", "lesson_plan", "prerequisite_analysis")
    ):
        return {
            "status": "error",
            "message": "No lesson context in session state.",
            "concept": _normalise(concept),
            "match_count": 0,
        }
    return match_example_context(
        concept,
        research_package=state.get("research_package"),
        lesson_plan=state.get("lesson_plan"),
        prerequisite_analysis=state.get("prerequisite_analysis"),
    )


def check_example(
    example: str,
    required_concept: str,
    example_type: str = "",
    research_package: Any = None,
) -> dict[str, Any]:
    """Validate an example. Does not rewrite it."""

    text = _normalise(example)
    concept = _normalise(required_concept)
    kind = _requested_type(example_type) or _normalise(example_type).lower()
    issues: list[str] = []
    warnings: list[str] = []

    if not text:
        issues.append("Example is empty.")
    if not concept:
        issues.append("No target concept supplied.")

    words = text.split()
    word_count = len(words)
    concept_tokens = _tokens(concept)
    mentions = bool(concept_tokens and concept_tokens.intersection(_tokens(text)))
    if text and concept and not mentions:
        issues.append("Example does not mention the target concept.")
    if word_count and word_count < 8:
        issues.append("Example is too short to be useful.")
    elif word_count > 160:
        warnings.append("Example is long; tighten it.")

    if kind in {"numerical", "worked"} and text:
        if not _DIGIT_RE.search(text):
            issues.append("Numerical or worked example has no values.")
        if kind == "worked" and not _EQUATION_RE.search(text):
            issues.append("Worked example has no equation or substitution.")
        if kind in {"numerical", "worked"} and not _UNIT_RE.search(text):
            warnings.append("Add units if the verified material includes them.")
    if kind == "analogy" and text and not _ANALOGY_LIMIT_RE.search(text):
        issues.append("Analogy does not state where it stops being accurate.")

    package_tokens: set[str] = set()
    package = _as_data(research_package)
    if isinstance(package, dict):
        for claim in package.get("claims") or []:
            if isinstance(claim, dict):
                package_tokens.update(_tokens(claim.get("claim") or ""))
                package_tokens.update(_tokens(claim.get("evidence") or ""))
        package_tokens.update(_tokens(package.get("topic") or ""))
        for item in package.get("key_concepts") or []:
            package_tokens.update(_tokens(item))
    if text and package_tokens and not package_tokens.intersection(_tokens(text)):
        warnings.append(
            "Example does not overlap verified package wording. Check it is grounded."
        )

    return {
        "valid": not issues,
        "issues": issues,
        "warnings": warnings,
        "example_type": kind or None,
        "word_count": word_count,
        "mentions_concept": mentions,
    }


def validate_example(
    example: str,
    required_concept: str,
    example_type: str = "",
    tool_context: ToolContext | None = None,
) -> dict[str, Any]:
    """
    Check that an example is non-empty, on-concept, and type-appropriate.

    Does not generate a replacement example.
    """

    state = _session_state(tool_context)
    return check_example(
        example=example,
        required_concept=required_concept,
        example_type=example_type,
        research_package=state.get("research_package"),
    )
