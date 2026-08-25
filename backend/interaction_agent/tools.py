from __future__ import annotations

import json
import re
from typing import Any

from google.adk.tools.tool_context import ToolContext

MAX_TURNS = 8
MAX_TURN_CHARS = 280
MAX_UPCOMING = 2

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
        "do",
        "does",
        "did",
        "you",
        "me",
        "my",
        "we",
        "what",
        "why",
        "how",
    }
)
_WORD_RE = re.compile(r"[a-z0-9]+(?:'[a-z]+)?", re.IGNORECASE)
_STUDENT_ROLES = frozenset({"student", "user", "human", "learner"})
_TEACHER_ROLES = frozenset({"teacher", "model", "assistant", "agent"})

# First matching type wins. More specific patterns come first so
# "show me" is not classified as conceptual via the letters "how".
_QUESTION_TYPES: tuple[tuple[str, re.Pattern[str], str, bool], ...] = (
    (
        "comparison",
        re.compile(
            r"\b(difference between|differ(?:ence)?|compare|versus|vs\.?|same as)\b",
            re.IGNORECASE,
        ),
        "compare_from_package",
        True,
    ),
    (
        "procedure",
        re.compile(
            r"\b(how do i|how to|how can i|steps?(?: to)?|calculate|work out)\b",
            re.IGNORECASE,
        ),
        "worked_steps_from_package",
        True,
    ),
    (
        "clarification",
        re.compile(
            r"\b(don'?t understand|confused|what do you mean|say that again|"
            r"slower|simpler|too fast|lost me)\b",
            re.IGNORECASE,
        ),
        "simplify_previous_point",
        False,
    ),
    (
        "misconception",
        re.compile(
            r"\b(but i thought|i thought|isn'?t it just|doesn'?t that mean|"
            r"so it'?s just|always true)\b",
            re.IGNORECASE,
        ),
        "correct_with_package",
        True,
    ),
    (
        "example_request",
        re.compile(
            r"\b(examples?|for instance|show me|worked example|illustrate)\b",
            re.IGNORECASE,
        ),
        "give_example",
        True,
    ),
    (
        "definition",
        re.compile(
            r"\b(what is|what'?s|whats|define|definition of|meaning of|mean by)\b",
            re.IGNORECASE,
        ),
        "define_from_package",
        True,
    ),
    (
        "conceptual",
        re.compile(
            r"\b(why|how come|how does|how is|how are|what happens|"
            r"what would happen|mechanism)\b",
            re.IGNORECASE,
        ),
        "explain_mechanism",
        True,
    ),
    (
        "check_understanding",
        re.compile(
            r"\b(so you(?:'re| are) saying|is it that|wait so|does that mean)\b",
            re.IGNORECASE,
        ),
        "confirm_or_correct",
        True,
    ),
    (
        "follow_up",
        re.compile(r"\b(earlier|you said|still|again|also)\b", re.IGNORECASE),
        "connect_to_recent_turn",
        True,
    ),
)

_MOVE_GENERAL = "answer_briefly_then_check"
_MOVE_EMPTY = "ask_student_to_restate"


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


def _score(text: str, question_tokens: set[str]) -> int:
    if not question_tokens:
        return 0
    overlap = question_tokens.intersection(_tokens(text))
    return len(overlap)


def classify_student_question(question: str) -> dict[str, Any]:
    """
    Classify a student question by intent.

    Does not answer the question. Uses word-boundary cues so
    phrases like "show me" are not treated as "how".
    """

    cleaned = _normalise(question)
    if not cleaned:
        return {
            "type": "empty",
            "confidence": "high",
            "cues": [],
            "needs_verified_fact": False,
            "suggested_move": _MOVE_EMPTY,
            "question": "",
        }

    for question_type, pattern, move, needs_fact in _QUESTION_TYPES:
        match = pattern.search(cleaned)
        if match:
            return {
                "type": question_type,
                "confidence": "high",
                "cues": [match.group(0).lower()],
                "needs_verified_fact": needs_fact,
                "suggested_move": move,
                "question": cleaned,
            }

    return {
        "type": "general_question",
        "confidence": "low",
        "cues": [],
        "needs_verified_fact": True,
        "suggested_move": _MOVE_GENERAL,
        "question": cleaned,
    }


def _sequence(lesson_plan: Any) -> list[dict[str, Any]]:
    data = _as_data(lesson_plan)
    if isinstance(data, dict):
        raw = data.get("lesson_sequence") or data.get("steps") or []
    elif isinstance(data, list):
        raw = data
    else:
        return []
    return [item for item in raw if isinstance(item, dict)]


def _slides(slides: Any) -> list[dict[str, Any]]:
    data = _as_data(slides)
    if isinstance(data, dict):
        raw = data.get("slides") or []
    elif isinstance(data, list):
        raw = data
    else:
        return []
    return [item for item in raw if isinstance(item, dict)]


def _compact_step(item: dict[str, Any] | None) -> dict[str, Any] | None:
    if not item:
        return None
    concepts = [
        _normalise(concept)
        for concept in (item.get("concepts") or [])
        if _normalise(concept)
    ]
    return {
        "step": item.get("step"),
        "title": _normalise(item.get("title")),
        "purpose": _normalise(item.get("purpose")) or None,
        "concepts": concepts,
    }


def _current_index(lesson_state: Any, sequence: list[dict[str, Any]]) -> int:
    data = _as_data(lesson_state)
    if not sequence:
        return 0
    if not isinstance(data, dict):
        return 0
    step = data.get("current_step") or data.get("step")
    if isinstance(step, int) and step >= 1:
        return min(step - 1, len(sequence) - 1)
    if isinstance(step, str) and step.strip().isdigit():
        return min(int(step.strip()) - 1, len(sequence) - 1)
    title = _normalise(data.get("current_title") or data.get("title"))
    if title:
        lowered = title.lower()
        for index, item in enumerate(sequence):
            if _normalise(item.get("title")).lower() == lowered:
                return index
    return 0


def _step_text(item: dict[str, Any]) -> str:
    concepts = item.get("concepts") or []
    return " ".join(
        [
            _normalise(item.get("title")),
            _normalise(item.get("purpose")),
            " ".join(_normalise(concept) for concept in concepts),
        ]
    )


def _package_text(package: Any) -> str:
    data = _as_data(package)
    if isinstance(data, dict):
        parts = [
            _normalise(data.get("topic")),
            " ".join(_normalise(item) for item in (data.get("key_concepts") or [])),
            " ".join(_normalise(item) for item in (data.get("misconceptions") or [])),
        ]
        for claim in data.get("claims") or []:
            if isinstance(claim, dict):
                parts.append(_normalise(claim.get("claim")))
            else:
                parts.append(_normalise(claim))
        return " ".join(part for part in parts if part)
    return _normalise(data)


def _profile_level(learner_profile: Any) -> str | None:
    data = _as_data(learner_profile)
    if isinstance(data, dict):
        for key in ("education_level", "level", "Education Level", "Level"):
            text = _normalise(data.get(key))
            if text:
                return text
        return None
    text = _normalise(data)
    return text or None


def _alignment(
    question: str,
    sequence: list[dict[str, Any]],
    index: int,
    package: Any,
) -> dict[str, Any]:
    tokens = _tokens(question)
    if not tokens:
        return {
            "in_current_step": False,
            "already_taught": False,
            "in_upcoming": False,
            "in_package": False,
            "guidance": "answer_from_current_step",
        }

    current = sequence[index] if sequence else None
    in_current = bool(current and _score(_step_text(current), tokens))
    already = any(_score(_step_text(item), tokens) for item in sequence[:index])
    upcoming = any(_score(_step_text(item), tokens) for item in sequence[index + 1 :])
    in_package = bool(_score(_package_text(package), tokens))

    if in_current:
        guidance = "answer_here"
    elif already:
        guidance = "brief_recall"
    elif upcoming and in_package:
        guidance = "preview_lightly_or_defer"
    elif in_package:
        guidance = "answer_from_package"
    else:
        guidance = "outside_verified_knowledge"

    return {
        "in_current_step": in_current,
        "already_taught": already,
        "in_upcoming": upcoming,
        "in_package": in_package,
        "guidance": guidance,
    }


def match_lesson_state(
    question: str = "",
    lesson_state: Any = None,
    lesson_plan: Any = None,
    slides: Any = None,
    research_package: Any = None,
    learner_profile: Any = None,
) -> dict[str, Any]:
    """Compact current lesson position. Does not dump the full plan."""

    sequence = _sequence(lesson_plan)
    slide_list = _slides(slides)
    if not sequence and not slide_list and not _as_data(lesson_state):
        return {
            "status": "error",
            "message": "No lesson state in session.",
        }

    index = _current_index(lesson_state, sequence)
    current = sequence[index] if sequence else None
    upcoming = [
        _compact_step(item) for item in sequence[index + 1 : index + 1 + MAX_UPCOMING]
    ]
    state = _as_data(lesson_state) if isinstance(_as_data(lesson_state), dict) else {}
    slide_number = None
    if isinstance(state, dict):
        slide_number = state.get("current_slide") or state.get("slide")
    current_slide = None
    if slide_list:
        if isinstance(slide_number, int) and 1 <= slide_number <= len(slide_list):
            current_slide = slide_list[slide_number - 1]
        elif current:
            title = _normalise(current.get("title")).lower()
            for item in slide_list:
                if title and title in _normalise(item.get("title")).lower():
                    current_slide = item
                    break
            if current_slide is None:
                current_slide = slide_list[min(index, len(slide_list) - 1)]

    result = {
        "status": "success",
        "current_step": _compact_step(current),
        "upcoming_steps": upcoming,
        "completed_steps": index,
        "remaining_steps": max(len(sequence) - index - 1, 0) if sequence else 0,
        "total_steps": len(sequence),
        "current_slide": {
            "number": current_slide.get("slide_number") or current_slide.get("number"),
            "title": _normalise(current_slide.get("title")),
        }
        if current_slide
        else None,
        "education_level": _profile_level(learner_profile),
    }
    if _normalise(question):
        result["alignment"] = _alignment(question, sequence, index, research_package)
    return result


def retrieve_current_lesson_state(
    question: str = "",
    tool_context: ToolContext | None = None,
) -> dict[str, Any]:
    """
    Return the compact current lesson position from session state.

    Optionally align a student question with the current step and
    verified package. Does not return the full lesson plan.
    """

    state = _session_state(tool_context)
    return match_lesson_state(
        question=question,
        lesson_state=state.get("lesson_state"),
        lesson_plan=state.get("lesson_plan"),
        slides=state.get("slides"),
        research_package=state.get("research_package"),
        learner_profile=state.get("learner_profile"),
    )


def _role(value: Any) -> str:
    raw = _normalise(value).lower()
    if raw in _STUDENT_ROLES:
        return "student"
    if raw in _TEACHER_ROLES:
        return "teacher"
    if raw in {"system"}:
        return "system"
    return raw or "unknown"


def _clip(text: str) -> str:
    if len(text) <= MAX_TURN_CHARS:
        return text
    return text[: MAX_TURN_CHARS - 1].rstrip() + "…"


def _turn(role: Any, text: Any) -> dict[str, str] | None:
    cleaned = _normalise(text)
    if not cleaned:
        return None
    return {"role": _role(role), "text": _clip(cleaned)}


def _turns_from_history(history: Any) -> list[dict[str, str]]:
    data = _as_data(history)
    if data is None:
        return []
    if isinstance(data, dict):
        data = data.get("turns") or data.get("messages") or data.get("history") or []
    if not isinstance(data, list):
        turn = _turn("student", data)
        return [turn] if turn else []
    turns: list[dict[str, str]] = []
    for item in data:
        if isinstance(item, dict):
            turn = _turn(
                item.get("role") or item.get("author") or item.get("speaker"),
                item.get("text")
                or item.get("content")
                or item.get("message")
                or item.get("parts"),
            )
        else:
            turn = _turn("unknown", item)
        if turn:
            turns.append(turn)
    return turns


def _event_text(event: Any) -> str:
    if event is None:
        return ""
    content = getattr(event, "content", None)
    if content is None and isinstance(event, dict):
        content = event.get("content") or event.get("text")
    if isinstance(content, str):
        return _normalise(content)
    parts = getattr(content, "parts", None) if content is not None else None
    if parts is None and isinstance(content, dict):
        parts = content.get("parts")
        if not parts:
            return _normalise(content.get("text"))
    if not parts:
        text = getattr(content, "text", None) if content is not None else None
        if text:
            return _normalise(text)
        return _normalise(getattr(event, "text", None))
    chunks: list[str] = []
    for part in parts:
        if isinstance(part, str):
            chunks.append(part)
            continue
        text = getattr(part, "text", None)
        if text is None and isinstance(part, dict):
            text = part.get("text")
        if text:
            chunks.append(str(text))
    return _normalise(" ".join(chunks))


def _turns_from_events(session: Any) -> list[dict[str, str]]:
    events = getattr(session, "events", None) if session is not None else None
    if not events:
        return []
    turns: list[dict[str, str]] = []
    for event in events:
        text = _event_text(event)
        if not text:
            continue
        author = getattr(event, "author", None)
        if author is None and isinstance(event, dict):
            author = event.get("author") or event.get("role")
        turn = _turn(author or "unknown", text)
        if turn:
            turns.append(turn)
    return turns


def match_conversation_context(
    question: str = "",
    conversation_history: Any = None,
    session: Any = None,
) -> dict[str, Any]:
    """Recent turns only. Does not dump the full transcript."""

    turns = _turns_from_history(conversation_history)
    if not turns:
        turns = _turns_from_events(session)

    cleaned_question = _normalise(question)
    if (
        cleaned_question
        and turns
        and turns[-1]["role"] == "student"
        and turns[-1]["text"].lower() == cleaned_question.lower()
    ):
        turns = turns[:-1]

    recent = turns[-MAX_TURNS:]
    question_tokens = _tokens(cleaned_question)
    needed = 1 if len(question_tokens) <= 2 else 2
    teacher_text = " ".join(
        item["text"] for item in recent if item["role"] == "teacher"
    )
    student_text = " ".join(
        item["text"] for item in recent if item["role"] == "student"
    )
    already_addressed = bool(
        question_tokens and _score(teacher_text, question_tokens) >= needed
    )
    repeated_question = bool(
        question_tokens and _score(student_text, question_tokens) >= needed
    )
    confusion = bool(
        re.search(
            r"\b(don'?t understand|confused|lost|too fast)\b",
            student_text,
            re.IGNORECASE,
        )
    )
    return {
        "status": "success",
        "recent_interactions": recent,
        "turn_count": len(recent),
        "already_addressed": already_addressed,
        "repeated_question": repeated_question,
        "student_confusion": confusion,
    }


def retrieve_conversation_context(
    question: str = "",
    tool_context: ToolContext | None = None,
) -> dict[str, Any]:
    """
    Return recent student-teacher turns from session state.

    Truncates history. Does not answer the question.
    """

    state = _session_state(tool_context)
    session = getattr(tool_context, "session", None) if tool_context else None
    return match_conversation_context(
        question=question,
        conversation_history=state.get("conversation_history"),
        session=session,
    )
