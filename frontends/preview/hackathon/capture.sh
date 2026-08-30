#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$(cd "$(dirname "$0")" && pwd)"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
PORT=8765

cd "$ROOT"
python3 -m http.server "$PORT" >/tmp/syntra-preview-http.log 2>&1 &
SERVER_PID=$!
trap 'kill "$SERVER_PID" 2>/dev/null || true' EXIT
sleep 0.4

shot() {
  local name="$1"
  local url="$2"
  local w="${3:-1600}"
  local h="${4:-1000}"
  "$CHROME" \
    --headless=new \
    --disable-gpu \
    --hide-scrollbars \
    --force-device-scale-factor=2 \
    --window-size="$w,$h" \
    --virtual-time-budget=4000 \
    --screenshot="$OUT/$name" \
    "$url"
  echo "wrote $OUT/$name"
}

shot "01-mark.png" "http://127.0.0.1:${PORT}/index.html?shot=mark"
shot "02-wordmark.png" "http://127.0.0.1:${PORT}/index.html?shot=name"
shot "03-landing.png" "http://127.0.0.1:${PORT}/index.html?shot=landing"
shot "04-studio.png" "http://127.0.0.1:${PORT}/index.html?shot=studio"
shot "05-pipeline.png" "http://127.0.0.1:${PORT}/index.html?shot=run"
shot "06-ready.png" "http://127.0.0.1:${PORT}/index.html?shot=ready"
shot "07-teach.png" "http://127.0.0.1:${PORT}/index.html?shot=teach"
shot "08-history.png" "http://127.0.0.1:${PORT}/index.html?shot=history"
shot "09-signin.png" "http://127.0.0.1:${PORT}/index.html?shot=signin"
shot "10-hold.png" "http://127.0.0.1:${PORT}/index.html?shot=hold"
shot "11-thumbnail.png" "http://127.0.0.1:${PORT}/thumbnail.html" 1500 1000
shot "12-architecture.png" "http://127.0.0.1:${PORT}/hackathon/architecture.html" 1600 900
cp "$OUT/12-architecture.png" "$OUT/syntra-architecture-16x9.png"
