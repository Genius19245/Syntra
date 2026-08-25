---
name: evidence-extraction
description: Extract structured evidence objects from retrieved text. Use after RAG hits or fetched pages. Output must be usable by the Fact Checker.
---

# Evidence Extraction

Do not treat research as URL → dump of webpage text. Extract structured evidence.

## Evidence object

Every extracted item must be an object with:

- `claim`: one teachable factual sentence
- `evidence`: the supporting fact in your own careful paraphrase, faithful to the source
- `source`: organisation or document name
- `url`: the real URL that was retrieved (never invented)
- `source_authority`: short label from source evaluation
- `source_tier`: integer 1–5
- `publication_date`: if stated in the source, else empty
- `retrieved_date`: date the text was retrieved, if known
- `topic`: the lesson topic
- `education_level`: the requested level, if any
- `confidence`: HIGH, MEDIUM, or LOW for how clearly the passage supports the claim
- `relevant_passage`: a short quotation or close excerpt that actually appears in the source

## Rules

- One claim per object. Do not bundle unrelated facts.
- The relevant passage must support the claim. If it does not, discard the object.
- Keep claims at classroom depth for the requested level.
- Preserve numbers, units, names, and dates exactly.
- If the source does not support a tempting claim, do not emit that claim.
- These objects are passed to the Fact Checker. Missing URLs or invented passages make verification impossible.
