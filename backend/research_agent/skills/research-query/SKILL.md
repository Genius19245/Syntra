---
name: research-query
description: Decompose a research question into a small set of targeted search dimensions. Use before any web search. Prevents duplicate and scattershot queries.
---

# Research Query Generation

Do not blindly generate dozens of searches. Plan first, then search.

## Goal

Fewer, more targeted, higher-quality searches. Maximum reliability with minimum unnecessary research.

## Process

1. Restate the classroom research question (not a dissertation question).
2. Identify the requested subject, education level, and exam board **only if present**.
3. Decompose into research dimensions that apply to *this* question. Typical dimensions, used only when relevant:
   - Core concept or mechanism
   - Definitions and notation
   - Causes, processes, or methods
   - Evidence or worked examples at this level
   - Curriculum or specification requirements
   - Common misconceptions
   - Required educational depth
4. Call `generate_research_queries` with the topic, level, board, and subject. Use its deduplicated list.
5. Do not add near-duplicate queries ("X explained", "what is X", "X overview").
6. Do not search for academic rabbit holes (neuroscience, meta-analyses, "the literature") unless the brief is postgraduate or the user asked for research-level depth.

## Budget

- Default cap: 6 queries.
- Prefer 3–5.
- One query per dimension unless a dimension is empty.
- After searches, only add a query if an evidence gap remains (missing definition, missing curriculum point, unresolved conflict).

## Stop

Stop searching when high-tier evidence covers the teachable claims for this lesson. More searches are not better.
