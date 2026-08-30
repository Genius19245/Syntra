from types import SimpleNamespace

from explanation_agent.agent import explanation_agent
from explanation_agent.tools import (
    get_explanation_level,
    match_concept_context,
    retrieve_concept_context,
)


def _package():
    return {
        "topic": "electromagnetic induction",
        "key_concepts": ["magnetic flux", "induced emf", "Faraday's law"],
        "misconceptions": [
            "A magnet sitting still on a coil still induces a current.",
            "Current is the same as voltage.",
        ],
        "claims": [
            {
                "claim": "Magnetic flux measures how much field passes through a surface.",
                "evidence": "GCSE notes define flux as BA for a uniform field.",
                "verification": {"verdict": "VERIFIED"},
                "sources": [{"organisation": "SYNTRA seed notes"}],
            },
            {
                "claim": "Faraday's law relates induced emf to changing flux.",
                "evidence": "emf = -N dΦ/dt.",
                "verification": "VERIFIED",
                "sources": [{"organisation": "SYNTRA seed notes"}],
            },
            {
                "claim": "Photosynthesis converts light energy into chemical energy.",
                "evidence": "Unrelated biology claim.",
                "sources": [{"organisation": "SYNTRA seed notes"}],
            },
        ],
        "research_method": {"rag_used": True, "web_used": False},
    }


def _lesson_plan():
    return {
        "lesson_sequence": [
            {
                "step": 1,
                "title": "Recall magnetic fields",
                "purpose": "Activate prior knowledge",
                "concepts": ["magnetic field"],
            },
            {
                "step": 2,
                "title": "Define magnetic flux",
                "purpose": "Introduce flux",
                "concepts": ["magnetic flux"],
            },
        ]
    }


def test_explanation_agent_is_single_turn_local_tools():
    names = [
        getattr(tool, "__name__", getattr(tool, "name", None))
        for tool in explanation_agent.tools
    ]
    assert explanation_agent.name == "explanation_agent"
    assert explanation_agent.mode == "single_turn"
    assert explanation_agent.output_key == "explanation"
    assert names[:2] == ["get_explanation_level", "retrieve_concept_context"]
    assert "example_agent" in names
    assert [agent.name for agent in explanation_agent.sub_agents] == ["example_agent"]
    instruction = explanation_agent.instruction
    assert "{research_package?}" in instruction
    assert "{learner_profile?}" in instruction
    assert "{prerequisite_analysis?}" in instruction
    assert "{lesson_plan?}" in instruction
    assert "{slides?}" in instruction
    assert "Do not pass the research package into the tool" in instruction
    assert "## Say this" in instruction
    assert "## Freeze" in instruction
    assert "student-facing" in instruction.lower()


def test_get_explanation_level_matches_gcse_phrases():
    result = get_explanation_level("Year 11 GCSE Combined Science")
    assert result["education_band"] == "gcse"
    assert result["recommended_depth"] == "Foundational / GCSE"
    assert result["allow_equations"] is True
    assert result["allow_formalism"] is False
    assert result["prefer_analogies"] is True
    assert result["max_bloom"] == "Analysis"


def test_get_explanation_level_reads_learner_profile_from_state():
    context = SimpleNamespace(state={"learner_profile": {"level": "A-Level Physics"}})
    result = get_explanation_level(tool_context=context)
    assert result["education_band"] == "a_level"
    assert result["recommended_depth"] == "Intermediate / A-Level"
    assert result["allow_formalism"] is True


def test_get_explanation_level_uses_required_depth_when_unspecified():
    result = get_explanation_level("adult learner", required_depth="exam application")
    assert result["education_band"] == "unspecified"
    assert result["recommended_depth"] == "exam application"


def test_match_concept_context_returns_compact_hits_not_the_package():
    result = match_concept_context(
        "magnetic flux",
        research_package=_package(),
        lesson_plan=_lesson_plan(),
        prerequisite_analysis={"core": ["Magnetic field", "Area"], "missing": ["Flux"]},
    )
    assert result["status"] == "success"
    assert result["match_count"] > 0
    claims = [item["claim"] for item in result["claims"]]
    assert any("flux" in claim.lower() for claim in claims)
    assert all("photosynthesis" not in claim.lower() for claim in claims)
    assert "research_method" not in result
    assert result["lesson_steps"][0]["title"] == "Define magnetic flux"
    assert "Flux" in result["prerequisites"] or "magnetic flux" in {
        item.lower() for item in result["key_concepts"]
    }


def test_retrieve_concept_context_does_not_dump_unmatched_package():
    context = SimpleNamespace(
        state={"research_package": _package(), "lesson_plan": _lesson_plan()}
    )
    result = retrieve_concept_context("osmosis", tool_context=context)
    assert result["status"] == "not_found"
    assert result["claims"] == []
    assert result["slides"] == []
    assert result["match_count"] == 0
    assert "photosynthesis" not in str(result).lower()


def test_retrieve_concept_context_requires_session_state():
    result = retrieve_concept_context("flux")
    assert result["status"] == "error"
    assert "session state" in result["message"]


def test_match_concept_context_parses_json_package_once():
    import json

    payload = json.dumps(_package())
    result = match_concept_context("Faraday's law", research_package=payload)
    assert result["status"] == "success"
    assert result["claims"][0]["claim"].startswith("Faraday")


def test_match_concept_context_keeps_this_concept_misconceptions_only():
    result = match_concept_context(
        "Fetch and wave energy",
        research_package={
            "key_concepts": ["fetch", "wave energy", "constructive waves"],
            "misconceptions": [
                "Fetch is how windy it is.",
                "A tall wave is automatically a destructive wave.",
            ],
            "claims": [
                {
                    "claim": "Fetch is the unbroken stretch of water the wind blows over.",
                    "evidence": "GCSE notes define fetch as open-water distance.",
                    "verification": "VERIFIED",
                }
            ],
        },
        slides={
            "slides": [
                {
                    "title": "Wave energy tracks fetch",
                    "teacher_explanation": "Point at fetch first, then wind.",
                    "equation": {"equation": "Wave energy ∝ fetch × wind speed"},
                    "content": [
                        "Fetch is the unbroken distance wind blows over water.",
                    ],
                },
                {
                    "title": "Constructive vs destructive waves",
                    "teacher_explanation": "Swash versus backwash is the test.",
                    "content": ["Strong swash, weak backwash. The beach builds."],
                },
            ]
        },
    )
    assert result["status"] == "success"
    joined = " ".join(result["misconceptions"]).lower()
    assert "fetch is how windy" in joined
    assert "destructive wave" not in joined
    assert any("fetch" in item.lower() for item in result["key_concepts"])
    assert all("constructive" not in item.lower() for item in result["key_concepts"])
    assert result["slides"][0]["title"] == "Wave energy tracks fetch"
    assert result["slides"][0]["equation"] == "Wave energy ∝ fetch × wind speed"
    assert all("constructive" not in (slide["title"] or "").lower() for slide in result["slides"])
