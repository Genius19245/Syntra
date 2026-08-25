"""Rendering-layer image generation. Not used as an ADK tool.

The Slide Agent only emits a visual_asset spec (prompt, aspect_ratio,
educational_purpose). This module may attach a url when generation is
on and a Vertex client is available. Fail-soft: return the spec
without a url if generation is off or the model call fails.
"""

from __future__ import annotations

import base64
import hashlib
import logging
import os
from types import SimpleNamespace
from typing import Any

logger = logging.getLogger(__name__)

_UNSET = SimpleNamespace()

PROJECT_ID = os.environ.get("GOOGLE_CLOUD_PROJECT", "agenticsai2026")
DEFAULT_IMAGE_MODEL = "gemini-3.1-flash-image"
IMAGE_MODEL_FALLBACKS = (
    "gemini-3.1-flash-image",
    "gemini-2.5-flash-image",
)
DEFAULT_MAX_IMAGES = 2
DEFAULT_IMAGE_SIZE = "2K"

_CLIENT: Any = _UNSET
_FAILED_MODELS: set[str] = set()
_URL_BY_ASSET: dict[str, dict[str, Any]] = {}
_IMAGE_CONFIG_BY_RATIO: dict[str, Any] = {}


def _fail_soft_errors() -> tuple[type[BaseException], ...]:
    errors: list[type[BaseException]] = [
        AttributeError,
        ImportError,
        LookupError,
        OSError,
        OverflowError,
        RuntimeError,
        TypeError,
        ValueError,
    ]
    try:
        from google.genai.errors import APIError
    except ImportError:
        return tuple(errors)
    errors.append(APIError)
    return tuple(errors)


_FAIL_SOFT = _fail_soft_errors()


def image_generation_enabled() -> bool:
    return os.environ.get("SYNTRA_GENERATE_IMAGES", "").strip().lower() in {
        "1",
        "true",
        "yes",
    }


def image_model_name() -> str:
    return (
        os.environ.get("SYNTRA_IMAGE_MODEL", DEFAULT_IMAGE_MODEL).strip()
        or DEFAULT_IMAGE_MODEL
    )


def max_images_per_lesson() -> int:
    raw = os.environ.get("SYNTRA_IMAGE_MAX_PER_LESSON", str(DEFAULT_MAX_IMAGES))
    try:
        return max(0, min(8, int(raw)))
    except (TypeError, ValueError):
        return DEFAULT_MAX_IMAGES


def image_location() -> str:
    explicit = os.environ.get("SYNTRA_IMAGE_LOCATION", "").strip()
    if explicit:
        return explicit
    model = image_model_name()
    if model.startswith("imagen"):
        return "us-central1"
    return (
        os.environ.get("GOOGLE_CLOUD_LOCATION")
        or os.environ.get("VERTEX_LOCATION")
        or "global"
    )


def reset_image_client(client: Any = _UNSET) -> None:
    """Tests inject a fake client. Production never calls this."""

    global _CLIENT, _FAILED_MODELS
    _CLIENT = client
    _FAILED_MODELS = set()
    _URL_BY_ASSET.clear()
    _IMAGE_CONFIG_BY_RATIO.clear()


def image_client() -> Any | None:
    """Return a cached Vertex client, or None when generation is off."""

    global _CLIENT
    if _CLIENT is not _UNSET:
        return _CLIENT
    if not image_generation_enabled():
        return None
    try:
        from google.genai import Client

        _CLIENT = Client(
            vertexai=True,
            project=os.environ.get("GOOGLE_CLOUD_PROJECT", PROJECT_ID),
            location=image_location(),
        )
        return _CLIENT
    except _FAIL_SOFT:
        logger.debug("Image generation client is unavailable", exc_info=True)
        _CLIENT = None
        return None


def asset_id_for(prompt: str, educational_purpose: str) -> str:
    digest = hashlib.sha256(
        f"{prompt.strip()}\n{educational_purpose.strip()}".encode()
    ).hexdigest()[:16]
    return f"img_{digest}"


def materialize_image_asset(
    prompt: str,
    educational_purpose: str,
    aspect_ratio: str = "16:9",
) -> dict[str, Any]:
    """Build a stored image-asset spec. Generation is optional."""

    spec: dict[str, Any] = {
        "type": "ai_generated_image",
        "asset_id": asset_id_for(prompt, educational_purpose),
        "prompt": (prompt or "").strip(),
        "educational_purpose": (educational_purpose or "").strip(),
        "aspect_ratio": (aspect_ratio or "").strip() or "16:9",
        "status": "image_generation_requested",
        "url": None,
    }
    cached = _URL_BY_ASSET.get(spec["asset_id"])
    if cached:
        spec.update(cached)
        return spec
    if image_generation_enabled():
        generated = _generate(spec)
        if generated:
            spec.update(generated)
            _URL_BY_ASSET[spec["asset_id"]] = generated
    return spec


def _models_to_try() -> list[str]:
    primary = image_model_name()
    models = [primary]
    for name in IMAGE_MODEL_FALLBACKS:
        if name not in models:
            models.append(name)
    return models


def _render_prompt(spec: dict[str, Any]) -> str:
    purpose = spec.get("educational_purpose") or ""
    prompt = spec.get("prompt") or ""
    parts = [
        "Educational illustration for a classroom slide, viewed from several metres away.",
        "High contrast, large simple shapes, uncluttered composition.",
        "One clear subject filling the frame. Bright even lighting, sharp focus.",
        "Student-facing teaching visual. No tiny details.",
        "No text, no labels, no captions, no watermarks, no equations, no legends.",
    ]
    if purpose:
        parts.append(f"Purpose: {purpose}.")
    if prompt:
        parts.append(prompt)
    return " ".join(parts)


def _generate(spec: dict[str, Any]) -> dict[str, Any] | None:
    """Call the configured Gemini / Imagen model. Fail-soft."""

    client = image_client()
    if client is None:
        return None
    prompt = _render_prompt(spec)
    ratio = spec.get("aspect_ratio") or "16:9"
    for model in _models_to_try():
        if model in _FAILED_MODELS:
            continue
        try:
            if model.startswith("imagen"):
                data, mime = _from_imagen(client, model, prompt, ratio)
            else:
                data, mime = _from_gemini(client, model, prompt, ratio)
        except _FAIL_SOFT as exc:
            logger.debug("Image generation failed for model %s", model, exc_info=True)
            message = str(exc).lower()
            if "not found" in message or "404" in message or "not supported" in message:
                _FAILED_MODELS.add(model)
                continue
            return None
        if not data:
            continue
        encoded = base64.b64encode(data).decode("ascii")
        return {
            "url": f"data:{mime};base64,{encoded}",
            "status": "image_generated",
            "mime_type": mime,
            "model": model,
        }
    return None


def _gemini_image_config(aspect_ratio: str) -> Any:
    cached = _IMAGE_CONFIG_BY_RATIO.get(aspect_ratio)
    if cached is not None:
        return cached
    image_fields: dict[str, Any] = {
        "aspect_ratio": aspect_ratio,
        "image_size": DEFAULT_IMAGE_SIZE,
    }
    config: dict[str, Any] = {
        "response_modalities": ["IMAGE"],
        "image_config": image_fields,
    }
    try:
        from google.genai import types

        try:
            image_config = types.ImageConfig(**image_fields)
        except TypeError:
            image_config = types.ImageConfig(aspect_ratio=aspect_ratio)
        config = types.GenerateContentConfig(
            response_modalities=["IMAGE"],
            image_config=image_config,
        )
    except _FAIL_SOFT:
        logger.debug("Falling back to dict image config", exc_info=True)
    _IMAGE_CONFIG_BY_RATIO[aspect_ratio] = config
    return config


def _from_gemini(
    client: Any,
    model: str,
    prompt: str,
    aspect_ratio: str,
) -> tuple[bytes | None, str]:
    response = client.models.generate_content(
        model=model,
        contents=prompt,
        config=_gemini_image_config(aspect_ratio),
    )
    return _bytes_from_content(response)


def _from_imagen(
    client: Any,
    model: str,
    prompt: str,
    aspect_ratio: str,
) -> tuple[bytes | None, str]:
    response = client.models.generate_images(
        model=model,
        prompt=prompt,
        config={
            "number_of_images": 1,
            "aspect_ratio": aspect_ratio,
        },
    )
    images = getattr(response, "generated_images", None) or []
    if not images:
        return None, "image/png"
    image = getattr(images[0], "image", None)
    if image is None:
        return None, "image/png"
    data = getattr(image, "image_bytes", None)
    mime = getattr(image, "mime_type", None) or "image/png"
    if isinstance(data, str):
        data = base64.b64decode(data)
    if not isinstance(data, (bytes, bytearray)):
        return None, mime
    return bytes(data), mime


def _bytes_from_content(response: Any) -> tuple[bytes | None, str]:
    for part in _iter_parts(response):
        inline = getattr(part, "inline_data", None) or getattr(part, "inlineData", None)
        if inline is None:
            continue
        data = getattr(inline, "data", None)
        mime = (
            getattr(inline, "mime_type", None)
            or getattr(inline, "mimeType", None)
            or "image/png"
        )
        if data is None:
            continue
        if isinstance(data, str):
            data = base64.b64decode(data)
        if isinstance(data, (bytes, bytearray)) and data:
            return bytes(data), mime
    return None, "image/png"


def _iter_parts(response: Any):
    parts = getattr(response, "parts", None)
    if parts:
        yield from parts
        return
    for candidate in getattr(response, "candidates", None) or []:
        content = getattr(candidate, "content", None)
        yield from getattr(content, "parts", None) or []
