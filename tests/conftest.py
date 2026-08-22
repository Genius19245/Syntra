import os

os.environ.setdefault("SYNTRA_FIRESTORE_BACKEND", "memory")

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
