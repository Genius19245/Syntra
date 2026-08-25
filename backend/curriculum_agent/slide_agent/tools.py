import re
from typing import Any

from .image_assets import (
    image_generation_enabled,
    materialize_image_asset,
    max_images_per_lesson,
)

ALLOWED_VISUAL_TYPES = frozenset(
    {
        "none",
        "diagram",
        "ai_generated",
        "graph",
        "equation",
        "timeline",
        "comparison",
        "flowchart",
        "interactive",
    }
)

ALLOWED_DIFFICULTY = frozenset(
    {
        "foundation",
        "developing",
        "intermediate",
        "advanced",
        "exam_application",
    }
)

ALLOWED_ASPECT_RATIOS = frozenset({"16:9", "4:3", "1:1", "9:16"})

_PRECISION_RE = re.compile(
    r"\b(equations?|latex|scale bars?|numbered|measurements?|si units?)\b",
    re.IGNORECASE,
)
_LABEL_RE = re.compile(r"\b(labels?|labelled|labeled)\b", re.IGNORECASE)
_NO_LABEL_RE = re.compile(
    r"\b(no|without|un)[\s-]*labels?\b",
    re.IGNORECASE,
)


def _precision_warnings(prompt: str, slide_number: Any = None) -> list[str]:
    text = prompt or ""
    hits: list[str] = []
    if _PRECISION_RE.search(text):
        hits.append("equation/measurement marks")
    if _LABEL_RE.search(text) and not _NO_LABEL_RE.search(text):
        hits.append("labels")
    if not hits:
        return []
    where = f"Slide {slide_number}: " if slide_number is not None else ""
    return [
        (
            f"{where}AI image prompt asks for precise marks "
            f"({', '.join(hits)}). Use generate_diagram_spec or "
            "render_equation for those."
        )
    ]


def _clean(value: Any) -> str:
    return " ".join(str(value or "").split())


def _token(value: Any) -> str:
    return _clean(value).lower().replace(" ", "_")


def _visual_type(value: Any) -> str:
    visual_type = _token(value)
    if visual_type == "image":
        return "ai_generated"
    return visual_type


def _string_list(value: Any) -> list[str]:
    if isinstance(value, str):
        item = _clean(value)
        return [item] if item else []
    if not isinstance(value, list):
        return []
    seen: set[str] = set()
    items: list[str] = []
    for raw in value:
        item = _clean(raw)
        key = item.lower()
        if not item or key in seen:
            continue
        seen.add(key)
        items.append(item)
    return items


def generate_diagram_spec(
    diagram_type: str,
    subject: str,
    concepts: list[str] | None = None,
    description: str = "",
) -> dict[str, Any]:
    """
    Normalise a labelled-diagram specification.

    Local only. Does not render or fetch an image.
    """

    return {
        "type": "diagram",
        "diagram_type": _clean(diagram_type) or "concept",
        "subject": _clean(subject),
        "concepts": _string_list(concepts)[:8],
        "description": _clean(description),
        "status": "diagram_specification_created",
    }


def retrieve_visual_reference(
    query: str,
    educational_purpose: str,
) -> dict[str, Any]:
    """
    Record a visual-reference request. Does not search the web.
    """

    return {
        "query": _clean(query),
        "educational_purpose": _clean(educational_purpose),
        "status": "visual_reference_request_created",
    }


def render_equation(
    equation: str,
    context: str = "",
) -> dict[str, Any]:
    """
    Normalise an equation for downstream deterministic rendering.

    Local only. Does not call a typesetter.
    """

    return {
        "equation": _clean(equation),
        "context": _clean(context),
        "format": "latex",
        "status": "equation_prepared",
    }


def generate_ai_image(
    prompt: str,
    educational_purpose: str,
    aspect_ratio: str = "16:9",
    materialize: bool | None = None,
    slide_number: Any = None,
) -> dict[str, Any]:
    """
    Build a backend-agnostic visual_asset specification.

    When SYNTRA_GENERATE_IMAGES is on and a client exists, the
    rendering layer may attach a url. Fail-soft: the spec is
    still returned if generation is off or the model call fails.
    """

    ratio = _clean(aspect_ratio) or "16:9"
    if ratio not in ALLOWED_ASPECT_RATIOS:
        ratio = "16:9"
    prompt_text = _clean(prompt)
    spec: dict[str, Any] = {
        "prompt": prompt_text,
        "aspect_ratio": ratio,
        "educational_purpose": _clean(educational_purpose),
    }
    warnings = _precision_warnings(prompt_text, slide_number)
    if warnings:
        spec["warnings"] = warnings
    if _should_materialize(materialize):
        stored = materialize_image_asset(
            prompt=prompt_text,
            educational_purpose=spec["educational_purpose"],
            aspect_ratio=ratio,
        )
        url = (stored or {}).get("url")
        if url:
            spec["url"] = url
    return spec


def _should_materialize(flag: bool | None) -> bool:
    if flag is False:
        return False
    return image_generation_enabled()


def _visual_asset_payload(
    spec: dict[str, Any], existing_url: str = ""
) -> dict[str, Any]:
    asset = {
        "prompt": spec["prompt"],
        "aspect_ratio": spec["aspect_ratio"],
        "educational_purpose": spec["educational_purpose"],
    }
    url = spec.get("url") or existing_url
    if url:
        asset["url"] = url
    return asset


def prepare_slide_visuals(
    slides: list[dict[str, Any]] | None = None,
) -> dict[str, Any]:
    """
    Normalise and validate visuals for the full slide list in one pass.

    Pass every slide. Do not call this once per slide.
    Does not search the web. Generates an image only when a slide is
    ai_generated, has a prompt, has no url yet, and budget remains.
    """

    prepared: list[dict[str, Any]] = []
    warnings: list[str] = []
    issues: list[str] = []
    rows = slides or []
    budget = max_images_per_lesson() if image_generation_enabled() else 0

    if not rows:
        issues.append("No slides were generated.")

    for index, raw in enumerate(rows, start=1):
        if not isinstance(raw, dict):
            issues.append(f"Slide {index}: not an object.")
            continue
        slide = dict(raw)
        number = slide.get("slide_number", index)
        visual_type = _visual_type(slide.get("visual_type"))
        if visual_type not in ALLOWED_VISUAL_TYPES:
            if visual_type:
                issues.append(f"Slide {number}: unknown visual_type {visual_type!r}.")
            visual_type = "none"

        if not _clean(slide.get("title")):
            issues.append(f"Slide {number}: missing title.")
        if not _clean(slide.get("purpose")):
            issues.append(f"Slide {number}: missing purpose.")
        if not _clean(slide.get("teacher_explanation")):
            issues.append(f"Slide {number}: missing teacher explanation.")

        difficulty = _token(slide.get("difficulty"))
        if difficulty and difficulty not in ALLOWED_DIFFICULTY:
            issues.append(f"Slide {number}: unknown difficulty {difficulty!r}.")

        asset = slide.get("visual_asset") or slide.get("image_asset")
        if isinstance(asset, dict) or visual_type == "ai_generated":
            data = asset if isinstance(asset, dict) else {}
            existing_url = _clean(data.get("url")) if isinstance(data, dict) else ""
            prompt = data.get("prompt") or slide.get("visual_description") or ""
            should_generate = (
                visual_type == "ai_generated"
                and budget > 0
                and not existing_url
                and bool(_clean(prompt))
            )
            spec = generate_ai_image(
                prompt=prompt,
                educational_purpose=data.get("educational_purpose")
                or slide.get("purpose")
                or "",
                aspect_ratio=data.get("aspect_ratio") or "16:9",
                materialize=should_generate,
                slide_number=number,
            )
            if should_generate:
                budget -= 1
            warnings.extend(spec.get("warnings") or [])
            if visual_type == "ai_generated" or spec["prompt"]:
                slide["visual_asset"] = _visual_asset_payload(spec, existing_url)
                if visual_type == "none" and spec["prompt"]:
                    visual_type = "ai_generated"
            if visual_type == "ai_generated" and not spec["prompt"]:
                issues.append(
                    f"Slide {number}: ai_generated slides need visual_asset.prompt."
                )

        diagram = slide.get("diagram_spec")
        if isinstance(diagram, dict) or visual_type == "diagram":
            data = diagram if isinstance(diagram, dict) else {}
            slide["diagram_spec"] = generate_diagram_spec(
                diagram_type=data.get("diagram_type") or visual_type,
                subject=data.get("subject") or slide.get("title") or "",
                concepts=data.get("concepts"),
                description=data.get("description")
                or slide.get("visual_description")
                or "",
            )

        equation = slide.get("equation")
        if visual_type == "equation" or equation:
            if isinstance(equation, dict):
                slide["equation"] = render_equation(
                    equation=equation.get("equation") or equation.get("latex") or "",
                    context=equation.get("context") or "",
                )
                equation_text = slide["equation"]["equation"]
            elif isinstance(equation, str) and _clean(equation):
                slide["equation"] = render_equation(equation=equation)
                equation_text = slide["equation"]["equation"]
            else:
                equation_text = _clean(equation) if isinstance(equation, str) else ""
            if visual_type == "equation" and not equation_text:
                issues.append(
                    f"Slide {number}: equation visual_type needs an equation."
                )

        content = slide.get("content")
        if isinstance(content, list) and len(content) > 4:
            slide["content"] = content[:4]
            warnings.append(f"Slide {number}: trimmed on-screen content to 4 bullets.")

        slide["visual_type"] = visual_type
        slide.pop("image_asset", None)
        prepared.append(slide)

    return {
        "slides": prepared,
        "warnings": warnings,
        "issues": issues,
        "valid": len(issues) == 0,
        "slide_count": len(prepared),
    }


def validate_slide_structure(
    slides: list[dict[str, Any]] | None = None,
) -> dict[str, Any]:
    """
    Validate the full slide list in one local pass.

    Prefer prepare_slide_visuals, which already validates.
    """

    issues: list[str] = []
    warnings: list[str] = []
    rows = slides or []

    if not rows:
        issues.append("No slides were generated.")

    for index, slide in enumerate(rows, start=1):
        if not isinstance(slide, dict):
            issues.append(f"Slide {index}: not an object.")
            continue

        number = slide.get("slide_number", index)
        if not _clean(slide.get("title")):
            issues.append(f"Slide {number}: missing title.")
        if not _clean(slide.get("purpose")):
            issues.append(f"Slide {number}: missing purpose.")
        if not _clean(slide.get("teacher_explanation")):
            issues.append(f"Slide {number}: missing teacher explanation.")

        content = slide.get("content", [])
        if isinstance(content, list) and len(content) > 4:
            warnings.append(f"Slide {number}: potentially too much on-screen content.")

        visual_type = _visual_type(slide.get("visual_type"))
        if visual_type and visual_type not in ALLOWED_VISUAL_TYPES:
            issues.append(f"Slide {number}: unknown visual_type {visual_type!r}.")

        difficulty = _token(slide.get("difficulty"))
        if difficulty and difficulty not in ALLOWED_DIFFICULTY:
            issues.append(f"Slide {number}: unknown difficulty {difficulty!r}.")

        asset = slide.get("visual_asset") or slide.get("image_asset")
        if visual_type == "ai_generated":
            prompt = ""
            if isinstance(asset, dict):
                prompt = _clean(asset.get("prompt"))
            if not prompt:
                issues.append(
                    f"Slide {number}: ai_generated slides need visual_asset.prompt."
                )
            else:
                warnings.extend(_precision_warnings(prompt, number))

        if visual_type == "diagram" and not isinstance(slide.get("diagram_spec"), dict):
            warnings.append(
                f"Slide {number}: diagram visual_type without diagram_spec."
            )

        equation = slide.get("equation")
        if visual_type == "equation":
            text = ""
            if isinstance(equation, dict):
                text = _clean(equation.get("equation") or equation.get("latex"))
            elif isinstance(equation, str):
                text = _clean(equation)
            if not text:
                issues.append(
                    f"Slide {number}: equation visual_type needs an equation."
                )

    return {
        "valid": len(issues) == 0,
        "issues": issues,
        "warnings": warnings,
        "slide_count": len(rows),
    }
