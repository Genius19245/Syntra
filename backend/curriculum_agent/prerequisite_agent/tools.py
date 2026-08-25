VALID_PRIORITIES = ("CORE", "HELPFUL", "ADVANCED")
_PRIORITIES_ALLOWED = list(VALID_PRIORITIES)


def _normalise_item(item: str) -> str:
    return " ".join(str(item).split()).strip()


def _dedupe(items: list[str] | None) -> list[str]:
    unique: list[str] = []
    seen: set[str] = set()
    for item in items or []:
        cleaned = _normalise_item(item)
        if not cleaned:
            continue
        key = cleaned.lower()
        if key in seen:
            continue
        seen.add(key)
        unique.append(cleaned)
    return unique


def _deduped_bands(
    core: list[str] | None = None,
    helpful: list[str] | None = None,
    advanced: list[str] | None = None,
) -> tuple[list[str], list[str], list[str]]:
    return _dedupe(core), _dedupe(helpful), _dedupe(advanced)


def _structure_from_bands(
    core: list[str],
    helpful: list[str],
    advanced: list[str],
) -> dict:
    core_keys = {item.lower() for item in core}
    structured_helpful = [item for item in helpful if item.lower() not in core_keys]
    higher_keys = core_keys | {item.lower() for item in structured_helpful}
    structured_advanced = [item for item in advanced if item.lower() not in higher_keys]
    return {
        "core": core,
        "helpful": structured_helpful,
        "advanced": structured_advanced,
        "all": core + structured_helpful + structured_advanced,
        "core_count": len(core),
        "helpful_count": len(structured_helpful),
        "advanced_count": len(structured_advanced),
    }


def _cross_band_duplicates(
    core: list[str],
    helpful: list[str],
    advanced: list[str],
) -> list[str]:
    seen: set[str] = set()
    duplicates: list[str] = []
    for item in (*core, *helpful, *advanced):
        key = item.lower()
        if key in seen and item not in duplicates:
            duplicates.append(item)
        seen.add(key)
    return duplicates


def structure_prerequisites(
    core: list[str] | None = None,
    helpful: list[str] | None = None,
    advanced: list[str] | None = None,
) -> dict:
    """
    Structure prerequisite lists supplied by the Prerequisite Agent.

    The LLM decides which concepts belong in each band.
    This tool only normalises, deduplicates, and records them.
    """

    core_d, helpful_d, advanced_d = _deduped_bands(core, helpful, advanced)
    return _structure_from_bands(core_d, helpful_d, advanced_d)


def build_prerequisite_dependencies(
    ordered_prerequisites: list[str] | None = None,
    edges: list[list[str]] | None = None,
) -> dict:
    """
    Structure a dependency sequence supplied by the Prerequisite Agent.

    The LLM decides the learning order. This tool does not invent
    relationships; it records the supplied order and optional edges.
    """

    sequence = _dedupe(ordered_prerequisites)
    structured_edges: list[dict[str, str]] = []
    invalid_edges: list[str] = []

    for edge in edges or []:
        if not isinstance(edge, list) or len(edge) != 2:
            invalid_edges.append(str(edge))
            continue
        before = _normalise_item(edge[0])
        after = _normalise_item(edge[1])
        if not before or not after or before.lower() == after.lower():
            invalid_edges.append(str(edge))
            continue
        structured_edges.append({"before": before, "after": after})

    arrow_path = " -> ".join(sequence) if sequence else ""

    return {
        "sequence": sequence,
        "edges": structured_edges,
        "arrow_path": arrow_path,
        "invalid_edges": invalid_edges,
        "sequence_count": len(sequence),
    }


def identify_prerequisite_gaps(
    required_prerequisites: list[str],
    known_prerequisites: list[str] | None = None,
) -> dict:
    """
    Compare required prerequisites with knowledge already attributed
    to the learner. Does not infer extra knowledge.
    """

    required = _dedupe(required_prerequisites)

    if not known_prerequisites:
        return {
            "known": [],
            "mastered": [],
            "missing": required,
            "completion_percentage": 0.0,
            "status": "Learner knowledge not provided",
            "gaps_computed": True,
        }

    known_list = _dedupe(known_prerequisites)
    known = {item.lower() for item in known_list}

    mastered = []
    missing = []
    for item in required:
        if item.lower() in known:
            mastered.append(item)
        else:
            missing.append(item)

    completion_percentage = (
        round(len(mastered) / len(required) * 100, 1) if required else 100.0
    )

    return {
        "known": known_list,
        "mastered": mastered,
        "missing": missing,
        "completion_percentage": completion_percentage,
        "status": "Knowledge comparison completed",
        "gaps_computed": True,
    }


def validate_prerequisite_analysis(
    core: list[str] | None = None,
    helpful: list[str] | None = None,
    advanced: list[str] | None = None,
    sequence: list[str] | None = None,
    gaps_computed: bool = False,
) -> dict:
    """
    Validate a prerequisite analysis after the LLM has proposed it.

    Checks emptiness, duplicates, invalid priority labels, and whether
    gap analysis was run. Does not generate prerequisite knowledge.
    """

    issues: list[str] = []
    core_d, helpful_d, advanced_d = _deduped_bands(core, helpful, advanced)
    structured = _structure_from_bands(core_d, helpful_d, advanced_d)

    if not structured["all"]:
        issues.append("No prerequisites were supplied.")

    duplicates = _cross_band_duplicates(core_d, helpful_d, advanced_d)
    if duplicates:
        issues.append(
            "Duplicate concepts across priority bands: " + ", ".join(duplicates)
        )

    sequence_items = _dedupe(sequence)
    structured_keys = {item.lower() for item in structured["all"]}
    unknown_in_sequence = [
        item for item in sequence_items if item.lower() not in structured_keys
    ]
    if unknown_in_sequence:
        issues.append(
            "Dependency sequence contains concepts not in the "
            "structured lists: " + ", ".join(unknown_in_sequence)
        )

    if sequence_items and not structured["all"]:
        issues.append("A dependency sequence was supplied without prerequisites.")

    if not gaps_computed:
        issues.append("Gap analysis has not been computed.")

    return {
        "valid": len(issues) == 0,
        "issues": issues,
        "priorities_allowed": _PRIORITIES_ALLOWED,
        "structured": structured,
        "sequence": sequence_items,
        "gaps_computed": gaps_computed,
    }
