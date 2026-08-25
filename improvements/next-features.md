# Next features for SYNTRA

Relevant follow-ons given the current pipeline — intake → research + profile → curriculum — plus Firestore `research_cache` and vector search.

Highest leverage: lesson playback and assessments on top of the package already stored, plus a visible “used cache / researched web” line in the UI.

## Research and knowledge

- Turn the Fact Checker back on as an optional “strict mode” so verified lessons cost more time only when the teacher wants it.
- Backfill embeddings on older cache docs (magnets, osmosis, etc.) so they join vector search, not just lexical fallback.
- Show cache hit vs web research in the UI (“reused from SYNTRA cache” vs “researched live”).
- Time-to-live or “refresh this topic” so stale cache packages can be re-researched.


## Learner

- Sign-in so profiles and lessons persist across devices (Firebase Auth; cache stays Admin-only).
- Progress: which objectives were covered, which prerequisites are still gaps.
- Exam-board picker that actually filters RAG (AQA / OCR / Edexcel) when the brief names a board.

## Speed and ops

- Skip Source Researcher retries when RAG_ONLY already covered the three claims.
- Progress stream in the Flutter run screen (label → cache → web → curriculum) so a 2-minute wait feels explained.
- Admin view of `research_cache` hit counts so you can see which topics are paying off.
