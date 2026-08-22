import re
from itertools import pairwise

BLOOM_TYPES = (
    "Knowledge",
    "Understanding",
    "Application",
    "Analysis",
    "Evaluation",
    "Creation",
)

BLOOM_RANK = {name: index + 1 for index, name in enumerate(BLOOM_TYPES)}

MIN_OBJECTIVES = 2
MAX_OBJECTIVES = 8
RECOMMENDED_OBJECTIVE_COUNT = {"min": 3, "max": 6}

BLOOM_VERBS: dict[str, tuple[str, ...]] = {
    "Knowledge": (
        "define",
        "identify",
        "state",
        "list",
        "recall",
        "name",
        "label",
        "recognise",
        "recognize",
        "select",
        "match",
        "repeat",
        "memorise",
        "memorize",
        "quote",
        "outline",
    ),
    "Understanding": (
        "explain",
        "describe",
        "summarise",
        "summarize",
        "paraphrase",
        "discuss",
        "illustrate",
        "predict",
        "restate",
        "exemplify",
        "infer",
        "interpret",
        "classify",
        "clarify",
    ),
    "Application": (
        "calculate",
        "apply",
        "solve",
        "implement",
        "perform",
        "demonstrate",
        "compute",
        "execute",
        "operate",
        "practise",
        "practice",
        "show",
        "use",
        "employ",
    ),
    "Analysis": (
        "analyse",
        "analyze",
        "compare",
        "contrast",
        "differentiate",
        "organise",
        "organize",
        "examine",
        "investigate",
        "distinguish",
        "deconstruct",
        "attribute",
        "categorise",
        "categorize",
        "relate",
    ),
    "Evaluation": (
        "evaluate",
        "assess",
        "judge",
        "critique",
        "justify",
        "argue",
        "appraise",
        "defend",
        "recommend",
        "criticise",
        "criticize",
        "conclude",
        "prioritise",
        "prioritize",
    ),
    "Creation": (
        "design",
        "create",
        "develop",
        "construct",
        "produce",
        "compose",
        "formulate",
        "invent",
        "generate",
        "plan",
        "propose",
        "synthesise",
        "synthesize",
        "build",
        "assemble",
        "devise",
    ),
}

_VERB_TYPE: dict[str, str] = {
    verb: bloom_type
    for bloom_type, verbs in BLOOM_VERBS.items()
    for verb in verbs
}

_PHRASE_VERBS: tuple[tuple[str, str], ...] = (
    ("give examples", "Understanding"),
    ("break down", "Analysis"),
    ("carry out", "Application"),
)

_BAND_BLOOM: dict[str, tuple[str, ...]] = {
    "primary": ("Knowledge", "Understanding", "Application"),
    "lower_secondary": ("Knowledge", "Understanding", "Application"),
    "gcse": ("Knowledge", "Understanding", "Application", "Analysis"),
    "a_level": ("Understanding", "Application", "Analysis", "Evaluation"),
    "undergraduate": ("Application", "Analysis", "Evaluation", "Creation"),
    "postgraduate": ("Analysis", "Evaluation", "Creation"),
    "unspecified": BLOOM_TYPES,
}

_BAND_COUNT: dict[str, dict[str, int]] = {
    "primary": {"min": 2, "max": 4},
    "lower_secondary": {"min": 3, "max": 5},
    "gcse": {"min": 3, "max": 6},
    "a_level": {"min": 3, "max": 6},
    "undergraduate": {"min": 3, "max": 7},
    "postgraduate": {"min": 3, "max": 6},
    "unspecified": RECOMMENDED_OBJECTIVE_COUNT,
}

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
            r"\b(a-?levels?|a levels?|as-?levels?|as levels?|ib(?:\s+diploma)?|sixth form|year 1[23])\b",
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

_NUMBER_PREFIX = re.compile(r"^\s*(?:\d+\s*[.)]|[-*•])\s*")
_STEM = re.compile(
    r"^(?:(?:the\s+)?(?:learner|student|pupils?|they)\s+)?"
    r"(?:will\s+(?:be\s+able\s+to\s+)?|be\s+able\s+to\s+|can\s+|"
    r"should\s+(?:be\s+able\s+to\s+)?)",
    re.IGNORECASE,
)
_WORD_RE = re.compile(r"[a-z]+(?:'[a-z]+)?", re.IGNORECASE)
_WEAK_LANGUAGE = re.compile(
    r"be familiar with|become familiar with|gain an understanding of|"
    r"have an understanding of|demonstrate an understanding of|"
    r"learn about|become aware of|"
    r"\bunderstand(?:s|ing)?\b|\bknow(?:s|ing)?\b|"
    r"\bappreciate(?:s|d|ing)?\b|\bcomprehend(?:s|ing)?\b|"
    r"\bgrasp(?:s|ing)?\b|\bfamiliarise(?:s|d)?\b|\bfamiliarize(?:s|d)?\b|"
    r"\blearn(?:s)?\b",
    re.IGNORECASE,
)


def _normalise_text(value: str | None) -> str:
    return " ".join(str(value or "").split()).strip()


def _normalise_objective(objective: str) -> str:
    cleaned = _NUMBER_PREFIX.sub("", _normalise_text(objective))
    return _STEM.sub("", cleaned).strip(" .:")


def _dedupe(items: list[str] | None) -> list[str]:
    unique: list[str] = []
    seen: set[str] = set()
    for item in items or []:
        cleaned = _normalise_text(item)
        if not cleaned:
            continue
        key = cleaned.lower()
        if key in seen:
            continue
        seen.add(key)
        unique.append(cleaned)
    return unique


def _as_list(value: list[str] | str | None) -> list[str]:
    if value is None:
        return []
    if isinstance(value, str):
        return [value]
    return [str(item) for item in value]


def _education_band(education_level: str) -> str:
    for band, pattern in _LEVEL_REGEX:
        if pattern.search(education_level):
            return band
    return "unspecified"


def _words(text: str) -> list[str]:
    return [match.group(0).lower() for match in _WORD_RE.finditer(text)]


def _mentions_topic(objective: str, topic_tokens: set[str]) -> bool:
    if not topic_tokens:
        return False
    objective_tokens = set(_words(objective))
    if topic_tokens & objective_tokens:
        return True
    stems = {token[:5] for token in topic_tokens if len(token) >= 5}
    return any(len(word) >= 5 and word[:5] in stems for word in objective_tokens)


def _classify_one(objective: str) -> dict:
    original = _normalise_text(objective)
    cleaned = _normalise_objective(original)
    lowered = cleaned.lower()

    for phrase, bloom_type in _PHRASE_VERBS:
        if phrase in lowered:
            return {
                "objective": original,
                "type": bloom_type,
                "verb": phrase,
                "rank": BLOOM_RANK[bloom_type],
            }

    tokens = _words(cleaned)
    if tokens:
        leading = tokens[0]
        bloom_type = _VERB_TYPE.get(leading)
        if bloom_type:
            return {
                "objective": original,
                "type": bloom_type,
                "verb": leading,
                "rank": BLOOM_RANK[bloom_type],
            }

    for phrase, bloom_type in _PHRASE_VERBS:
        if phrase in lowered:
            return {
                "objective": original,
                "type": bloom_type,
                "verb": phrase,
                "rank": BLOOM_RANK[bloom_type],
            }

    for token in tokens[1:]:
        bloom_type = _VERB_TYPE.get(token)
        if bloom_type:
            return {
                "objective": original,
                "type": bloom_type,
                "verb": token,
                "rank": BLOOM_RANK[bloom_type],
            }

    return {
        "objective": original,
        "type": "Unclassified",
        "verb": tokens[0] if tokens else "",
        "rank": 0,
    }


def generate_objective_framework(
    subject: str,
    topic: str,
    education_level: str,
    learning_goal: str | None = None,
    learner_profile: str | None = None,
    prerequisite_analysis: str | None = None,
) -> dict:
    """
    Record the target context and return Bloom constraints for drafting
    measurable learning objectives.

    Does not invent objectives, the learner, or the topic.
    """

    subject_text = _normalise_text(subject)
    topic_text = _normalise_text(topic)
    level_text = _normalise_text(education_level)
    goal_text = _normalise_text(learning_goal)
    band = _education_band(level_text)
    recommended_types = _BAND_BLOOM[band]
    recommended_count = _BAND_COUNT[band]
    verb_bank = {bloom_type: list(BLOOM_VERBS[bloom_type]) for bloom_type in recommended_types}

    return {
        "subject": subject_text,
        "topic": topic_text,
        "education_level": level_text,
        "learning_goal": goal_text or None,
        "education_band": band,
        "has_learner_profile": bool(_normalise_text(learner_profile)),
        "has_prerequisite_analysis": bool(_normalise_text(prerequisite_analysis)),
        "recommended_bloom_types": list(recommended_types),
        "recommended_objective_count": recommended_count,
        "verb_bank": verb_bank,
        "avoid_verbs": [
            "understand",
            "know",
            "learn",
            "be familiar with",
            "appreciate",
            "grasp",
            "comprehend",
        ],
        "objective_stem": (
            "By the end of the learning experience, the learner will be able to"
        ),
        "instruction": (
            "Draft observable, measurable objectives for this subject, topic, "
            "and education level. Use the recommended Bloom types and verb "
            "bank. Start from the prerequisite analysis rather than missing "
            "prior knowledge. Do not invent a different learner, subject, or topic."
        ),
    }


def classify_objective_type(objectives: list[str]) -> dict:
    """
    Classify each learning objective by its primary Bloom type.

    Uses the leading action verb where possible. Does not rewrite objectives.
    """

    classifications = [
        _classify_one(objective) for objective in _dedupe(_as_list(objectives))
    ]
    type_counts: dict[str, int] = {}
    for item in classifications:
        type_counts[item["type"]] = type_counts.get(item["type"], 0) + 1

    ranks = [item["rank"] for item in classifications if item["rank"]]
    is_progressive = bool(ranks) and all(
        later >= earlier for earlier, later in pairwise(ranks)
    )

    return {
        "classifications": classifications,
        "type_counts": type_counts,
        "progression": [item["type"] for item in classifications],
        "is_progressive": is_progressive,
        "classified_count": len(classifications),
        "unclassified_count": type_counts.get("Unclassified", 0),
    }


def validate_learning_objectives(
    objectives: list[str],
    education_level: str | None = None,
    topic: str | None = None,
) -> dict:
    """
    Check that learning objectives are observable, specific, and
    level-appropriate. Does not generate replacement objectives.
    """

    issues: list[str] = []
    warnings: list[str] = []
    supplied = [
        item
        for item in (_normalise_text(raw) for raw in _as_list(objectives))
        if item
    ]
    unique = _dedupe(supplied)
    classified = classify_objective_type(unique)
    band = _education_band(_normalise_text(education_level)) if education_level else "unspecified"
    recommended_types = set(_BAND_BLOOM[band])
    recommended_count = _BAND_COUNT[band]
    topic_tokens = {token for token in _words(_normalise_text(topic)) if len(token) > 3}

    if len(supplied) != len(unique):
        issues.append("Duplicate objectives were supplied.")

    if len(unique) < MIN_OBJECTIVES:
        issues.append(
            f"Too few objectives ({len(unique)}). Provide at least {MIN_OBJECTIVES}."
        )
    elif len(unique) > MAX_OBJECTIVES:
        issues.append(
            f"Too many objectives ({len(unique)}). Keep at most {MAX_OBJECTIVES}."
        )
    elif not (
        recommended_count["min"] <= len(unique) <= recommended_count["max"]
    ):
        warnings.append(
            "Objective count is outside the recommended range "
            f"{recommended_count['min']}-{recommended_count['max']} "
            f"for {band} learners."
        )

    results = []
    topic_hits = 0

    for item in classified["classifications"]:
        objective = item["objective"]
        word_count = len(_words(objective))
        weak_terms = sorted({match.group(0).lower() for match in _WEAK_LANGUAGE.finditer(objective)})
        objective_issues: list[str] = []

        if word_count < 3:
            objective_issues.append("Too short to be specific.")
        elif word_count > 40:
            objective_issues.append("Too long; split or tighten the objective.")

        if weak_terms:
            objective_issues.append(
                "Replace weak language with an observable verb: " + ", ".join(weak_terms)
            )

        if item["type"] == "Unclassified":
            objective_issues.append(
                "No observable Bloom verb found. Start with a verb such as "
                "explain, calculate, compare, evaluate, or design."
            )
        elif (
            band != "unspecified"
            and item["type"] not in recommended_types
            and BLOOM_RANK.get(item["type"], 0) > max(BLOOM_RANK[t] for t in recommended_types)
        ):
            objective_issues.append(
                f"{item['type']} may be too advanced for a {band} learner."
            )

        if _mentions_topic(objective, topic_tokens):
            topic_hits += 1

        status = "Needs revision" if objective_issues else "Pass"
        results.append(
            {
                "objective": objective,
                "type": item["type"],
                "verb": item["verb"],
                "rank": item["rank"],
                "word_count": word_count,
                "has_weak_language": bool(weak_terms),
                "weak_terms": weak_terms,
                "issues": objective_issues,
                "specific": word_count >= 3,
                "measurable": item["type"] != "Unclassified" and not weak_terms,
                "observable": item["type"] != "Unclassified",
                "status": status,
            }
        )

    failed = [result for result in results if result["status"] != "Pass"]
    if failed:
        issues.append(f"{len(failed)} objective(s) need revision.")

    if topic_tokens and unique and topic_hits == 0:
        warnings.append(
            "None of the objectives mention the target topic. Check relevance."
        )

    if (
        len(results) >= 4
        and classified["classified_count"]
        and classified["unclassified_count"] == 0
        and len(classified["type_counts"]) == 1
    ):
        warnings.append(
            "All objectives are the same type. Add progression across Bloom levels "
            "where the lesson can support it."
        )

    ranks = [result["rank"] for result in results if result["rank"]]
    if ranks and ranks[0] >= BLOOM_RANK["Evaluation"] and min(ranks) <= BLOOM_RANK["Understanding"]:
        warnings.append(
            "Objectives appear to start at a high Bloom level and later drop back. "
            "Reorder from foundational to more advanced."
        )

    valid_count = sum(1 for result in results if result["status"] == "Pass")

    return {
        "valid": not issues and valid_count == len(results) and bool(results),
        "issues": issues,
        "warnings": warnings,
        "objectives": results,
        "valid_count": valid_count,
        "total_count": len(results),
        "all_valid": valid_count == len(results) and bool(results),
        "type_counts": classified["type_counts"],
        "progression": classified["progression"],
        "is_progressive": classified["is_progressive"],
        "education_band": band,
        "checks": {
            "specific": all(result["specific"] for result in results) if results else False,
            "measurable": all(result["measurable"] for result in results) if results else False,
            "level_appropriate": not any(
                "too advanced" in issue for result in results for issue in result["issues"]
            ),
            "relevant": topic_hits > 0 or not topic_tokens,
            "observable": all(result["observable"] for result in results) if results else False,
        },
    }
