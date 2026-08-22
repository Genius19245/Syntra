#!/usr/bin/env zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if lsof -tiTCP:8000 -sTCP:LISTEN >/dev/null 2>&1; then
  lsof -tiTCP:8000 -sTCP:LISTEN | xargs kill
  sleep 1
fi

source "$ROOT/.venv/bin/activate"

# Chrome Flutter runs on a random localhost port. ADK's "*" CORS flag
# is incompatible with credentials, so allow local origins by regex.
adk api_server --port 8000 \
  --allow_origins 'regex:http://localhost:[0-9]+' \
  --allow_origins 'regex:http://127\.0\.0\.1:[0-9]+' &

for _ in {1..20}; do
  if curl -sf "http://127.0.0.1:8000/list-apps" >/dev/null 2>&1 \
    || curl -sf "http://127.0.0.1:8000/apps" >/dev/null 2>&1; then
    break
  fi
  sleep 0.5
done

cd "$ROOT/syntra_app"
# Override the Cloud Run default so this script still uses local ADK.
exec flutter run -d chrome --dart-define=ADK_BASE_URL=http://127.0.0.1:8000
