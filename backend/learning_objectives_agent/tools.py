import json
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
    verb: bloom_type for bloom_type, verbs in BLOOM_VERBS.items() for verb in verbs
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

_BAND_BLOOM_SET = {band: frozenset(types) for band, types in _BAND_BLOOM.items()}
_BAND_MAX_RANK = {
    band: max(BLOOM_RANK[t] for t in types) for band, types in _BAND_BLOOM.items()
}
_BAND_VERB_BANK = {
    band: {bloom_type: BLOOM_VERBS[bloom_type] for bloom_type in types}
    for band, types in _BAND_BLOOM.items()
}
_AVOID_VERBS = (
    "understand",
    "know",
    "learn",
    "be familiar with",
    "appreciate",
    "grasp",
    "comprehend",
)
_OBJECTIVE_STEM = "By the end of the learning experience, the learner will be able to"
_FRAMEWORK_INSTRUCTION = (
    "Draft observable, measurable objectives for this subject, topic, "
    "and education level. Use the recommended Bloom types and verb "
    "bank. Start from the prerequisite analysis rather than missing "
    "prior knowledge. Do not invent a different learner, subject, or topic."
)

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
    cleaned = _NUMBER_PREFIX.sub("", objective)
    return _STEM.sub("", cleaned).strip(" .:")


def _as_list(value: list[str] | str | None) -> list[str]:
    if value is None:
        return []
    if isinstance(value, str):
        stripped = value.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            try:
                parsed = json.loads(stripped)
            except json.JSONDecodeError:
                parsed = None
            if isinstance(parsed, list):
                return [str(item) for item in parsed]
        return [value]
    return [str(item) for item in value]


_UNIQUE_CACHE_KEY: tuple[str, ...] | None = None
_UNIQUE_CACHE: tuple[list[str], list[str]] | None = None


def _unique_objectives(value: list[str] | str | None) -> tuple[list[str], list[str]]:
    global _UNIQUE_CACHE_KEY, _UNIQUE_CACHE
    raw = _as_list(value)
    cache_key = tuple(raw)
    if _UNIQUE_CACHE is not None and _UNIQUE_CACHE_KEY == cache_key:
        return _UNIQUE_CACHE

    supplied: list[str] = []
    unique: list[str] = []
    seen: set[str] = set()
    for item in raw:
        cleaned = _normalise_text(item)
        if not cleaned:
            continue
        supplied.append(cleaned)
        key = cleaned.lower()
        if key in seen:
            continue
        seen.add(key)
        unique.append(cleaned)
    _UNIQUE_CACHE_KEY = cache_key
    _UNIQUE_CACHE = (supplied, unique)
    return supplied, unique


def _education_band(education_level: str) -> str:
    for band, pattern in _LEVEL_REGEX:
        if pattern.search(education_level):
            return band
    return "unspecified"


def _words(text: str) -> list[str]:
    return [match.group(0).lower() for match in _WORD_RE.finditer(text)]


def _mentions_topic(
    objective_tokens: list[str],
    topic_tokens: set[str],
    topic_stems: set[str],
) -> bool:
    if not topic_tokens:
        return False
    for word in objective_tokens:
        if word in topic_tokens:
            return True
        if topic_stems and len(word) >= 5 and word[:5] in topic_stems:
            return True
    return False


def _classify_one(objective: str, *, normalised: bool = False) -> dict:
    original = objective if normalised else _normalise_text(objective)
    cleaned = _normalise_objective(original)
    lowered = cleaned.lower()
    original_tokens = _words(original)
    weak_terms = sorted(
        {match.group(0).lower() for match in _WEAK_LANGUAGE.finditer(original)}
    )
    bloom_type = "Unclassified"
    verb = ""
    rank = 0

    for phrase, phrase_type in _PHRASE_VERBS:
        if phrase in lowered:
            bloom_type = phrase_type
            verb = phrase
            rank = BLOOM_RANK[phrase_type]
            break
    else:
        tokens = _words(cleaned)
        if tokens:
            leading = tokens[0]
            matched = _VERB_TYPE.get(leading)
            if matched:
                bloom_type = matched
                verb = leading
                rank = BLOOM_RANK[matched]
            else:
                for token in tokens[1:]:
                    matched = _VERB_TYPE.get(token)
                    if matched:
                        bloom_type = matched
                        verb = token
                        rank = BLOOM_RANK[matched]
                        break
            if bloom_type == "Unclassified":
                verb = tokens[0]

    return {
        "objective": original,
        "type": bloom_type,
        "verb": verb,
        "rank": rank,
        "_tokens": original_tokens,
        "_weak": weak_terms,
    }


_CLASSIFY_CACHE_KEY: tuple[str, ...] | None = None
_CLASSIFY_CACHE: dict | None = None


def _classify_unique(unique: list[str]) -> dict:
    global _CLASSIFY_CACHE_KEY, _CLASSIFY_CACHE
    key = tuple(unique)
    if _CLASSIFY_CACHE is not None and _CLASSIFY_CACHE_KEY == key:
        return _CLASSIFY_CACHE

    classifications = [
        _classify_one(objective, normalised=True) for objective in unique
    ]
    type_counts: dict[str, int] = {}
    for item in classifications:
        type_counts[item["type"]] = type_counts.get(item["type"], 0) + 1

    ranks = [item["rank"] for item in classifications if item["rank"]]
    is_progressive = bool(ranks) and all(
        later >= earlier for earlier, later in pairwise(ranks)
    )
    result = {
        "classifications": classifications,
        "type_counts": type_counts,
        "progression": [item["type"] for item in classifications],
        "is_progressive": is_progressive,
        "classified_count": len(classifications),
        "unclassified_count": type_counts.get("Unclassified", 0),
    }
    _CLASSIFY_CACHE_KEY = key
    _CLASSIFY_CACHE = result
    return result


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

    return {
        "subject": subject_text,
        "topic": topic_text,
        "education_level": level_text,
        "learning_goal": goal_text or None,
        "education_band": band,
        "has_learner_profile": bool(learner_profile and learner_profile.strip()),
        "has_prerequisite_analysis": bool(
            prerequisite_analysis and prerequisite_analysis.strip()
        ),
        "recommended_bloom_types": _BAND_BLOOM[band],
        "recommended_objective_count": _BAND_COUNT[band],
        "verb_bank": _BAND_VERB_BANK[band],
        "avoid_verbs": _AVOID_VERBS,
        "objective_stem": _OBJECTIVE_STEM,
        "instruction": _FRAMEWORK_INSTRUCTION,
    }


def classify_objective_type(objectives: list[str]) -> dict:
    """
    Classify each learning objective by its primary Bloom type.

    Uses the leading action verb where possible. Does not rewrite objectives.
    """

    _, unique = _unique_objectives(objectives)
    classified = _classify_unique(unique)
    return {
        **classified,
        "classifications": [
            {
                "objective": item["objective"],
                "type": item["type"],
                "verb": item["verb"],
                "rank": item["rank"],
            }
            for item in classified["classifications"]
        ],
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
    supplied, unique = _unique_objectives(objectives)
    classified = _classify_unique(unique)
    band = (
        _education_band(_normalise_text(education_level))
        if education_level
        else "unspecified"
    )
    recommended_types = _BAND_BLOOM_SET[band]
    recommended_count = _BAND_COUNT[band]
    max_recommended_rank = _BAND_MAX_RANK[band]
    topic_tokens = {token for token in _words(_normalise_text(topic)) if len(token) > 3}
    topic_stems = {token[:5] for token in topic_tokens if len(token) >= 5}

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
    elif not (recommended_count["min"] <= len(unique) <= recommended_count["max"]):
        warnings.append(
            "Objective count is outside the recommended range "
            f"{recommended_count['min']}-{recommended_count['max']} "
            f"for {band} learners."
        )

    results = []
    topic_hits = 0
    failed = 0
    valid_count = 0
    all_specific = True
    all_measurable = True
    all_observable = True
    level_ok = True
    first_rank = 0
    min_rank = 0

    for item in classified["classifications"]:
        objective = item["objective"]
        tokens = item["_tokens"]
        word_count = len(tokens)
        weak_terms = item["_weak"]
        objective_issues: list[str] = []

        if word_count < 3:
            objective_issues.append("Too short to be specific.")
        elif word_count > 40:
            objective_issues.append("Too long; split or tighten the objective.")

        if weak_terms:
            objective_issues.append(
                "Replace weak language with an observable verb: "
                + ", ".join(weak_terms)
            )

        if item["type"] == "Unclassified":
            objective_issues.append(
                "No observable Bloom verb found. Start with a verb such as "
                "explain, calculate, compare, evaluate, or design."
            )
        elif (
            band != "unspecified"
            and item["type"] not in recommended_types
            and item["rank"] > max_recommended_rank
        ):
            objective_issues.append(
                f"{item['type']} may be too advanced for a {band} learner."
            )
            level_ok = False

        if _mentions_topic(tokens, topic_tokens, topic_stems):
            topic_hits += 1

        specific = word_count >= 3
        measurable = item["type"] != "Unclassified" and not weak_terms
        observable = item["type"] != "Unclassified"
        status = "Needs revision" if objective_issues else "Pass"
        if status == "Pass":
            valid_count += 1
        else:
            failed += 1
        if not specific:
            all_specific = False
        if not measurable:
            all_measurable = False
        if not observable:
            all_observable = False
        rank = item["rank"]
        if rank:
            if not first_rank:
                first_rank = rank
            if not min_rank or rank < min_rank:
                min_rank = rank

        results.append(
            {
                "objective": objective,
                "type": item["type"],
                "verb": item["verb"],
                "rank": rank,
                "word_count": word_count,
                "has_weak_language": bool(weak_terms),
                "weak_terms": weak_terms,
                "issues": objective_issues,
                "specific": specific,
                "measurable": measurable,
                "observable": observable,
                "status": status,
            }
        )

    if failed:
        issues.append(f"{failed} objective(s) need revision.")

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

    if (
        first_rank >= BLOOM_RANK["Evaluation"]
        and min_rank
        and min_rank <= BLOOM_RANK["Understanding"]
    ):
        warnings.append(
            "Objectives appear to start at a high Bloom level and later drop back. "
            "Reorder from foundational to more advanced."
        )

    all_ok = bool(results) and valid_count == len(results)
    return {
        "valid": not issues and all_ok,
        "issues": issues,
        "warnings": warnings,
        "objectives": results,
        "valid_count": valid_count,
        "total_count": len(results),
        "all_valid": all_ok,
        "type_counts": classified["type_counts"],
        "progression": classified["progression"],
        "is_progressive": classified["is_progressive"],
        "education_band": band,
        "checks": {
            "specific": all_specific if results else False,
            "measurable": all_measurable if results else False,
            "level_appropriate": level_ok,
            "relevant": topic_hits > 0 or not topic_tokens,
            "observable": all_observable if results else False,
        },
    }
