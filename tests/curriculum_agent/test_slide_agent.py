from types import SimpleNamespace

from curriculum_agent.agent import curriculum_agent
from curriculum_agent.slide_agent.agent import slide_agent
from curriculum_agent.slide_agent.image_assets import (
    DEFAULT_IMAGE_MODEL,
    _render_prompt,
    image_model_name,
    reset_image_client,
)
from curriculum_agent.slide_agent.tools import (
    generate_ai_image,
    prepare_slide_visuals,
    retrieve_visual_reference,
    validate_slide_structure,
)
from curriculum_agent.tools import instruction_template


class _FakeImageClient:
    def __init__(self, data: bytes = b"fakepng", boom: bool = False):
        self.calls = 0
        self._data = data
        self._boom = boom
        self.models = self

    def generate_content(self, **kwargs):
        self.calls += 1
        self.last_kwargs = kwargs
        if self._boom:
            raise RuntimeError("image model unavailable")
        part = SimpleNamespace(
            inline_data=SimpleNamespace(data=self._data, mime_type="image/png")
        )
        return SimpleNamespace(parts=[part], candidates=[])

    def generate_images(self, **kwargs):
        return self.generate_content(**kwargs)


def test_slide_agent_runs_after_lesson_planner():
    names = [agent.name for agent in curriculum_agent.sub_agents]
    assert names == [
        "prerequisite_agent",
        "learning_objectives_agent",
        "lesson_planner_agent",
        "slide_agent",
    ]
    assert names.index("slide_agent") == names.index("lesson_planner_agent") + 1


def test_slide_agent_reads_required_upstream_state():
    instruction = instruction_template(slide_agent)
    assert "{learner_profile?}" in instruction
    assert "{learning_objectives?}" in instruction
    assert "{prerequisite_analysis?}" in instruction
    assert "{lesson_plan?}" in instruction
    assert "{research_brief?}" in instruction
    assert "{research_package?}" not in instruction
    assert slide_agent.output_key == "slides"
    assert getattr(slide_agent, "mode", None) in {"single_turn", None} or str(
        slide_agent.mode
    ).endswith("single_turn")
    assert '{"slides": []}' in instruction
    assert "visual_asset" in instruction


def test_slide_agent_keeps_the_hot_path_local():
    tool_names = [
        getattr(tool, "__name__", None) or getattr(tool, "name", None)
        for tool in slide_agent.tools
    ]
    assert tool_names == ["prepare_slide_visuals"]
    assert "validate_slide_structure" not in tool_names
    assert "retrieve_visual_reference" not in tool_names
    instruction = instruction_template(slide_agent)
    assert "Do not call retrieve_visual_reference" in instruction
    assert "Do not call an image backend" in instruction
    assert "prepare_slide_visuals ONCE" in instruction
    curriculum_instruction = instruction_template(curriculum_agent)
    assert "{slides?}" not in curriculum_instruction
    assert "{lesson_plan?}" in curriculum_instruction
    assert curriculum_instruction.count("prerequisite analysis") >= 1
    assert "Do not wait for image generation" in curriculum_instruction


def test_generate_ai_image_returns_a_backend_agnostic_spec():
    spec = generate_ai_image(
        prompt="Educational illustration of a magnet moving through a coil, no labels.",
        educational_purpose="Visualise electromagnetic induction",
        aspect_ratio="16:9",
    )
    assert spec["prompt"].startswith("Educational illustration")
    assert spec["aspect_ratio"] == "16:9"
    assert spec["educational_purpose"] == "Visualise electromagnetic induction"
    assert "url" not in spec
    assert "asset_id" not in spec


def test_prepare_slide_visuals_normalises_the_full_list_locally():
    result = prepare_slide_visuals(
        [
            {
                "slide_number": 1,
                "title": "Induction",
                "purpose": "See the motion",
                "visual_type": "image",
                "visual_asset": {
                    "prompt": "Coil and magnet in motion, no labels",
                    "educational_purpose": "Visualise induction",
                    "aspect_ratio": "wide",
                },
                "content": ["a", "b", "c", "d", "e", "f", "g", "h"],
            },
            {
                "slide_number": 2,
                "title": "Faraday",
                "purpose": "Write the law",
                "visual_type": "equation",
                "equation": "E = -dNΦ/dt",
            },
        ]
    )
    assert result["slide_count"] == 2
    first, second = result["slides"]
    assert first["visual_type"] == "ai_generated"
    assert first["visual_asset"]["aspect_ratio"] == "16:9"
    assert len(first["content"]) == 4
    assert second["equation"]["format"] == "latex"
    assert second["equation"]["equation"] == "E = -dNΦ/dt"
    assert "valid" in result
    assert "issues" in result


def test_validate_slide_structure_accepts_a_complete_deck():
    report = validate_slide_structure(
        [
            {
                "slide_number": 1,
                "title": "Induction",
                "purpose": "See the motion",
                "teacher_explanation": "Move the magnet.",
                "visual_type": "ai_generated",
                "visual_asset": {
                    "prompt": "Coil and magnet in motion, no labels",
                    "educational_purpose": "Visualise induction",
                    "aspect_ratio": "16:9",
                },
                "content": ["A changing field can induce an EMF."],
                "difficulty": "foundation",
            }
        ]
    )
    assert report["valid"] is True
    assert report["issues"] == []


def test_retrieve_visual_reference_does_not_search():
    result = retrieve_visual_reference(
        query="faraday coil",
        educational_purpose="optional still",
    )
    assert result["status"] == "visual_reference_request_created"
    assert "url" not in result


def test_generate_ai_image_attaches_url_from_mocked_client(monkeypatch):
    client = _FakeImageClient()
    monkeypatch.setenv("SYNTRA_GENERATE_IMAGES", "true")
    reset_image_client(client)
    try:
        spec = generate_ai_image(
            prompt="Coil and magnet in motion, no labels",
            educational_purpose="Visualise induction",
            aspect_ratio="16:9",
        )
    finally:
        reset_image_client()
    assert spec["prompt"].startswith("Coil")
    assert spec["url"].startswith("data:image/png;base64,")
    assert client.calls == 1
    assert "High contrast" in client.last_kwargs["contents"]
    assert "No text" in client.last_kwargs["contents"]


def test_generate_ai_image_fail_soft_when_client_raises(monkeypatch):
    monkeypatch.setenv("SYNTRA_GENERATE_IMAGES", "true")
    reset_image_client(_FakeImageClient(boom=True))
    try:
        spec = generate_ai_image(
            prompt="Coil and magnet in motion, no labels",
            educational_purpose="Visualise induction",
        )
    finally:
        reset_image_client()
    assert spec["prompt"].startswith("Coil")
    assert "url" not in spec


def test_prepare_slide_visuals_caps_generated_images(monkeypatch):
    client = _FakeImageClient()
    monkeypatch.setenv("SYNTRA_GENERATE_IMAGES", "true")
    monkeypatch.setenv("SYNTRA_IMAGE_MAX_PER_LESSON", "1")
    reset_image_client(client)
    try:
        result = prepare_slide_visuals(
            [
                {
                    "slide_number": 1,
                    "title": "One",
                    "purpose": "See it",
                    "visual_type": "ai_generated",
                    "visual_asset": {
                        "prompt": "first illustration",
                        "educational_purpose": "show one",
                        "aspect_ratio": "16:9",
                    },
                },
                {
                    "slide_number": 2,
                    "title": "Two",
                    "purpose": "See it again",
                    "visual_type": "ai_generated",
                    "visual_asset": {
                        "prompt": "second illustration",
                        "educational_purpose": "show two",
                        "aspect_ratio": "16:9",
                    },
                },
            ]
        )
    finally:
        reset_image_client()
    assert client.calls == 1
    assert result["slides"][0]["visual_asset"]["url"].startswith("data:image/png")
    assert "url" not in result["slides"][1]["visual_asset"]


def test_default_image_model_is_nano_banana_2(monkeypatch):
    monkeypatch.delenv("SYNTRA_IMAGE_MODEL", raising=False)
    assert DEFAULT_IMAGE_MODEL == "gemini-3.1-flash-image"
    assert image_model_name() == "gemini-3.1-flash-image"


def test_render_prompt_asks_for_classroom_visible_scenes():
    text = _render_prompt(
        {
            "prompt": "Coil and magnet",
            "educational_purpose": "Visualise induction",
        }
    )
    assert "High contrast" in text
    assert "No text" in text
    assert "tiny" in text.lower()
    assert "Coil and magnet" in text


def test_prepare_slide_visuals_skips_generation_when_url_exists(monkeypatch):
    client = _FakeImageClient()
    monkeypatch.setenv("SYNTRA_GENERATE_IMAGES", "true")
    reset_image_client(client)
    try:
        result = prepare_slide_visuals(
            [
                {
                    "slide_number": 1,
                    "title": "Induction",
                    "purpose": "See the motion",
                    "teacher_explanation": "Move the magnet.",
                    "visual_type": "ai_generated",
                    "visual_asset": {
                        "prompt": "Coil and magnet in motion, no labels",
                        "educational_purpose": "Visualise induction",
                        "aspect_ratio": "16:9",
                        "url": "https://example.test/already.png",
                    },
                }
            ]
        )
    finally:
        reset_image_client()
    assert client.calls == 0
    assert result["slides"][0]["visual_asset"]["url"] == (
        "https://example.test/already.png"
    )


def test_prepare_slide_visuals_skips_generation_without_prompt(monkeypatch):
    client = _FakeImageClient()
    monkeypatch.setenv("SYNTRA_GENERATE_IMAGES", "true")
    reset_image_client(client)
    try:
        result = prepare_slide_visuals(
            [
                {
                    "slide_number": 1,
                    "title": "Induction",
                    "purpose": "See the motion",
                    "teacher_explanation": "Move the magnet.",
                    "visual_type": "ai_generated",
                    "visual_asset": {
                        "prompt": "",
                        "educational_purpose": "Visualise induction",
                        "aspect_ratio": "16:9",
                    },
                }
            ]
        )
    finally:
        reset_image_client()
    assert client.calls == 0
    assert result["valid"] is False
    assert any("visual_asset.prompt" in issue for issue in result["issues"])


def test_generate_ai_image_reuses_in_memory_cache(monkeypatch):
    client = _FakeImageClient()
    monkeypatch.setenv("SYNTRA_GENERATE_IMAGES", "true")
    reset_image_client(client)
    try:
        first = generate_ai_image(
            prompt="Coil and magnet in motion, no labels",
            educational_purpose="Visualise induction",
            aspect_ratio="16:9",
        )
        second = generate_ai_image(
            prompt="Coil and magnet in motion, no labels",
            educational_purpose="Visualise induction",
            aspect_ratio="16:9",
        )
    finally:
        reset_image_client()
    assert client.calls == 1
    assert first["url"] == second["url"]
    assert first["url"].startswith("data:image/png;base64,")
