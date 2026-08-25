from curriculum_agent.prerequisite_agent.tools import (
    structure_prerequisites,
    validate_prerequisite_analysis,
)


def test_validate_prerequisite_analysis_parses_bands_once():
    report = validate_prerequisite_analysis(
        core=["Flux", "EMF"],
        helpful=["flux", "Right-hand rule"],
        advanced=["Maxwell"],
        sequence=["Flux", "EMF", "Right-hand rule"],
        gaps_computed=True,
    )
    assert report["structured"]["core"] == ["Flux", "EMF"]
    assert report["structured"]["helpful"] == ["Right-hand rule"]
    assert report["valid"] is False
    assert any("Duplicate concepts" in issue for issue in report["issues"])


def test_structure_prerequisites_keeps_highest_band():
    structured = structure_prerequisites(
        core=["Flux"],
        helpful=["Flux", "EMF"],
        advanced=["EMF", "Maxwell"],
    )
    assert structured["core"] == ["Flux"]
    assert structured["helpful"] == ["EMF"]
    assert structured["advanced"] == ["Maxwell"]
    assert structured["all"] == ["Flux", "EMF", "Maxwell"]
