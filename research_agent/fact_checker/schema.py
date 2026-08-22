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
        description="Source organisation, e.g. IPCC, NASA, NOAA."
    )
    title: str | None = Field(default=None, description="Source title if known.")
    url: str | None = Field(default=None, description="Source URL if retrieved.")


class VerifiedClaim(BaseModel):
    claim: str = Field(description="The precise factual claim being verified.")
    evidence: str = Field(
        description="Evidence from retrieved sources that supports or contradicts the claim."
    )
    sources: list[ClaimSource] = Field(
        description="Sources attached to this claim only."
    )
    verification: Verification
    confidence: Confidence
    primary_source: str = Field(
        description="Most authoritative organisation supporting the claim, or NONE."
    )
    secondary_source: str = Field(
        description="Corroborating organisation, or NONE."
    )
    notes: str | None = Field(
        default=None,
        description="Caveats, contradictions, or dating concerns.",
    )


class FactCheckReport(BaseModel):
    claims: list[VerifiedClaim] = Field(
        description="One verified record per important factual claim."
    )
