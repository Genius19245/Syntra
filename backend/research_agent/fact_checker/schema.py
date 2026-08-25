from enum import Enum

from pydantic import BaseModel, Field


class Verification(str, Enum):
    VERIFIED = "VERIFIED"
    MOSTLY_VERIFIED = "MOSTLY_VERIFIED"
    PARTIALLY_VERIFIED = "PARTIALLY_VERIFIED"
    UNVERIFIED = "UNVERIFIED"
    CONTRADICTED = "CONTRADICTED"
    OUTDATED = "OUTDATED"
    UNCERTAIN = "UNCERTAIN"


class Confidence(str, Enum):
    HIGH = "HIGH"
    MEDIUM = "MEDIUM"
    LOW = "LOW"


class ClaimSource(BaseModel):
    organisation: str = Field(
        description="Source organisation, e.g. an exam board or scientific body."
    )
    title: str | None = Field(default=None, description="Source title if known.")
    url: str | None = Field(default=None, description="Source URL if retrieved.")
    source_tier: int | None = Field(
        default=None,
        description="Authority tier 1 (highest) to 5 (lowest).",
    )


class VerifiedClaim(BaseModel):
    claim: str = Field(description="The precise factual claim being verified.")
    evidence: str = Field(
        description="Evidence from retrieved sources that supports or contradicts the claim."
    )
    sources: list[ClaimSource] = Field(
        default_factory=list,
        description="Sources attached to this claim only.",
    )
    verification: Verification
    confidence: Confidence
    primary_source: str = Field(
        default="NONE",
        description="Most authoritative organisation supporting the claim, or NONE.",
    )
    secondary_source: str = Field(
        default="NONE",
        description="Corroborating organisation, or NONE.",
    )
    supporting_sources: list[ClaimSource] = Field(default_factory=list)
    contradictory_sources: list[ClaimSource] = Field(default_factory=list)
    notes: str | None = Field(
        default=None,
        description="Caveats, contradictions, or dating concerns.",
    )
    verdict: Verification | None = Field(
        default=None,
        description="Alias of verification for downstream agents.",
    )


class FactCheckReport(BaseModel):
    claims: list[VerifiedClaim] = Field(
        description="One verified record per important factual claim."
    )
