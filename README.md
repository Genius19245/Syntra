# SYNTRA

SYNTRA turns a teacher’s topic, level, and exam board into a classroom-ready curriculum. A Flutter studio sends the brief to a Google ADK orchestrator: research and learner profile run in parallel, then curriculum, prerequisites, and learning objectives are assembled.

Research prefers a shared cache of verified packages (server-side Admin SDK). Stable topics can skip live web search. The Flutter app never writes that cache.

## Run locally

Python 3.11+, Flutter, and Application Default Credentials for Vertex AI.

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
./scripts/dev.sh
```

`./scripts/dev.sh` starts ADK on port 8000 (apps from `backend/`) and launches the Flutter app against that local server. `pytest.ini` puts `backend/` on `PYTHONPATH`.

To run the app against the deployed orchestrator instead:

```bash
cd frontends/syntra_app
flutter run -d chrome --dart-define-from-file=firebase.defines.json
```

Omit `--dart-define-from-file` if you do not have Firebase Auth locally. Sign-in is skippable; guest mode still talks to Cloud Run.

## Reproducible Testing

These steps are what the project gallery and reviewers should follow. Automated tests do not call Vertex AI, Firestore, or Cloud Run.

### 1. Automated tests (no cloud credentials)

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
pytest
```

`tests/conftest.py` forces an in-memory research cache and turns telemetry export off. Then:

```bash
cd frontends/syntra_app
flutter test
```

### 2. Studio against the live orchestrator (gallery path)

The Flutter app defaults to Cloud Run at
`https://syntra-orchestrator-459448503831.us-central1.run.app`.
Do not set `ADK_BASE_URL`.

```bash
curl -sf https://syntra-orchestrator-459448503831.us-central1.run.app/list-apps
cd frontends/syntra_app
flutter run -d chrome --dart-define-from-file=firebase.defines.json
```

If `firebase.defines.json` is missing, run `flutter run -d chrome` and skip sign-in.

**Walkthrough**

1. Open the studio in Chrome. Use **Skip for now** if Sign in appears.
2. Click **Create New Lesson**.
3. Choose **GCSE**, exam board **AQA**, subject **Mathematics**, topic **Quadratic equations** (or tap a suggestion).
4. Leave strict verification and refresh-cache off (faster; cached topics skip live web search).
5. Click **Launch curriculum**.
6. Watch the run screen stream research, then curriculum, prerequisites, and learning objectives.
7. On the ready screen, open **View Lesson** for slides and the teaching pack. **Past lessons** should list this brief on the same device.

A full pipeline run typically takes a few minutes. Cached topics return faster.

### 3. Local ADK instead of Cloud Run

Only if you need to test agents on this machine:

```bash
gcloud auth application-default login
./scripts/dev.sh
```

That starts ADK on port 8000 and points Flutter at `http://127.0.0.1:8000`. Repeat the walkthrough above.

## Layout

- `frontends/syntra_app/` — teacher studio (Flutter)
- `frontends/preview/` — static landing preview
- `backend/syntra_orchestrator/` — ADK root agent
- `backend/research_agent/` — research, RAG retrieval, optional fact checking
- `backend/curriculum_agent/` — profile, prerequisites, curriculum, lesson plan
- `backend/learning_objectives_agent/` — measurable outcomes
- `tests/` — pytest suite (`pytest`)

Local `.env` files, generated research markdown, and Firebase project files stay out of git.
