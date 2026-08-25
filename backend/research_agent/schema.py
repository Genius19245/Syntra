from datetime import datetime, timezone
from enum import Enum
from typing import Any

from pydantic import BaseModel, ConfigDict, Field


class FreshnessClass(str, Enum):
    STABLE = "STABLE"
    RECENT = "RECENT"
    TIME_SENSITIVE = "TIME_SENSITIVE"
    MIXED = "MIXED"


class RetrievalMode(str, Enum):
    RAG_ONLY = "RAG_ONLY"
    WEB_ONLY = "WEB_ONLY"
    HYBRID = "HYBRID"


class Confidence(str, Enum):
    HIGH = "HIGH"
    MEDIUM = "MEDIUM"
    LOW = "LOW"


class SourceRecord(BaseModel):
    model_config = ConfigDict(extra="ignore")

    organisation: str = Field(description="Source organisation or document owner.")
    title: str | None = Field(default=None, description="Document or page title.")
    url: str | None = Field(default=None, description="Retrieved URL. Never invented.")
    source_tier: int | None = Field(
        default=None,
        ge=1,
        le=5,
        description="Authority tier 1 (highest) to 5 (lowest).",
    )
    source_authority: str | None = Field(
        default=None,
        description="Short authority label, e.g. official_exam_board.",
    )


class Evidence(BaseModel):
    model_config = ConfigDict(extra="ignore")

    claim: str
    evidence: str
    source: str
    url: str = ""
    source_authority: str = ""
    source_tier: int = Field(default=4, ge=1, le=5)
    publication_date: str = ""
    retrieved_date: str = Field(
        default_factory=lambda: datetime.now(timezone.utc).date().isoformat()
    )
    topic: str = ""
    education_level: str = ""
    confidence: Confidence = Confidence.MEDIUM
    relevant_passage: str = ""

    def as_fact_check_input(self) -> dict[str, Any]:
        return {
            "claim": self.claim,
            "evidence": self.evidence,
            "sources": [
                {
                    "organisation": self.source,
                    "url": self.url,
                    "source_tier": self.source_tier,
                }
            ],
            "confidence": self.confidence.value
            if isinstance(self.confidence, Confidence)
            else str(self.confidence),
        }


class ClaimVerification(BaseModel):
    model_config = ConfigDict(extra="ignore")

    verdict: str
    confidence: str | float
    supporting_sources: list[SourceRecord] = Field(default_factory=list)
    contradictory_sources: list[SourceRecord] = Field(default_factory=list)
    notes: str | None = None


class PackageClaim(BaseModel):
    model_config = ConfigDict(extra="ignore")

    claim: str
    evidence: str
    sources: list[SourceRecord] = Field(default_factory=list)
    verification: ClaimVerification | None = None


class ResearchMethod(BaseModel):
    model_config = ConfigDict(extra="ignore")

    rag_used: bool = False
    web_used: bool = False
    fact_check_used: bool = False
    freshness: FreshnessClass | None = None
    retrieval_mode: RetrievalMode | None = None


class ResearchPackage(BaseModel):
    model_config = ConfigDict(extra="ignore")

    topic: str
    subject: str = ""
    education_level: str = ""
    exam_board: str = ""
    learning_objectives: list[str] = Field(default_factory=list)
    key_concepts: list[str] = Field(default_factory=list)
    claims: list[PackageClaim] = Field(default_factory=list)
    misconceptions: list[str] = Field(default_factory=list)
    uncertainties: list[str] = Field(default_factory=list)
    sources: list[SourceRecord] = Field(default_factory=list)
    research_method: ResearchMethod = Field(default_factory=ResearchMethod)
