import json

import pytest
from curriculum_agent.tools import instruction_template
from learning_objectives_agent import tools as objective_tools
from learning_objectives_agent.agent import learning_objectives_agent
from learning_objectives_agent.tools import (
    classify_objective_type,
    generate_objective_framework,
    validate_learning_objectives,
)


@pytest.fixture(autouse=True)
def clear_classify_cache():
    objective_tools._CLASSIFY_CACHE_KEY = None
    objective_tools._CLASSIFY_CACHE = None
    objective_tools._UNIQUE_CACHE_KEY = None
    objective_tools._UNIQUE_CACHE = None
    yield
    objective_tools._CLASSIFY_CACHE_KEY = None
    objective_tools._CLASSIFY_CACHE = None
    objective_tools._UNIQUE_CACHE_KEY = None
    objective_tools._UNIQUE_CACHE = None


def test_objectives_agent_is_single_turn_local_tools():
    names = [
        getattr(tool, "__name__", getattr(tool, "name", None))
        for tool in learning_objectives_agent.tools
    ]
    assert learning_objectives_agent.mode == "single_turn"
    assert names == ["validate_learning_objectives"]
    assert "{research_brief?}" in instruction_template(learning_objectives_agent)
    assert "{research_package?}" not in instruction_template(learning_objectives_agent)
    assert "{learner_profile?}" in instruction_template(learning_objectives_agent)
    assert "{prerequisite_analysis?}" in instruction_template(learning_objectives_agent)
    assert "generate_objective_framework" not in instruction_template(
        learning_objectives_agent
    )
    assert "classify_objective_type" not in instruction_template(
        learning_objectives_agent
    )


def test_classify_parses_json_list_once():
    payload = json.dumps(["Explain Faraday's law.", "Calculate the induced emf."])
    result = classify_objective_type(payload)
    assert result["classified_count"] == 2
    assert result["classifications"][0]["type"] == "Understanding"
    assert result["classifications"][1]["type"] == "Application"


def test_phrase_verbs_are_classified_without_a_second_scan():
    result = classify_objective_type(
        [
            "Give examples of magnetic materials.",
            "Break down a transformer into its parts.",
        ]
    )
    assert [item["type"] for item in result["classifications"]] == [
        "Understanding",
        "Analysis",
    ]


def test_validate_reuses_classify_parse(monkeypatch):
    calls = {"n": 0}
    original = objective_tools._classify_one

    def counted(objective, **kwargs):
        calls["n"] += 1
        return original(objective, **kwargs)

    monkeypatch.setattr(objective_tools, "_classify_one", counted)
    objectives = [
        "Explain magnetic flux.",
        "Calculate induced emf in a coil.",
        "Compare AC and DC generators.",
    ]
    classified = classify_objective_type(objectives)
    after_classify = calls["n"]
    validated = validate_learning_objectives(
        objectives,
        education_level="GCSE",
        topic="electromagnetic induction",
    )
    assert after_classify == len(objectives)
    assert calls["n"] == after_classify
    assert classified["progression"] == validated["progression"]
    assert validated["valid"] is True


def test_validate_flags_duplicates_and_weak_language():
    result = validate_learning_objectives(
        [
            "Understand magnets.",
            "Understand magnets.",
            "Know about fields.",
        ],
        education_level="GCSE",
        topic="magnets",
    )
    assert result["valid"] is False
    assert "Duplicate objectives were supplied." in result["issues"]
    assert any(
        "weak language" in issue.lower()
        for item in result["objectives"]
        for issue in item["issues"]
    )


def test_generate_objective_framework_uses_level_band():
    result = generate_objective_framework(
        "Physics",
        "Electromagnetic induction",
        "A-Level",
        learning_goal="Explain Faraday's law",
        learner_profile="# Profile",
        prerequisite_analysis="# Gaps",
    )
    assert result["education_band"] == "a_level"
    assert result["has_learner_profile"] is True
    assert "Creation" not in result["recommended_bloom_types"]
    assert "Evaluation" in result["recommended_bloom_types"]
