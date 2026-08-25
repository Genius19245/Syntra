# Duration, timetable, student notes, YouTube

Four classroom-delivery pieces on top of the curriculum SYNTRA already writes. Research and the Firestore cache stay as they are. This is not a graph, not a new retrieval engine.

Highest leverage in [next-features.md](next-features.md) is still lesson playback. These make a curriculum **schedulable and usable in the room** without the student buried in copying.

This is a design note, not a build order.

## Why

Today the curriculum agent returns sections, a teaching sequence, and depth. A teacher still has to guess:

- How long is this? One period or a term?
- What happens on Monday vs week 8?
- What should students hold on paper so they can watch the teacher?
- Which short video is worth ten minutes of homework?

Intake already knows level, board, and goal. It does not ask for **span**. The same magnetism package can be a 50-minute lesson or a 12-week unit. Duration and timetable are **layout**, not new facts.

## What exists today

| Piece | Where | Gap |
| --- | --- | --- |
| Curriculum sections + teaching sequence | `curriculum_agent/agent.py` | No minutes, no dates, no daily vs term |
| Depth | intake + learner profile | Depth ≠ calendar length |
| Research package | Research Agent + `research_cache` | Facts only. No pedagogy media. Agent is told not to web-search at curriculum time. |
| `search_web` | `research_agent/source_researcher/tools.py` | Used for claims, not YouTube. |
| Lesson history | Flutter `LessonStore` | Can store extra payloads later (`teacher` already has a notes-shaped example in tests). |
| Slide / Teacher agents | mentioned in curriculum instructions | Not built. Notes should not wait for slides. |

Curriculum rules already say: do not invent facts, do not create slides or the spoken script yet. Notes and a timetable can sit **after** the curriculum plan, still using only the research package for content.

## 1. Duration

Every curriculum plan should state clock time at two grains:

- **Session** — one sitting (e.g. 40 / 50 / 60 / 90 minutes). Default from a simple intake control, not inferred from the topic title.
- **Span** — how far the plan stretches: **one session**, **one week**, or **one term (~12 weeks / ~3 months)**.

Put duration on the plan as data, not only prose:

```text
## Duration
- Session minutes: 50
- Span: term
- Sessions in span: 24
```

Rules:

- Session minutes are an **input** (teacher picks). The agent fills the sequence to fit; it does not invent a 3-hour double period unless asked.
- Span is an **input**. A one-session plan is a single teaching sequence with minute marks. A term plan is the same topic broken into sessions that sum to the span.
- Do not pad with filler to hit 12 weeks. If the research package is thin, fewer sessions and a “stop / revise / assess” line. Inventing extra content to fill a term is a bad link of a different kind.
- GCSE vs undergraduate still follows the existing level split. A longer span is more practice and sequencing, not automatically higher mathematics.

Minute marks on a single session (example):

| Minutes | Beat |
| --- | --- |
| 0–8 | Hook + prior |
| 8–22 | Core idea |
| 22–38 | Worked example / practice |
| 38–48 | Check + pack away |

Those beats map to existing curriculum sections. Do not add new factual claims here.

## 2. Timetable: daily vs long and deep

Two views of the **same** curriculum, not two research runs.

### Daily (short)

“What do I teach **this** sitting?”

- One date or “next lesson”
- Duration = session minutes
- Sequence with minute marks
- One homework / one video cap
- Student notes for **this** hour only

This is the default when span is one session. Matches “plan the lesson you need tomorrow.”

### Term (long and deep, ~3 months)

“What does this topic look like across a half-term / term?”

- Week grid, then day-of-week only if the teacher supplies a pattern (e.g. Mon + Thu). Do not invent a school calendar.
- Each cell is a **session stub**: title, minutes, objectives covered, notes pack id, optional video id.
- Weeks 1–2: foundations already in the curriculum structure.
- Middle: examples, practice, board-style if the goal is exam.
- Last 1–2 weeks: consolidation and a gap check against prerequisites / objectives (pairs with learner progress in next-features).
- Same cluster of facts as the research package. Later weeks go **deeper on the same claims**, not new unverified topics.

### What the teacher picks at intake

Add span next to level / topic, not a new pipeline:

- **Tomorrow** — one session
- **This week** — 3–5 sessions
- **This term** — ~12 weeks

If they pick term, still generate a **today** slice (week 1, session 1) so the UI is not a 20-page dump. The rest is the grid.

Do not store 12 duplicate research packages. One package, many session rows.

## 3. Notes agent (students look at the teacher)

A **student notes** pack, not the teacher script and not a second curriculum.

Purpose: a short sheet the class can glance at so they **watch the demonstration**, not copy the board for 50 minutes.

### What it is

- Headed by topic, level, board, session date/week
- 1–2 pages (or one screen): definitions they must keep, one diagram prompt, 3–6 bullets, one worked skeleton with blanks
- Tied to **this session’s** learning objectives only
- Language at the profile level (GCSE wording ≠ undergraduate)

### What it is not

- Not a transcript of the teacher
- Not the full research package
- Not exam questions (assessments stay a later feature)
- Not slides
- Not “notes” fields on fact-checker claims

### Agent placement

New sibling under curriculum, after the plan exists:

```text
curriculum_agent
  ├── prerequisite_agent
  ├── learning_objectives_agent
  └── notes_agent        # new
```

`notes_agent` reads: learner profile, objectives for this session, curriculum section for this session, research package. It does **not** call the Research Agent. It does **not** web-search. Facts only from the package.

Output: markdown (and later a printable view in Flutter). Store on the lesson record as `student_notes`, separate from any future `teacher_script`.

Classroom rule to print at the top of the pack: *Look up. These notes are the minimum to keep. The teacher’s example is the lesson.*

If span is a term, one notes pack **per session**, not one giant booklet. A term booklet is a later export.

## 4. YouTube tutorials to watch

Optional **watch list**, after the curriculum exists. Pedagogy media, not a source of scientific truth.

### Rules

- Search is a **bounded tool** (`search_youtube` or `search_web` with `site:youtube.com`), not the Source Researcher claim loop.
- Query from labelled topic + level + “explanation” / “worked example”, e.g. `GCSE magnetism explanation`.
- Cap: **one per session** (homework or starter). Term plans: at most one per week unless the teacher asks for more.
- Prefer length that fits the leftover minutes (e.g. ≤ 12 minutes for a 50-minute lesson with 8 minutes spare).
- Store: title, url, channel, duration if known, why it matches **this session**. Teacher can drop it.
- If search fails, omit. Do not hallucinate a video.
- Do not fetch comments. Do not treat the video as a research claim. If it conflicts with the package, the package wins; skip the video.
- Exam-board named: prefer board-tagged videos when the listing says so; never invent an AQA badge.

### Where it runs

Not inside `curriculum_agent` (that agent is forbidden from web research). A small **media** tool on the orchestrator or a `media_agent` that runs **after** curriculum + notes, using the same labels as `label_prompt` (subject, topic, level). Flutter can show “Watch” under the daily session.

Do not write YouTube URLs into `research_cache`. Cache stays verified packages. Watch list lives on the lesson record.

## Pipeline (when built)

```text
intake (+ session minutes + span)
  → research + profile (unchanged)
  → curriculum (add Duration + session stubs if term)
  → notes_agent (per session in view)
  → youtube search (optional, per session in view)
  → Flutter: Daily | Term toggle
```

Exact `prompt_key` / vector cache behaviour unchanged. Span does not change the cache key. A term plan and a one-off lesson on the same topic **share** research.

## Non-goals

- Do not auto-fill a school’s real timetable (bells, INSET, sports day).
- Do not scrape YouTube transcripts into the research package.
- Do not generate a teacher talking script here (curriculum already defers that).
- Do not use notes as a second fact store.
- Do not mix GCSE and uni sessions on one row because the term is long.
- Do not implement Slide Agent in this slice.

## Files that would change (when built)

- Intake catalog + Flutter intake — session minutes, span (tomorrow / week / term).
- `curriculum_agent/agent.py` — Duration section; term = session stubs from existing structure.
- `curriculum_agent/notes_agent/` — new ADK agent, package-only facts.
- Orchestrator — optional media step after curriculum.
- New YouTube search tool (thin wrapper; reuse HTTP stack from source researcher, different allowlist).
- Flutter result screen — **Daily** vs **Term** views; notes panel; one Watch link.
- `LessonStore` — persist duration, grid, `student_notes`, watch list. Still no client writes to `research_cache`.

Tests: term plan session count × minutes ≤ span; notes contain no claim absent from the package; YouTube omitted when search empty; one-session plan has minute marks; GCSE notes do not include undergraduate-only wording from a mismatched package.

## Rollout

1. **Duration on the plan** — intake minutes + span; curriculum prints Duration and minute marks for one session. No YouTube, no notes agent.
2. **Daily view in Flutter** — show tomorrow’s sequence with the clock.
3. **Notes agent** — one pack per one-session plan. Printable markdown is enough.
4. **Term grid** — session stubs, still one notes pack for “this week’s next session” only.
5. **YouTube** — one optional video per daily session, teacher can dismiss.

Do not start at 5. A wrong video is worse than none.

## How you would know it worked

- Teacher can say how long the lesson is without editing the markdown by hand.
- Tomorrow vs 3-month is a view/span choice, not a second research bill.
- Students have a short sheet and the teacher is still the focus.
- At most one video, skipped if search is empty or off-brief.
- Research cache hit rates unchanged (same packages).
