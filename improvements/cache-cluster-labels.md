# Cluster labels on the research cache

Steal the useful bit of a knowledge graph — **named clusters, subject, and level** as hard facts — without building a graph database or mixing levels inside one fingerprint.

Firestore stays the store. `syntra/workspace/research_cache` stays Admin-only. Flutter still never reads it.

This is a design note, not a build order. Do not implement until the backfill and “cache vs web” UI in [next-features.md](next-features.md) are in better shape; those make this cheaper to judge.

## Why

Fingerprints (Vertex embeddings + Firestore `find_nearest`) answer: *does this question look like a package we already saved?*

They do not answer: *is this the same idea, at a compatible level, in the right subject?*

A full knowledge graph would store explicit edges (osmosis needs diffusion). That is expensive to keep honest. Bad edges poison later lessons.

The slice worth taking:

- **Cluster** — magnets, magnetic, magnetism all sit under `magnetism`.
- **Subject** — that cluster is physics, not history “field”.
- **Level of this package** — this *document* is GCSE, not “GCSE plus A-level plus uni” mashed together.
- **Sibling packages** — magnetism-GCSE and magnetism-A-level are separate cache docs, linked only by the same cluster name.

Filters first (must be true) → fingerprint second (worded differently). That is faster as the cache grows and it blocks most bad links.

## What exists today

| Piece | Where | What it does |
| --- | --- | --- |
| Tiny alias map | `research_agent/rag/labels.py` `_ALIASES` | Token → `(cluster, subject)`. Example: `magnet` → magnetism / physics. Most topics fall through to a slug of the raw title. |
| `prompt_key` | same file | Hash of topic + subject + **this** level + board. GCSE magnetism and A-level magnetism are already different docs. |
| Cache fields | `ResearchCache.store` in `firebase_cache.py` | Writes `subject`, `education_level`, `exam_board`, `topic_cluster`, `keywords`, `embedding`. |
| Vector search | `FirestoreBackend.find_nearest` | Cosine on `embedding`, optionally `where subject == …`. Limit 24. |
| Level gate | `store._compatible_level` | Applied **after** candidates are fetched. School vs university do not mix; adjacent bands only. |
| Fingerprint text | `_document_corpus` | Topic, subject, **this package’s level**, key concepts, claims. |
| Cluster bonus | `_score_entry` | `+0.08` if `topic_cluster` matches. Exact key still wins (0.95); vector scores cap at 0.94. |

Gaps:

- Aliases cover a handful of demos. Unknown topics get a unique slug, so “osmosis in cells” and “diffusion and osmosis” may never share a cluster.
- Vector search filters **subject** only. Cluster and level are not in the Firestore query, so the 24 nearest can include the wrong idea; Python then throws some away.
- Putting extra levels into the fingerprint would pull uni wording toward a GCSE query. Do not do that.
- There is no cluster catalog: nothing records “magnetism is taught at GCSE, A-level, and undergraduate” except by existing as separate packages.

## Non-goals

- Do not add Neo4j, RDF, or a second database.
- Do not embed “A-level” and “university” into a GCSE package’s vector.
- Do not auto-invent prerequisite edges across the whole cache (that is how bad links get in).
- Do not let the Flutter client read `research_cache`.
- Do not replace exact `prompt_key` hits. Exact still wins.

## Target model

### Two kinds of record

**1. Package (already exists)** — one verified research blob for one topic × subject × **one** level × board.

Keep `education_level` as a single string on the package. That is the level this text was written for.

**2. Cluster (new, small)** — a name and the facts that are true of the *idea*, not of one lesson.

Suggested path, still under the same workspace, still Admin-only:

```
syntra/workspace/topic_clusters/{cluster_id}
```

Example `magnetism`:

```json
{
  "cluster_id": "magnetism",
  "subject": "physics",
  "aliases": ["magnet", "magnets", "magnetic", "magnetism"],
  "levels_seen": ["gcse", "a-level", "undergraduate"],
  "related_clusters": ["electromagnetic-induction"],
  "updated_at": "…"
}
```

`levels_seen` is **observed**, not a syllabus claim: append the package’s level when a verified package stores. Do not seed “every level” by hand and then treat it as truth.

`related_clusters` is optional and **manual or high-confidence only** (see “Avoiding bad links”). Empty is fine. One or two links is plenty. This is not a graph to traverse at query time in v1.

Package docs gain nothing exotic. Optional extra fields, all denormalised for filters:

- `cluster_id` — same as today’s `topic_cluster` once aliases are reliable (keep both in lockstep at first).
- `level_band` — `0`–`4` from `_BAND` in `store.py`, so Firestore can filter nearby bands without downloading the world.

### Fingerprint (do not change the idea)

Document text for Vertex stays:

- this topic wording
- this subject
- **this package’s level only**
- key concepts and claims

Do **not** concatenate sibling levels, related cluster names, or `levels_seen`. Those belong on the cluster doc and in query filters.

You *may* prefix the corpus with the cluster id as a single token (`magnetism`) so two GCSE wordings of the same idea sit closer. That is a label, not a graph dump.

Query embedding stays the teacher’s topic (and maybe `cluster_id` + subject). Still not “GCSE plus uni”.

## Lookup, after

Same waterfall, tighter funnel:

1. **Label** the intake (`label_prompt`). Resolve cluster from aliases / catalog, not only from title slug.
2. **Exact `prompt_key`**. Unchanged. If fresh and not “refresh this topic”, stop.
3. **Filtered vector search** on `research_cache`:
   - `subject == physics` (when not `general`)
   - `topic_cluster == magnetism` when the cluster is known
   - optionally `level_band` in `{q_band-1, q_band, q_band+1}` and still apply `_compatible_level` (school/uni split)
4. If that index cannot be used (unknown cluster), today’s subject-only `find_nearest`.
5. If vector search returns nothing, subject download + lexical score (already implemented).
6. Re-rank in Python: exact 0.95, cosine capped at 0.94, cluster bonus, keyword / board bonuses, `MIN_CACHE_SCORE` 0.35.

Faster because Firestore scans a slice (physics + magnetism + nearby band), not the whole cache. More good links because “magnets” and “magnetic fields” share `magnetism` even when titles differ. Fewer bad links because history and uni packages never enter the 24.

When cluster is unknown, behaviour stays as today. No worse.

## Labelling

### Grow `_ALIASES` without a giant hand map

v1: keep the dict; add rows when a package stores if the topic token clearly matches (existing alias or exact cluster id).

v2: cluster catalog is the source of truth. `label_prompt` looks up tokens against `aliases` on cluster docs (or an in-memory snapshot loaded at process start). Fall back to slug of the topic if nothing matches — same as now.

Do not ask the LLM to invent a cluster at retrieve time. Wrong cluster is a bad link. Optionally, after a package is **verified and stored**, a one-shot “suggest cluster” can queue a human/admin confirm. Skip that until aliases hurt.

### Level on the package vs levels on the cluster

| Question | Answer from |
| --- | --- |
| Which text do we reuse? | Package `education_level` + `_compatible_level` |
| Is magnetism even taught at uni? | Cluster `levels_seen` (analytics / admin, not a search filter that widens GCSE → uni) |

Never use `levels_seen` to *include* extra levels in a GCSE search. That would undo the school/uni split.

## Firestore indexes

Today: `embedding` flat 768, and `subject` + `embedding`.

Add (names indicative):

- `topic_cluster` + `embedding` (when cluster is known, this is the fast path)
- `subject` + `topic_cluster` + `embedding` if the console allows the composite
- `level_band` only if you actually query it; do not add unused composites

`package` stays unindexed (already in `fieldOverrides`). Cluster collection is tiny; ordinary fields are enough.

Deploy indexes before turning the new `find_nearest` filters on in production, or the query will fail and lookup already falls back — tests should assert that fallback.

## Writes

On `ResearchCache.store` after a verified package:

1. Write the package as today, including `topic_cluster`, `level_band`, embedding from the **narrow** corpus.
2. Merge the cluster doc: union `aliases` with tokens that mapped here; append this `education_level` to `levels_seen` if missing; set `subject` if currently empty and the package subject is not `general`.
3. Do not overwrite `related_clusters` from the model. Only an admin script or an explicit allowlist edit.

`backfill_embeddings.py` should also backfill `level_band` and, where `_ALIASES` can resolve it, a stable `topic_cluster` on old docs. Docs that stay on a unique title slug still work; they just will not join the cluster slice.

## Avoiding bad links

Rules to keep:

- School packages never enter a university query (and the reverse). Already in `_compatible_level`; keep it as a **hard** filter, not a score bump.
- Exam board: if the brief names AQA, drop non-AQA when the cache doc has a board (already done). Do not “link” OCR into an AQA hit via cluster.
- Related clusters: if you ever follow `related_clusters` at lookup, require (a) same subject, (b) compatible level, (c) score still ≥ `MIN_CACHE_SCORE`, (d) cap at one hop. v1 does not follow them at all — store for later.
- Unknown cluster ≠ `general` dump. Unknown means “no cluster filter”, still subject + level.

How a bad link would look, and the block:

| Failure | Block |
| --- | --- |
| Magnetic field vs farmer’s field | Subject physics vs geography; cluster `magnetism` vs slug `field` |
| GCSE magnets vs undergrad electrodynamics | `_compatible_level` / band filter |
| Photosynthesis vs “synthesis” in chemistry | Cluster ids are whole ideas, not shared suffixes |
| LLM names a cute but wrong cluster | No LLM at retrieve; aliases/catalog only |

## Files that would change (when built)

- `research_agent/rag/labels.py` — resolve cluster from catalog/aliases; expose `level_band`.
- `research_agent/rag/firebase_cache.py` — filters on `find_nearest`; `store` merges cluster doc; corpus stays narrow.
- `research_agent/rag/store.py` — keep `_compatible_level` / `_BAND` as the single level policy (import from here, do not fork).
- `firestore.indexes.json` — new vector composites (local gitignored file today; still document the shape in the PR).
- `scripts/backfill_embeddings.py` — optional `--clusters` to fill `level_band` / cluster id.
- `tests/research_agent/test_firebase_cache.py` and `test_embeddings.py` — cluster filter used when known; sibling levels not in corpus; school/uni still split; unknown cluster falls back.

No Flutter, no `cloud_firestore` in the app.

## Rollout

1. **Schema only** — write `level_band` and keep `topic_cluster` as now. No query change. Backfill band on old docs.
2. **Filter when cluster known** — `find_nearest` with `topic_cluster` + subject. Measure cache hit rate and wrong-subject misses on a few topics (magnets, osmosis, photosynthesis).
3. **Catalog collection** — `topic_clusters` updated on store; `label_prompt` reads aliases from it (cached in process).
4. **Stop** unless data shows titles still miss. Only then consider a single-token cluster prefix in the embedding corpus, re-embed, and compare.

Do not start at step 4.

## How you would know it worked

- Same topic, different wording, same level: more `RAG_ONLY` / cache hits without a web pass.
- Same cluster, adjacent school levels (GCSE vs A-level): may reuse if bands allow; scores still below exact key.
- GCSE query never returns undergraduate packages.
- Lookup latency stays flat or drops as `research_cache` grows, because the vector scan is scoped.
- Admin `levels_seen` on a cluster is a report, not a ranking input.

## Relation to next-features

Depends on: backfill embeddings (un-fingerprinted docs never join the cluster slice).

Pairs with: exam-board picker actually filtering RAG; cache hit vs web in the UI (so you can *see* whether the tighter funnel helped).

Does not replace: fact-checker strict mode, TTL / refresh, or lesson progress / prerequisite gaps in the learner UI. Those gaps stay per-lesson text, not edges in `topic_clusters`.

## Recommended reading

Read these for the *shape* of the design (hard filters, then a similarity score). Skip anything that pushes a full graph database as the retrieval engine.

1. **Doug Turnbull & John Berryman — *Relevant Search***  
   Filter first, then rank with several weak signals. That is this note: subject / cluster / level as must-match, fingerprint as “looks similar,” cluster and board as small bonuses.

2. **Christopher Manning, Prabhakar Raghavan, Hinrich Schütze — *Introduction to Information Retrieval***  
   Why metadata and exact keys beat a blob of similar words, and why you cap a fuzzy score so it cannot outrank an exact hit. Free at [https://nlp.stanford.edu/IR-book/](https://nlp.stanford.edu/IR-book/).

3. **Martin Kleppmann — *Designing Data-Intensive Applications***  
   Documents plus secondary indexes (Firestore cache docs + vector / field indexes) versus a graph store. Justifies keeping `research_cache` and a tiny `topic_clusters` catalog instead of Neo4j.

4. **Chip Huyen — *AI Engineering*** (retrieval / RAG chapters)  
   Embeddings as one stage in a pipeline, not the source of truth. Matches “exact `prompt_key`, then filtered nearest, then lexical fallback.”

5. **Mayank Kejriwal, Craig Knoblock, Pedro Szekely — *Knowledge Graphs: Fundamentals, Techniques, and Applications***  
   What a real graph is (typed edges, identity, provenance). Use it to steal cluster + subject + level as *labels*, and to see why auto-grown “related to” edges go bad — the failure mode this design refuses.

6. **Ian Robinson, Jim Webber, Emil Eifrem — *Graph Databases*** (O’Reilly)  
   How people model “magnetism —taught-at→ GCSE.” Useful as a contrast: we store that as `levels_seen` on a cluster doc and **do not** traverse it at query time in v1.

Do not put extra levels or related-cluster names into the Vertex corpus after reading these. The point of the list is the opposite: structure in filters, wording in the fingerprint.
