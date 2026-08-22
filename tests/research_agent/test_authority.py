from research_agent.retrieval.authority import (
    contextual_sort_key,
    evaluate_source,
    source_tier,
)

AQA = "https://www.aqa.org.uk/subjects/science/as-and-a-level/physics-7408"
NASA = "https://science.nasa.gov/ems/02_anatomy/"
BITESIZE = "https://www.bbc.co.uk/bitesize/guides/z2b9v9q/revision/1"
MEDIUM = "https://medium.com/some-seo-post"


def test_scientific_agencies_are_tier_1():
    assert source_tier(NASA) == 1
    assert source_tier("https://www.who.int/news-room/fact-sheets") == 1
    assert source_tier("https://www.gov.uk/government/publications") == 1


def test_exam_boards_are_tier_1():
    assert source_tier(AQA) == 1
    assert source_tier("https://qualifications.pearson.com/en/qualifications/edexcel-a-levels.html") == 1
    assert source_tier("https://www.ocr.org.uk/qualifications/") == 1


def test_revision_sites_are_tier_3():
    assert source_tier(BITESIZE) == 3
    assert source_tier("https://en.wikipedia.org/wiki/Photosynthesis") == 3


def test_blogs_are_tier_5():
    assert source_tier(MEDIUM) == 5


def test_curriculum_question_prefers_named_exam_board_over_nasa():
    aqa_key = contextual_sort_key(
        AQA, exam_board="AQA", question_intent="curriculum"
    )
    nasa_key = contextual_sort_key(
        NASA, exam_board="AQA", question_intent="curriculum"
    )
    assert aqa_key < nasa_key


def test_scientific_claim_prefers_nasa_over_revision_site():
    nasa_key = contextual_sort_key(NASA, question_intent="scientific_claim")
    bbc_key = contextual_sort_key(BITESIZE, question_intent="scientific_claim")
    assert nasa_key < bbc_key
    assert source_tier(NASA) < source_tier(BITESIZE)


def test_evaluate_source_returns_metadata():
    result = evaluate_source(
        NASA, exam_board="", question_intent="scientific_claim"
    )
    assert result["success"] is True
    assert result["source_tier"] == 1
    assert result["scientific_authority"] is True
    assert result["exam_board_match"] is False
