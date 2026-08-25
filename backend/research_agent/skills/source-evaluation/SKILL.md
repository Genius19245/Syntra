---
name: source-evaluation
description: Rank educational sources by authority, relevance, recency, and curriculum fit. Use before trusting a webpage, RAG hit, or citation. Domain-independent.
---

# Source Evaluation

Evaluate every source before using it as evidence. Do not treat all URLs as equal.

## Default authority tiers

Lower tier number is more authoritative **in the abstract**. Always apply contextual overrides afterwards.

**Tier 1**
- Government organisations and official statistics
- Official scientific organisations
- Major international organisations
- Peer-reviewed scientific literature and primary research
- Official curriculum and exam-board documents

Examples of the *kind* of source, not an exhaustive list: national scientific agencies, health authorities, intergovernmental scientific bodies, universities' official teaching materials, national governments, named exam boards, scientific journals.

**Tier 2**
- Universities and established academic institutions
- Reputable educational organisations

**Tier 3**
- Established educational and revision websites

**Tier 4**
- General websites of unclear editorial standard

**Tier 5**
- Blogs, forums, unverified pages, SEO content, social media

Use the `evaluate_source` tool for deterministic host/tier metadata. Then apply the contextual judgement below. Do not re-implement host matching in prose; use the tool output as the baseline.

## Contextual ranking (required)

Authority is not absolute. Rank for the *question being asked*.

- If the task is **what an exam specification requires**, an official document from the named exam board outranks a scientific agency.
- If the task is **whether a scientific claim is true**, a primary scientific authority outranks a revision website, even if the revision site is on-syllabus.
- If no exam board was specified, do **not** invent one and do **not** prefer a board's materials over equally relevant national or scientific sources.

Score each source on:

1. Authority (tier, organisation, editorial process)
2. Relevance to the exact claim and education level
3. Recency, when the fact can go stale
4. Primary vs secondary (prefer primary when verifying a claim)
5. Curriculum relevance, only when a level or board was requested
6. Methodological quality
7. Corroboration from independent organisations

## Rules

- Prefer fewer high-tier sources over many weak ones.
- Wikipedia and similar encyclopedias are orientation only, never the sole evidence for a taught claim.
- Do not cite blogs, forums, or SEO pages as supporting evidence.
- If two sources conflict, keep both, flag the conflict, and send the claim to the Fact Checker. Do not pick a winner from authority alone when the conflict is substantive.
- Never upgrade a source's tier because it agrees with you.
