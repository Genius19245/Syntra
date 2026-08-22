# SYNTRA knowledge collections

Domain-independent persistent knowledge for the Research Agent RAG layer.

This is **not** a replacement for web research. Hybrid routing decides
RAG_ONLY, WEB_ONLY, or RAG + WEB from the question's freshness and
whether high-quality local evidence already exists.

## Layout

```
knowledge/
    curriculum/
        aqa/
        edexcel/
        ocr/
        cambridge/
    authoritative/
        nasa/
        noaa/
        ipcc/
        who/
        government/
        universities/
    textbooks/
    previous_research/
    samples/
```

Add markdown files with YAML frontmatter. Do not hard-code the store to a
single subject. The same collections can hold Physics, Maths, Biology,
Chemistry, Computer Science, History, Geography, Economics, and other
educational topics.

## Metadata

```yaml
---
source: AQA
authority: official_exam_board
source_tier: 1
topic: electromagnetic induction
subject: physics
education_level: a-level
exam_board: aqa
publication_date: "2024-01-01"
last_checked: "2026-08-22"
content_type: curriculum
url: https://www.aqa.org.uk/example
title: Electromagnetic induction
---
```

Leave `exam_board` empty when the document is not board-specific.
`source_tier` is 1 (highest authority) through 5 (unverified).

## Persistence

Verified research packages are written to `previous_research/` by the
`store_knowledge` tool after fact-checking. The in-memory store is
updated immediately, so the next lesson in the same process can
retrieve it. Restarting the agent reloads every `*.md` file under
this tree.

Time-sensitive questions are not stored. Unverified and contradicted
claims are not stored.

Override the corpus root with `SYNTRA_KNOWLEDGE_ROOT` if needed.

