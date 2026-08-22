from research_agent.retrieval.freshness import classify_freshness
from research_agent.schema import FreshnessClass


def test_stable_classroom_topics():
    assert classify_freshness("Teach me electromagnetic induction.") is FreshnessClass.STABLE
    assert classify_freshness("Explain photosynthesis.") is FreshnessClass.STABLE
    assert classify_freshness("Explain ionic bonding.") is FreshnessClass.STABLE
    assert classify_freshness("What is electromagnetic induction?") is FreshnessClass.STABLE
    assert classify_freshness("Explain Newton's laws.") is FreshnessClass.STABLE


def test_time_sensitive_topics():
    assert (
        classify_freshness("What is the latest major development in AI?")
        is FreshnessClass.TIME_SENSITIVE
    )
    assert (
        classify_freshness("What are the current UK energy policies?")
        is FreshnessClass.TIME_SENSITIVE
    )
    assert (
        classify_freshness("What is the latest IPCC assessment?")
        is FreshnessClass.TIME_SENSITIVE
    )


def test_mixed_when_stable_and_current():
    assert (
        classify_freshness("Explain photosynthesis using the latest IPCC assessment")
        is FreshnessClass.MIXED
    )
