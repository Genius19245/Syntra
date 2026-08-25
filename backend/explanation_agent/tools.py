from __future__ import annotations

import json
import re
from typing import Any

from google.adk.tools.tool_context import ToolContext

MAX_CLAIMS = 6
MAX_MISCONCEPTIONS = 4
MAX_LESSON_STEPS = 3
MAX_PREREQUISITES = 6
MAX_KEY_CONCEPTS = 8
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
_LEVEL_REGEX: tuple[tuple[str, re.Pattern[str]], ...] = (
    (
        "postgraduate",
        re.compile(
            r"\b(post[- ]?graduate|master'?s|msc|phd|doctorate|doctoral)\b",
            re.IGNORECASE,
        ),
    ),
    (
        "undergraduate",
        re.compile(
            r"\b(undergraduate|undergrad|university|bachelor|bsc|college)\b",
            re.IGNORECASE,
        ),
    ),
    (
        "a_level",
        re.compile(
            r"\b(a-?levels?|a levels?|as-?levels?|as levels?|"
            r"ib(?:\s+diploma)?|sixth form|year 1[23])\b",
            re.IGNORECASE,
        ),
    ),
    (
        "gcse",
        re.compile(
            r"\b(i?gcse|ks4|key stage 4|year 1[01]|o-?levels?|o levels?)\b",
            re.IGNORECASE,
        ),
    ),
    (
        "lower_secondary",
        re.compile(
            r"\b(ks3|key stage 3|year [789]|middle school|junior high)\b",
            re.IGNORECASE,
        ),
    ),
    (
        "primary",
        re.compile(
            r"\b(ks[12]|key stage [12]|primary|elementary|year [1-6])\b",
            re.IGNORECASE,
        ),
    ),
)
_BAND_GUIDANCE: dict[str, dict[str, Any]] = {
    "primary": {
        "recommended_depth": "Foundational",
        "allow_equations": False,
        "allow_formalism": False,
        "prefer_analogies": True,
        "max_bloom": "Application",
        "style": (
            "Everyday language, concrete examples, and short analogies. "
            "Do not introduce equations or specialist jargon."
        ),
    },
    "lower_secondary": {
        "recommended_depth": "Foundational / KS3",
        "allow_equations": False,
        "allow_formalism": False,
        "prefer_analogies": True,
        "max_bloom": "Application",
        "style": (
            "Simple mechanisms and familiar examples. Name key terms "
            "once, then keep the explanation concrete."
        ),
    },
    "gcse": {
        "recommended_depth": "Foundational / GCSE",
        "allow_equations": True,
        "allow_formalism": False,
        "prefer_analogies": True,
        "max_bloom": "Analysis",
        "style": (
            "Exam-board terms, one simple equation if it is in the "
            "verified material, and a worked qualitative example. "
            "No undergraduate formalism."
        ),
    },
    "a_level": {
        "recommended_depth": "Intermediate / A-Level",
        "allow_equations": True,
        "allow_formalism": True,
        "prefer_analogies": True,
        "max_bloom": "Evaluation",
        "style": (
            "Precise definitions, mechanisms, and standard equations. "
            "Use an analogy only to introduce the idea, then move to "
            "the formal account."
        ),
    },
    "undergraduate": {
        "recommended_depth": "Advanced / Undergraduate",
        "allow_equations": True,
        "allow_formalism": True,
        "prefer_analogies": False,
        "max_bloom": "Creation",
        "style": (
            "Formal definitions, derivations where the package supports "
            "them, and limits of the model. Analogies are optional."
        ),
    },
    "postgraduate": {
        "recommended_depth": "Advanced / Specialist",
        "allow_equations": True,
        "allow_formalism": True,
        "prefer_analogies": False,
        "max_bloom": "Creation",
        "style": (
            "Specialist vocabulary, assumptions, and caveats. Stay "
            "inside the verified package; do not expand into research "
            "frontiers that are not present."
        ),
    },
    "unspecified": {
        "recommended_depth": "Adaptive",
        "allow_equations": True,
        "allow_formalism": False,
        "prefer_analogies": True,
        "max_bloom": "Analysis",
        "style": (
            "Match the supplied required depth. Prefer a clear "
            "mechanism and one example; add formalism only if asked."
        ),
    },
}
_PROFILE_LEVEL_KEYS = (
    "education_level",
    "level",
    "Education Level",
    "Level",
)


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


def _education_band(education_level: str) -> str:
    for band, pattern in _LEVEL_REGEX:
        if pattern.search(education_level):
            return band
    return "unspecified"


def _profile_level(learner_profile: Any) -> str:
    data = _as_data(learner_profile)
    if isinstance(data, dict):
        for key in _PROFILE_LEVEL_KEYS:
            text = _normalise(data.get(key))
            if text:
                return text
        data = " ".join(str(item) for item in data.values() if item)
    return _normalise(data)


def _score_text(text: str, concept_lower: str, concept_tokens: set[str]) -> int:
    cleaned = _normalise(text)
    if not cleaned:
        return 0
    lowered = cleaned.lower()
    if concept_lower and concept_lower in lowered:
        return 100 + len(concept_tokens.intersection(_tokens(cleaned)))
    if not concept_tokens:
        return 0
    overlap = len(concept_tokens.intersection(_tokens(cleaned)))
    return overlap * 12 if overlap else 0


def _compact_claim(item: dict[str, Any]) -> dict[str, Any]:
    verification = item.get("verification")
    verdict = ""
    if isinstance(verification, dict):
        verdict = _normalise(verification.get("verdict") or verification.get("status"))
    elif verification:
        verdict = _normalise(verification)
    sources = item.get("sources")
    source_name = ""
    if isinstance(sources, list) and sources:
        first = sources[0]
        if isinstance(first, dict):
            source_name = _normalise(first.get("organisation") or first.get("title"))
        else:
            source_name = _normalise(first)
    elif item.get("source"):
        source_name = _normalise(item.get("source"))
    return {
        "claim": _normalise(item.get("claim")),
        "evidence": _normalise(item.get("evidence") or item.get("relevant_passage")),
        "verification": verdict or None,
        "source": source_name or None,
    }


def _collect_claims(
    package: Any, concept_lower: str, concept_tokens: set[str]
) -> list[dict[str, Any]]:
    data = _as_data(package)
    if not isinstance(data, dict):
        return []
    scored: list[tuple[int, dict[str, Any]]] = []
    for raw in data.get("claims") or []:
        if not isinstance(raw, dict):
            continue
        blob = " ".join(
            _normalise(raw.get(key))
            for key in ("claim", "evidence", "relevant_passage", "topic")
        )
        score = _score_text(blob, concept_lower, concept_tokens)
        if score:
            scored.append((score, _compact_claim(raw)))
    scored.sort(key=lambda item: item[0], reverse=True)
    return [item for _, item in scored[:MAX_CLAIMS]]


def _matching_strings(
    values: Any, concept_lower: str, concept_tokens: set[str], limit: int
) -> list[str]:
    matches: list[tuple[int, str]] = []
    seen: set[str] = set()
    for raw in values or []:
        text = _normalise(raw)
        key = text.lower()
        if not text or key in seen:
            continue
        score = _score_text(text, concept_lower, concept_tokens)
        if not score:
            continue
        seen.add(key)
        matches.append((score, text))
    matches.sort(key=lambda item: item[0], reverse=True)
    return [text for _, text in matches[:limit]]


def _lesson_steps(
    lesson_plan: Any, concept_lower: str, concept_tokens: set[str]
) -> list[dict[str, Any]]:
    data = _as_data(lesson_plan)
    if isinstance(data, dict):
        sequence = data.get("lesson_sequence") or data.get("steps") or []
    elif isinstance(data, list):
        sequence = data
    else:
        return []
    scored: list[tuple[int, dict[str, Any]]] = []
    for raw in sequence:
        if not isinstance(raw, dict):
            continue
        concepts = [
            _normalise(item) for item in (raw.get("concepts") or []) if _normalise(item)
        ]
        blob = " ".join(
            [
                _normalise(raw.get("title")),
                _normalise(raw.get("purpose")),
                " ".join(concepts),
            ]
        )
        score = _score_text(blob, concept_lower, concept_tokens)
        if not score:
            continue
        scored.append(
            (
                score,
                {
                    "step": raw.get("step"),
                    "title": _normalise(raw.get("title")),
                    "concepts": concepts,
                },
            )
        )
    scored.sort(key=lambda item: item[0], reverse=True)
    return [item for _, item in scored[:MAX_LESSON_STEPS]]


def _prerequisites(
    analysis: Any, concept_lower: str, concept_tokens: set[str]
) -> list[str]:
    data = _as_data(analysis)
    values: list[Any] = []
    if isinstance(data, dict):
        for key in ("core", "helpful", "missing", "mastered", "all", "required"):
            items = data.get(key)
            if isinstance(items, list):
                values.extend(items)
            elif isinstance(items, str):
                values.append(items)
        if not values:
            values = [
                value for value in data.values() if isinstance(value, (str, list))
            ]
    elif isinstance(data, list):
        values = data
    elif data:
        values = [data]
    flat: list[str] = []
    for item in values:
        if isinstance(item, list):
            flat.extend(_normalise(part) for part in item)
        else:
            flat.append(_normalise(item))
    return _matching_strings(flat, concept_lower, concept_tokens, MAX_PREREQUISITES)


def match_concept_context(
    concept: str,
    research_package: Any = None,
    lesson_plan: Any = None,
    prerequisite_analysis: Any = None,
) -> dict[str, Any]:
    """Return compact verified excerpts for one concept. Does not explain."""

    cleaned = _normalise(concept)
    if not cleaned:
        return {
            "status": "error",
            "message": "No concept provided.",
            "concept": "",
            "match_count": 0,
        }

    concept_lower = cleaned.lower()
    concept_tokens = _tokens(cleaned)
    package = _as_data(research_package)
    claims = _collect_claims(package, concept_lower, concept_tokens)
    misconceptions = _matching_strings(
        package.get("misconceptions") if isinstance(package, dict) else None,
        concept_lower,
        concept_tokens,
        MAX_MISCONCEPTIONS,
    )
    key_concepts = _matching_strings(
        package.get("key_concepts") if isinstance(package, dict) else None,
        concept_lower,
        concept_tokens,
        MAX_KEY_CONCEPTS,
    )
    lesson_steps = _lesson_steps(lesson_plan, concept_lower, concept_tokens)
    prerequisites = _prerequisites(prerequisite_analysis, concept_lower, concept_tokens)
    match_count = (
        len(claims)
        + len(misconceptions)
        + len(key_concepts)
        + len(lesson_steps)
        + len(prerequisites)
    )
    if match_count == 0:
        return {
            "status": "not_found",
            "message": (
                "No verified excerpts matched this concept. Use the "
                "research package already in session context; do not invent."
            ),
            "concept": cleaned,
            "match_count": 0,
            "claims": [],
            "misconceptions": [],
            "key_concepts": [],
            "lesson_steps": [],
            "prerequisites": [],
        }
    return {
        "status": "success",
        "concept": cleaned,
        "match_count": match_count,
        "claims": claims,
        "misconceptions": misconceptions,
        "key_concepts": key_concepts,
        "lesson_steps": lesson_steps,
        "prerequisites": prerequisites,
    }


def retrieve_concept_context(
    concept: str,
    tool_context: ToolContext | None = None,
) -> dict[str, Any]:
    """
    Pull compact verified excerpts for one concept from session state.

    Reads research_package, lesson_plan, and prerequisite_analysis.
    Does not return the full package and does not write the explanation.
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
    return match_concept_context(
        concept,
        research_package=state.get("research_package"),
        lesson_plan=state.get("lesson_plan"),
        prerequisite_analysis=state.get("prerequisite_analysis"),
    )


def get_explanation_level(
    education_level: str = "",
    required_depth: str = "",
    tool_context: ToolContext | None = None,
) -> dict[str, Any]:
    """
    Map the learner's education level to explanation constraints.

    Does not write the explanation. Call once per concept.
    """

    state = _session_state(tool_context)
    level_text = _normalise(education_level) or _profile_level(
        state.get("learner_profile")
    )
    depth_text = _normalise(required_depth)
    band = _education_band(level_text)
    guidance = _BAND_GUIDANCE[band]
    recommended = guidance["recommended_depth"]
    if band == "unspecified" and depth_text:
        recommended = depth_text
    return {
        "education_level": level_text,
        "education_band": band,
        "required_depth": depth_text or None,
        "recommended_depth": recommended,
        "allow_equations": guidance["allow_equations"],
        "allow_formalism": guidance["allow_formalism"],
        "prefer_analogies": guidance["prefer_analogies"],
        "max_bloom": guidance["max_bloom"],
        "style": guidance["style"],
    }
