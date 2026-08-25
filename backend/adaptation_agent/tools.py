from __future__ import annotations

import json
import re
from typing import Any

from google.adk.tools.tool_context import ToolContext

LEARNER_STATES = (
    "struggling",
    "developing",
    "mastering",
    "missing_prerequisite",
    "ready_for_increase",
    "unknown",
)

ACTIONS = (
    "simplify",
    "revisit_prerequisite",
    "provide_analogy",
    "provide_example",
    "ask_diagnostic",
    "slow_down",
    "increase_difficulty",
    "move_forward",
)

_CONFUSION_RE = re.compile(
    r"\b(don'?t understand|confused|lost|too fast|stuck|no idea)\b",
    re.IGNORECASE,
)
_STATE_ALIASES: tuple[tuple[str, tuple[str, ...]], ...] = (
    (
        "missing_prerequisite",
        ("missing prerequisite", "prerequisite", "knowledge gap", "gap"),
    ),
    (
        "ready_for_increase",
        ("ready", "increase", "stretch", "more difficult", "harder"),
    ),
    ("struggling", ("struggling", "stuck", "confused", "lost", "failing")),
    ("developing", ("developing", "partial", "mixed", "some understanding")),
    ("mastering", ("mastering", "mastered", "fluent", "confident", "secure")),
    ("unknown", ("unknown", "unclear", "not sure")),
)
_ACTION_COPY: dict[str, str] = {
    "simplify": "Simplify the current explanation. Stay on this step.",
    "revisit_prerequisite": (
        "Revisit the missing prerequisite before continuing the current concept."
    ),
    "provide_analogy": "Give a short analogy, then return to the current concept.",
    "provide_example": "Give another example and check understanding.",
    "ask_diagnostic": (
        "Ask a diagnostic question before changing difficulty or moving on."
    ),
    "slow_down": "Slow down. Break the current idea into smaller steps.",
    "increase_difficulty": (
        "Increase conceptual difficulty slightly. Do not skip ahead in the sequence."
    ),
    "move_forward": "The learner is ready for the next lesson step.",
}
_STATE_ACTION: dict[str, str] = {
    "struggling": "simplify",
    "developing": "provide_example",
    "mastering": "move_forward",
    "missing_prerequisite": "revisit_prerequisite",
    "ready_for_increase": "increase_difficulty",
    "unknown": "ask_diagnostic",
}


def _normalise(value: Any) -> str:
    return " ".join(str(value or "").split()).strip()


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


def _dedupe(items: list[str] | None) -> list[str]:
    unique: list[str] = []
    seen: set[str] = set()
    for item in items or []:
        cleaned = _normalise(item)
        if not cleaned:
            continue
        key = cleaned.lower()
        if key in seen:
            continue
        seen.add(key)
        unique.append(cleaned)
    return unique


def _as_list(value: Any) -> list[str]:
    data = _as_data(value)
    if data is None:
        return []
    if isinstance(data, str):
        parts = [part.strip() for part in re.split(r"[,;\n]", data) if part.strip()]
        return _dedupe(parts or [data])
    if isinstance(data, dict):
        for key in ("missing", "required", "concepts", "mastered", "known", "items"):
            if key in data:
                return _as_list(data[key])
        return _dedupe([str(item) for item in data.values() if isinstance(item, str)])
    if isinstance(data, list):
        flat: list[str] = []
        for item in data:
            if isinstance(item, dict):
                flat.append(
                    _normalise(
                        item.get("concept") or item.get("name") or item.get("title")
                    )
                )
            else:
                flat.append(_normalise(item))
        return _dedupe(flat)
    return _dedupe([str(data)])


def _ratio(data: dict[str, Any]) -> float | None:
    if "percentage" in data and data["percentage"] is not None:
        try:
            value = float(data["percentage"])
        except (TypeError, ValueError):
            return None
        return value / 100.0 if value > 1 else value
    if "score" in data and data["score"] is not None:
        try:
            score = float(data["score"])
        except (TypeError, ValueError):
            return None
        maximum = data.get("max") or data.get("total") or data.get("out_of")
        if maximum in (None, ""):
            return score / 100.0 if score > 1 else score
        try:
            maximum_f = float(maximum)
        except (TypeError, ValueError):
            return None
        return score / maximum_f if maximum_f else None
    if data.get("total") not in (None, "") and data.get("correct") is not None:
        try:
            total = float(data["total"])
            correct = float(data["correct"])
        except (TypeError, ValueError):
            return None
        return correct / total if total else None
    return None


def _count_checks(data: dict[str, Any]) -> tuple[int, int]:
    passed = 0
    failed = 0
    checks = data.get("checks") or data.get("concept_checks") or []
    if isinstance(checks, list):
        for item in checks:
            if isinstance(item, dict):
                ok = item.get("passed")
                if ok is None:
                    ok = item.get("correct")
                if ok is True:
                    passed += 1
                elif ok is False:
                    failed += 1
            elif str(item).lower() in {"pass", "passed", "correct", "true"}:
                passed += 1
            elif str(item).lower() in {"fail", "failed", "incorrect", "false"}:
                failed += 1
    if data.get("checks_passed") is not None:
        try:
            passed = int(data["checks_passed"])
        except (TypeError, ValueError):
            pass
    if data.get("checks_failed") is not None:
        try:
            failed = int(data["checks_failed"])
        except (TypeError, ValueError):
            pass
    return passed, failed


def _boolish(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    return str(value or "").strip().lower() in {"true", "yes", "1"}


def _scan_confusion(*blobs: Any) -> bool:
    for blob in blobs:
        data = _as_data(blob)
        if isinstance(data, dict) and (
            _boolish(data.get("confusion")) or _boolish(data.get("student_confusion"))
        ):
            return True
        if _CONFUSION_RE.search(_normalise(data)):
            return True
        if isinstance(data, list):
            for item in data:
                if _scan_confusion(item):
                    return True
        elif isinstance(data, dict):
            text = " ".join(
                _normalise(data.get(key))
                for key in ("text", "content", "message", "reply")
            )
            if _CONFUSION_RE.search(text):
                return True
    return False


def summarise_performance(
    performance: Any = None,
    lesson_state: Any = None,
    conversation_history: Any = None,
    interaction: Any = None,
) -> dict[str, Any]:
    """Compact learner-performance signals. Does not dump raw records."""

    chunks = [
        _as_data(item)
        for item in (performance, lesson_state, interaction)
        if item is not None
    ]
    merged: dict[str, Any] = {}
    for chunk in chunks:
        if isinstance(chunk, dict):
            merged.update(chunk)

    score = _ratio(merged) if merged else None
    passed, failed = _count_checks(merged) if merged else (0, 0)
    attempts = merged.get("attempts") if merged else None
    try:
        attempts_n = int(attempts) if attempts is not None else passed + failed
    except (TypeError, ValueError):
        attempts_n = passed + failed
    last_check = _normalise(merged.get("last_check") if merged else "")
    if last_check.lower() in {"pass", "passed", "correct"}:
        last = "pass"
    elif last_check.lower() in {"fail", "failed", "incorrect"} or failed and not passed:
        last = "fail"
    elif passed and not failed:
        last = "pass"
    else:
        last = None

    confusion = _scan_confusion(
        merged, conversation_history, interaction, performance, lesson_state
    )
    repeated = False
    interaction_data = _as_data(interaction)
    if isinstance(interaction_data, dict):
        repeated = _boolish(interaction_data.get("repeated_question"))
    if isinstance(merged, dict):
        repeated = repeated or _boolish(merged.get("repeated_question"))

    signals: list[str] = []
    if confusion:
        signals.append("confusion")
    if repeated:
        signals.append("repeated_question")
    if last == "fail" or failed > passed:
        signals.append("failed_check")
    if score is not None and score < 0.4:
        signals.append("low_score")
    elif score is not None and score >= 0.8:
        signals.append("high_score")
    if attempts_n >= 3 and (failed or confusion):
        signals.append("multiple_attempts")

    has_evidence = bool(
        merged or _as_data(conversation_history) or _as_data(interaction)
    )
    return {
        "status": "success" if has_evidence else "unknown",
        "score": None if score is None else round(score, 3),
        "checks_passed": passed,
        "checks_failed": failed,
        "attempts": attempts_n,
        "last_check": last,
        "confusion": confusion,
        "repeated_question": repeated,
        "signals": signals,
        "demonstrated_concepts": _as_list(
            (merged or {}).get("demonstrated_concepts")
            or (merged or {}).get("mastered_concepts")
        ),
    }


def retrieve_learner_performance(
    tool_context: ToolContext | None = None,
) -> dict[str, Any]:
    """
    Pull compact performance signals from session state.

    Does not echo the raw performance blob and does not decide
    the teaching move.
    """

    state = _session_state(tool_context)
    summary = summarise_performance(
        performance=state.get("performance") or state.get("learner_performance"),
        lesson_state=state.get("lesson_state"),
        conversation_history=state.get("conversation_history"),
        interaction=state.get("interaction"),
    )
    if tool_context is not None and isinstance(
        getattr(tool_context, "state", None), dict
    ):
        tool_context.state["learner_performance"] = summary
    return summary


def match_knowledge_gaps(
    required_concepts: Any = None,
    demonstrated_concepts: Any = None,
    prerequisite_analysis: Any = None,
    learning_objectives: Any = None,
    lesson_plan: Any = None,
    lesson_state: Any = None,
    performance: Any = None,
) -> dict[str, Any]:
    """Compare required vs demonstrated concepts. Does not invent gaps."""

    analysis = _as_data(prerequisite_analysis)
    required = _as_list(required_concepts)
    demonstrated = _as_list(demonstrated_concepts)

    if not required and isinstance(analysis, dict):
        required = _as_list(analysis.get("core") or analysis.get("required"))
        if not required:
            required = _as_list(analysis.get("all"))
    if not required:
        required = _as_list(learning_objectives)
    if not required:
        plan = _as_data(lesson_plan)
        sequence = []
        if isinstance(plan, dict):
            sequence = plan.get("lesson_sequence") or plan.get("steps") or []
        elif isinstance(plan, list):
            sequence = plan
        current = (
            _as_data(lesson_state) if isinstance(_as_data(lesson_state), dict) else {}
        )
        step_n = 0
        if isinstance(current, dict):
            step_n = int(current.get("current_step") or current.get("step") or 1) - 1
        if (
            sequence
            and 0 <= step_n < len(sequence)
            and isinstance(sequence[step_n], dict)
        ):
            required = _as_list(sequence[step_n].get("concepts"))

    if not demonstrated and isinstance(analysis, dict):
        demonstrated = _as_list(analysis.get("mastered") or analysis.get("known"))
    if not demonstrated:
        demonstrated = _as_list(
            (_as_data(performance) or {}).get("demonstrated_concepts")
            if isinstance(_as_data(performance), dict)
            else None
        )

    known = {item.lower() for item in demonstrated}
    mastered = [item for item in required if item.lower() in known]
    missing = [item for item in required if item.lower() not in known]
    extra = [
        item
        for item in demonstrated
        if item.lower() not in {r.lower() for r in required}
    ]
    analysis_missing = (
        _as_list(analysis.get("missing")) if isinstance(analysis, dict) else []
    )
    for item in analysis_missing:
        if item.lower() not in {m.lower() for m in missing}:
            missing.append(item)

    total = len(required) or (len(mastered) + len(missing))
    completion = round(len(mastered) / total * 100, 1) if total else None
    if not required and not demonstrated and not analysis_missing:
        return {
            "status": "unknown",
            "message": "No required or demonstrated concepts provided.",
            "missing_concepts": [],
            "mastered_concepts": [],
            "gap_count": 0,
            "completion_percentage": None,
        }
    return {
        "status": "success",
        "missing_concepts": missing,
        "mastered_concepts": mastered,
        "demonstrated_concepts": demonstrated,
        "unlisted_demonstrated": extra,
        "gap_count": len(missing),
        "completion_percentage": completion if completion is not None else 0.0,
    }


def identify_knowledge_gap(
    required_concepts: list[str] | str | None = None,
    demonstrated_concepts: list[str] | str | None = None,
    tool_context: ToolContext | None = None,
) -> dict[str, Any]:
    """
    Identify missing concepts from supplied lists or session state.

    Does not infer extra knowledge. Safe when lists are omitted.
    """

    state = _session_state(tool_context)
    result = match_knowledge_gaps(
        required_concepts=required_concepts,
        demonstrated_concepts=demonstrated_concepts,
        prerequisite_analysis=state.get("prerequisite_analysis"),
        learning_objectives=state.get("learning_objectives"),
        lesson_plan=state.get("lesson_plan"),
        lesson_state=state.get("lesson_state"),
        performance=state.get("performance") or state.get("learner_performance"),
    )
    if tool_context is not None and isinstance(
        getattr(tool_context, "state", None), dict
    ):
        tool_context.state["knowledge_gaps"] = result
    return result


def _normalise_state(learner_state: str) -> str:
    text = _normalise(learner_state).lower()
    if not text:
        return ""
    if text in LEARNER_STATES:
        return text
    for state, aliases in _STATE_ALIASES:
        for alias in aliases:
            if re.search(rf"\b{re.escape(alias)}\b", text):
                return state
    return ""


def _infer_state(performance: dict[str, Any], gaps: dict[str, Any]) -> str:
    missing = gaps.get("missing_concepts") or []
    signals = set(performance.get("signals") or [])
    score = performance.get("score")
    if missing and (
        "confusion" in signals
        or "failed_check" in signals
        or "low_score" in signals
        or performance.get("status") == "unknown"
    ):
        return "missing_prerequisite"
    if missing and score is not None and score < 0.6:
        return "missing_prerequisite"
    if "confusion" in signals or "failed_check" in signals or "low_score" in signals:
        return "struggling"
    if score is not None and score >= 0.8 and not missing:
        if "high_score" in signals:
            return "ready_for_increase"
        return "mastering"
    if score is not None and 0.4 <= score < 0.8:
        return "developing"
    if performance.get("last_check") == "pass" and not missing and not signals:
        return "mastering"
    if performance.get("status") == "unknown" and not missing:
        return "unknown"
    if missing:
        return "missing_prerequisite"
    if performance.get("status") == "success" and not signals:
        return "developing"
    return "unknown"


def decide_adaptation(
    learner_state: str = "",
    performance: dict[str, Any] | None = None,
    gaps: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Map evidence to one closed-set teaching adaptation."""

    performance = performance or {
        "status": "unknown",
        "signals": [],
        "score": None,
        "confusion": False,
    }
    gaps = gaps or {
        "missing_concepts": [],
        "gap_count": 0,
        "status": "unknown",
    }
    state = _normalise_state(learner_state) or _infer_state(performance, gaps)
    action = _STATE_ACTION.get(state, "ask_diagnostic")
    signals = list(performance.get("signals") or [])
    missing = list(gaps.get("missing_concepts") or [])

    if (
        state == "struggling"
        and "confusion" in signals
        and "multiple_attempts" in signals
    ):
        action = "slow_down"
    elif state == "struggling" and "repeated_question" in signals:
        action = "provide_analogy"
    elif state == "mastering" and not missing:
        action = "move_forward"
    elif state == "ready_for_increase" and missing:
        state = "missing_prerequisite"
        action = "revisit_prerequisite"

    stay = action not in {"move_forward", "increase_difficulty"}
    return {
        "status": "success",
        "learner_state": state,
        "action": action,
        "stay_on_step": stay,
        "increase_difficulty": action == "increase_difficulty",
        "revisit_concepts": missing[:6] if action == "revisit_prerequisite" else [],
        "recommendation": _ACTION_COPY[action],
        "signals": signals,
        "gap_count": gaps.get("gap_count") or len(missing),
    }


def recommend_adaptation(
    learner_state: str = "",
    tool_context: ToolContext | None = None,
) -> dict[str, Any]:
    """
    Recommend one teaching adaptation for the Teacher Agent.

    Infers learner_state from session evidence when it is omitted.
    Does not redesign the curriculum or invent content.
    """

    state = _session_state(tool_context)
    performance = state.get("learner_performance")
    if not isinstance(performance, dict) or performance.get("status") is None:
        performance = summarise_performance(
            performance=state.get("performance") or state.get("learner_performance"),
            lesson_state=state.get("lesson_state"),
            conversation_history=state.get("conversation_history"),
            interaction=state.get("interaction"),
        )
    gaps = state.get("knowledge_gaps")
    if not isinstance(gaps, dict) or "missing_concepts" not in gaps:
        gaps = match_knowledge_gaps(
            prerequisite_analysis=state.get("prerequisite_analysis"),
            learning_objectives=state.get("learning_objectives"),
            lesson_plan=state.get("lesson_plan"),
            lesson_state=state.get("lesson_state"),
            performance=state.get("performance") or performance,
        )
    result = decide_adaptation(
        learner_state=learner_state,
        performance=performance,
        gaps=gaps,
    )
    if tool_context is not None and isinstance(
        getattr(tool_context, "state", None), dict
    ):
        tool_context.state["adaptation"] = result
    return result
