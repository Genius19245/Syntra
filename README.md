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

`./scripts/dev.sh` starts ADK on port 8000 and launches the Flutter app against that local server.

To run the app against the deployed orchestrator instead:

```bash
cd syntra_app
flutter run -d chrome
```

## Layout

- `syntra_app/` — teacher studio (Flutter)
- `syntra_orchestrator/` — ADK root agent
- `research_agent/` — research, RAG retrieval, optional fact checking
- `curriculum_agent/` — profile, prerequisites, curriculum
- `learning_objectives_agent/` — measurable outcomes
- `tests/` — pytest suite (`pytest`)

Local `.env` files, generated research markdown, and Firebase project files stay out of git.
