import os

os.environ.setdefault("SYNTRA_FIRESTORE_BACKEND", "memory")
os.environ.setdefault("SYNTRA_OTEL_EXPORTER", "off")
os.environ.setdefault("ADK_CAPTURE_MESSAGE_CONTENT_IN_SPANS", "false")
os.environ.setdefault(
    "OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT", "NO_CONTENT"
)

import pytest
from research_agent.rag.embeddings import reset_embedder
from research_agent.rag.firebase_cache import MemoryBackend, reset_cache_backend


@pytest.fixture(autouse=True)
def isolated_firestore_cache():
    reset_cache_backend(MemoryBackend())
    reset_embedder(None)
    yield
    reset_cache_backend("unset")
    reset_embedder("unset")
