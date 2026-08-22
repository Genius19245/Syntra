from research_agent.rag.router import decide_mode, plan_retrieval_mode
from research_agent.schema import FreshnessClass, RetrievalMode


def test_time_sensitive_is_web_only_even_with_hits():
    mode = decide_mode(
        FreshnessClass.TIME_SENSITIVE,
        [{"score": 0.9, "title": "stale"}],
    )
    assert mode is RetrievalMode.WEB_ONLY


def test_stable_with_hits_is_rag_only():
    mode = decide_mode(FreshnessClass.STABLE, [{"score": 0.5}])
    assert mode is RetrievalMode.RAG_ONLY


def test_stable_without_hits_is_web_only():
    assert decide_mode(FreshnessClass.STABLE, []) is RetrievalMode.WEB_ONLY


def test_mixed_is_hybrid():
    assert decide_mode(FreshnessClass.MIXED, [{"score": 0.4}]) is RetrievalMode.HYBRID


def test_plan_electromagnetic_induction_prefers_rag():
    plan = plan_retrieval_mode(
        "Teach me electromagnetic induction.",
        education_level="A-Level",
        subject="physics",
    )
    assert plan["freshness"] == "STABLE"
    assert plan["mode"] == "RAG_ONLY"
    assert plan["web_needed"] is False
    assert plan["rag_hit_count"] >= 1


def test_plan_latest_ai_uses_web_only():
    plan = plan_retrieval_mode(
        "What is the latest major development in AI?",
        education_level="",
        subject="",
    )
    assert plan["freshness"] == "TIME_SENSITIVE"
    assert plan["mode"] == "WEB_ONLY"
    assert plan["web_needed"] is True
    assert plan["rag_hit_count"] == 0
