#!/usr/bin/env zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export PATH="/opt/homebrew/bin:$PATH"

PROJECT="agenticsai2026"
REGION="us-central1"
TEMPLATE="syntra-default"
export CLOUDSDK_API_ENDPOINT_OVERRIDES_MODELARMOR="https://modelarmor.${REGION}.rep.googleapis.com/"

gcloud services enable \
    telemetry.googleapis.com \
    cloudtrace.googleapis.com \
    logging.googleapis.com \
    modelarmor.googleapis.com \
    --project="$PROJECT"

PROJECT_NUMBER="$(gcloud projects describe "$PROJECT" --format='value(projectNumber)')"
SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

gcloud projects add-iam-policy-binding "$PROJECT" \
    --member="serviceAccount:${SA}" \
    --role="roles/telemetry.tracesWriter" \
    --condition=None \
    --quiet \
    --format=none

gcloud projects add-iam-policy-binding "$PROJECT" \
    --member="serviceAccount:${SA}" \
    --role="roles/serviceusage.serviceUsageConsumer" \
    --condition=None \
    --quiet \
    --format=none

gcloud projects add-iam-policy-binding "$PROJECT" \
    --member="serviceAccount:${SA}" \
    --role="roles/modelarmor.user" \
    --condition=None \
    --quiet \
    --format=none

if gcloud model-armor templates describe "$TEMPLATE" \
    --location="$REGION" \
    --project="$PROJECT" >/dev/null 2>&1; then
    echo "Model Armor template ${TEMPLATE} already exists."
else
    echo "Creating Model Armor template ${TEMPLATE}."
    gcloud model-armor templates create "$TEMPLATE" \
        --location="$REGION" \
        --project="$PROJECT" \
        --rai-settings-filters='[{"filterType":"HATE_SPEECH","confidenceLevel":"MEDIUM_AND_ABOVE"},{"filterType":"HARASSMENT","confidenceLevel":"MEDIUM_AND_ABOVE"},{"filterType":"SEXUALLY_EXPLICIT","confidenceLevel":"MEDIUM_AND_ABOVE"},{"filterType":"DANGEROUS","confidenceLevel":"MEDIUM_AND_ABOVE"}]' \
        --pi-and-jailbreak-filter-settings-enforcement=enabled \
        --pi-and-jailbreak-filter-settings-confidence-level=MEDIUM_AND_ABOVE \
        --basic-config-filter-enforcement=enabled \
        --malicious-uri-filter-settings-enforcement=enabled \
        || echo "Warning: could not create Model Armor template; callbacks will fail open until it exists."
fi

gcloud run deploy syntra-orchestrator \
    --source . \
    --project="$PROJECT" \
    --region="$REGION" \
    --port=8080 \
    --timeout=3600 \
    --memory=2Gi \
    --cpu=2 \
    --allow-unauthenticated
