#!/usr/bin/env zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export PATH="/opt/homebrew/bin:$PATH"

gcloud run deploy syntra-orchestrator \
  --source . \
  --project=agenticsai2026 \
  --region=us-central1 \
  --port=8080 \
  --timeout=3600 \
  --memory=2Gi \
  --cpu=2 \
  --allow-unauthenticated
