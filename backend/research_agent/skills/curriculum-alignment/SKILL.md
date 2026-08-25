---
name: curriculum-alignment
description: Detect requested educational depth and, if named, exam board. Use at the start of research. Never assume a board or overshoot the level.
---

# Curriculum Alignment

Match research depth to the learner's request. This skill is domain-independent.

## Detect education level

Look in the user message / intake brief for signals such as:

- Primary, KS2, KS3
- GCSE, National 5
- A-Level, Higher, IB
- undergraduate, university, bachelor's
- master's, postgraduate
- beginner, intermediate, advanced

Copy the stated level. Do not upgrade it (for example do not turn GCSE into A-Level, or A-Level into undergraduate research).

If no level is stated, research at a clear introductory classroom depth and record `education_level` as empty or "unspecified". Do not assume A-Level.

## Detect exam board

Named boards include AQA, Edexcel / Pearson, OCR, Cambridge, WJEC, SQA, IB, and others.

- If a board **is** specified, prefer that board's official specification or approved materials when deciding *what must be taught*.
- If a board **is not** specified, do **not** assume one. Do not filter RAG or searches to a single board.

## Depth rules

- School and undergraduate lessons: definitions, methods, syllabus points, worked-example facts, common misconceptions.
- Postgraduate or explicit research-level requests: scholarly sources are allowed.
- Do not chase journal-only claims, exact developmental ages, or neuroscience for school lessons.

## RAG filters

When calling retrieval tools, pass the detected `education_level`, `subject`, and `exam_board` (only if named) so A-Level material is preferred for A-Level, GCSE is not used as a substitute for university, and unspecified boards stay unspecified.
