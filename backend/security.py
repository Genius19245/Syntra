"""Model Armor at the ADK model I/O boundary.

Not an agent. Screens the latest user turn before Gemini and the model
response after. Disabled when SYNTRA_MODEL_ARMOR_TEMPLATE is unset so local
runs keep working. This is a Python module, not an ADK app.
"""

from __future__ import annotations

import logging
import os
from typing import Any

from google.genai import types
from opentelemetry import trace

logger = logging.getLogger("syntra.security")

_MAX_SCREEN_CHARS = 24_000
_SAFE_REFUSAL = (
    "SYNTRA could not continue this turn because the text did not pass "
    "the safety screen. Please rephrase and try again."
)

_client = None


def template_configured() -> bool:
    return bool((os.getenv("SYNTRA_MODEL_ARMOR_TEMPLATE") or "").strip())


def _project() -> str:
    return (os.getenv("GOOGLE_CLOUD_PROJECT") or "").strip()


def _location() -> str:
    return (os.getenv("SYNTRA_MODEL_ARMOR_LOCATION") or "us-central1").strip()


def _template_name() -> str:
    template = (os.getenv("SYNTRA_MODEL_ARMOR_TEMPLATE") or "").strip()
    project = _project()
    location = _location()
    if template.startswith("projects/"):
        return template
    return f"projects/{project}/locations/{location}/templates/{template}"


def _client_or_none() -> Any:
    global _client
    if _client is not None:
        return _client
    if not template_configured() or not _project():
        return None
    try:
        from google.api_core.client_options import ClientOptions
        from google.cloud import modelarmor_v1

        location = _location()
        _client = modelarmor_v1.ModelArmorClient(
            transport="rest",
            client_options=ClientOptions(
                api_endpoint=f"modelarmor.{location}.rep.googleapis.com"
            ),
        )
        return _client
    except Exception:
        logger.exception("Model Armor client is unavailable")
        return None


def _content_text(content: Any) -> str:
    if content is None:
        return ""
    text = getattr(content, "text", None)
    if isinstance(text, str) and text.strip():
        return text.strip()
    parts = getattr(content, "parts", None) or []
    chunks: list[str] = []
    for part in parts:
        piece = getattr(part, "text", None)
        if isinstance(piece, str) and piece:
            chunks.append(piece)
    return "\n".join(chunks).strip()


def user_prompt_text(llm_request: Any) -> str:
    """Last user turn only. Do not send system instructions to Model Armor."""

    contents = getattr(llm_request, "contents", None) or []
    for content in reversed(list(contents)):
        role = str(getattr(content, "role", "") or "").lower()
        if role and role != "user":
            continue
        text = _content_text(content)
        if text:
            return text[:_MAX_SCREEN_CHARS]
    return ""


def model_response_text(llm_response: Any) -> str:
    return _content_text(getattr(llm_response, "content", None))[:_MAX_SCREEN_CHARS]


def _is_blocked(result: Any) -> bool:
    sanitization = getattr(result, "sanitization_result", None) or result
    state = getattr(sanitization, "filter_match_state", None)
    if state is None:
        return False
    name = str(getattr(state, "name", None) or state).upper()
    return "MATCH_FOUND" in name and "NO_MATCH" not in name


def _filter_count(result: Any) -> int:
    sanitization = getattr(result, "sanitization_result", None) or result
    filters = getattr(sanitization, "filter_results", None)
    if not filters:
        return 0
    if hasattr(filters, "values"):
        return len(list(filters.values()))
    try:
        return len(filters)
    except TypeError:
        return 0


def _record(decision: str, filter_count: int = 0) -> None:
    span = trace.get_current_span()
    if span is None or not span.is_recording():
        return
    span.set_attribute("model_armor.decision", decision)
    span.set_attribute("model_armor.filter_count", filter_count)


def _blocked_response():
    from google.adk.models.llm_response import LlmResponse

    return LlmResponse(
        content=types.Content(
            role="model",
            parts=[types.Part.from_text(text=_SAFE_REFUSAL)],
        ),
        error_code="MODEL_ARMOR_BLOCKED",
        error_message="Blocked by Model Armor.",
    )


def _sanitize_user_prompt(text: str) -> Any:
    from google.cloud import modelarmor_v1

    client = _client_or_none()
    if client is None:
        return None
    request = modelarmor_v1.SanitizeUserPromptRequest(
        name=_template_name(),
        user_prompt_data=modelarmor_v1.DataItem(text=text),
    )
    return client.sanitize_user_prompt(request=request)


def _sanitize_model_response(text: str) -> Any:
    from google.cloud import modelarmor_v1

    client = _client_or_none()
    if client is None:
        return None
    request = modelarmor_v1.SanitizeModelResponseRequest(
        name=_template_name(),
        model_response_data=modelarmor_v1.DataItem(text=text),
    )
    return client.sanitize_model_response(request=request)


def sanitize_before_model(callback_context: Any, llm_request: Any) -> Any:
    """ADK before_model_callback. Skip Gemini when the user turn is blocked."""

    del callback_context
    if not template_configured():
        return None
    text = user_prompt_text(llm_request)
    if not text:
        return None
    try:
        result = _sanitize_user_prompt(text)
    except Exception:
        logger.exception("Model Armor prompt screen failed")
        _record("error")
        return None
    if result is None:
        return None
    if _is_blocked(result):
        _record("blocked", _filter_count(result))
        return _blocked_response()
    _record("allow", _filter_count(result))
    return None


def sanitize_after_model(callback_context: Any, llm_response: Any) -> Any:
    """ADK after_model_callback. Replace a blocked model response."""

    del callback_context
    if not template_configured():
        return None
    text = model_response_text(llm_response)
    if not text:
        return None
    try:
        result = _sanitize_model_response(text)
    except Exception:
        logger.exception("Model Armor response screen failed")
        _record("error")
        return None
    if result is None:
        return None
    if _is_blocked(result):
        _record("blocked", _filter_count(result))
        return _blocked_response()
    _record("allow", _filter_count(result))
    return None


def reset_for_tests() -> None:
    global _client
    _client = None
