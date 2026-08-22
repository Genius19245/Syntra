from research_agent.rag.store import KnowledgeStore, default_store


def test_default_store_indexes_sample_documents():
    store = default_store()
    paths = {doc.path for doc in store.documents}
    assert any("electromagnetic-induction" in path for path in paths)
    assert any("photosynthesis" in path for path in paths)
    assert any("ionic-bonding" in path for path in paths)


def test_a_level_physics_retrieves_electromagnetic_induction():
    hits = default_store().retrieve(
        "Teach me electromagnetic induction.",
        filters={"subject": "physics", "education_level": "A-Level"},
    )
    assert hits
    top = hits[0]
    assert top["metadata"]["topic"] == "electromagnetic induction"
    assert top["metadata"]["education_level"] == "a-level"
    assert "Faraday" in top["text"] or "induction" in top["text"].lower()


def test_gcse_chemistry_does_not_return_university_cs():
    hits = default_store().retrieve(
        "Explain ionic bonding.",
        filters={"subject": "chemistry", "education_level": "GCSE"},
    )
    assert hits
    assert hits[0]["metadata"]["topic"] == "ionic bonding"
    subjects = {hit["metadata"].get("subject") for hit in hits}
    levels = {hit["metadata"].get("education_level") for hit in hits}
    assert "computer science" not in subjects
    assert "undergraduate" not in levels


def test_university_cs_does_not_return_gcse_chemistry():
    hits = default_store().retrieve(
        "Explain operating system scheduling algorithms.",
        filters={
            "subject": "computer science",
            "education_level": "university",
        },
    )
    assert hits
    assert hits[0]["metadata"]["topic"] == "operating system scheduling algorithms"
    levels = {hit["metadata"].get("education_level") for hit in hits}
    assert "gcse" not in levels


def test_named_exam_board_excludes_other_boards(tmp_path):
    (tmp_path / "aqa.md").write_text(
        """---
topic: magnets
subject: physics
education_level: gcse
exam_board: aqa
title: AQA magnets
---
AQA classroom notes on magnets.
"""
    )
    (tmp_path / "ocr.md").write_text(
        """---
topic: magnets
subject: physics
education_level: gcse
exam_board: ocr
title: OCR magnets
---
OCR classroom notes on magnets.
"""
    )
    store = KnowledgeStore(root=tmp_path)
    hits = store.retrieve(
        "magnets",
        filters={"subject": "physics", "exam_board": "AQA"},
    )
    boards = {str(hit["metadata"].get("exam_board") or "").lower() for hit in hits}
    assert boards == {"aqa"}


def test_history_does_not_assume_an_exam_board():
    hits = default_store().retrieve(
        "Explain the causes of the First World War.",
        filters={"subject": "history", "exam_board": ""},
    )
    assert hits
    assert not hits[0]["metadata"].get("exam_board")


def test_custom_store_from_empty_directory(tmp_path):
    store = KnowledgeStore(root=tmp_path)
    assert store.retrieve("photosynthesis") == []
