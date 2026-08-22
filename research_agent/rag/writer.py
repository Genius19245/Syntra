"""Persist verified research packages into the local knowledge corpus."""

from __future__ import annotations

import json
import re
from datetime import date
from pathlib import Path
from typing import Any

from ..schema import PackageClaim, ResearchPackage
from .indexer import KnowledgeDocument, parse_frontmatter
from .store import KnowledgeStore, default_store, normalize_level

STORABLE_VERDICTS = {
    "VERIFIED",
    "MOSTLY_VERIFIED",
    "PARTIALLY_VERIFIED",
}
_SLUG = re.compile(r"[^a-z0-9]+")


def slugify(text: str, fallback: str = "topic") -> str:
    slug = _SLUG.sub("-", (text or "").lower()).strip("-")
    return slug[:80] or fallback


def _yaml_value(value: Any) -> str:
    if value is None:
        return '""'
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int) and not isinstance(value, bool):
        return str(value)
    text = str(value).strip()
    if not text:
        return '""'
    return json.dumps(text)


def _verdict(claim: PackageClaim) -> str:
    if claim.verification is None:
        return ""
    return str(claim.verification.verdict or "").upper().replace(" ", "_")


def _fact_check_required(package: ResearchPackage) -> bool:
    if package.research_method is None:
        return True
    return bool(package.research_method.fact_check_used)


def storable_claims(package: ResearchPackage) -> list[PackageClaim]:
    kept: list[PackageClaim] = []
    require_verdict = _fact_check_required(package)
    for claim in package.claims:
        verdict = _verdict(claim)
        if verdict in {"UNVERIFIED", "CONTRADICTED"}:
            continue
        if require_verdict:
            if verdict in STORABLE_VERDICTS:
                kept.append(claim)
        elif claim.claim.strip():
            kept.append(claim)
    return kept


def should_persist(package: ResearchPackage) -> tuple[bool, str]:
    freshness = ""
    if package.research_method and package.research_method.freshness:
        freshness = str(package.research_method.freshness.value)
    if freshness == "TIME_SENSITIVE":
        return False, "Time-sensitive research is not stored in RAG."
    if not package.topic.strip():
        return False, "Package has no topic."
    if not storable_claims(package):
        return False, "No verified claims to store."
    return True, "ok"


def package_relative_path(package: ResearchPackage) -> str:
    subject = slugify(package.subject or "general", "general")
    level = slugify(normalize_level(package.education_level) or "unspecified", "unspecified")
    topic = slugify(package.topic, "topic")
    return f"previous_research/{subject}/{level}/{topic}.md"


def render_package_markdown(package: ResearchPackage, *, checked: str | None = None) -> str:
    checked = checked or date.today().isoformat()
    claims = storable_claims(package)
    tiers = [
        source.source_tier
        for claim in claims
        for source in claim.sources
        if source.source_tier
    ]
    source_tier = min(tiers) if tiers else 2
    orgs = []
    for claim in claims:
        for source in claim.sources:
            if source.organisation and source.organisation not in orgs:
                orgs.append(source.organisation)
    primary = orgs[0] if orgs else "SYNTRA research"

    metadata = {
        "source": primary,
        "authority": "previous_research",
        "source_tier": source_tier,
        "topic": package.topic,
        "subject": package.subject,
        "education_level": normalize_level(package.education_level) or package.education_level,
        "exam_board": package.exam_board,
        "publication_date": checked,
        "last_checked": checked,
        "content_type": "previous_research",
        "url": "",
        "title": package.topic,
    }
    lines = ["---"]
    for key, value in metadata.items():
        lines.append(f"{key}: {_yaml_value(value)}")
    lines.append("---")
    lines.append("")
    lines.append(f"# {package.topic.strip()}")
    lines.append("")
    if package.key_concepts:
        lines.append("## Key concepts")
        for concept in package.key_concepts:
            lines.append(f"- {concept}")
        lines.append("")
    if package.learning_objectives:
        lines.append("## Learning objectives")
        for objective in package.learning_objectives:
            lines.append(f"- {objective}")
        lines.append("")
    for index, claim in enumerate(claims, start=1):
        lines.append(f"## Claim {index}")
        lines.append("")
        lines.append(claim.claim.strip())
        lines.append("")
        lines.append(f"Evidence: {claim.evidence.strip()}")
        if claim.verification:
            lines.append(f"Verdict: {claim.verification.verdict}")
            lines.append(f"Confidence: {claim.verification.confidence}")
        if claim.sources:
            lines.append("Sources:")
            for source in claim.sources:
                label = source.organisation
                if source.url:
                    label = f"{label} ({source.url})"
                lines.append(f"- {label}")
        lines.append("")
    if package.misconceptions:
        lines.append("## Misconceptions")
        for item in package.misconceptions:
            lines.append(f"- {item}")
        lines.append("")
    if package.uncertainties:
        lines.append("## Uncertainties")
        for item in package.uncertainties:
            lines.append(f"- {item}")
        lines.append("")
    return "\n".join(lines).strip() + "\n"


def persist_research_package(
    package: ResearchPackage,
    *,
    store: KnowledgeStore | None = None,
    root: Path | None = None,
    checked: str | None = None,
) -> dict[str, Any]:
    """Write verified claims to previous_research/ and refresh the store."""
    ok, reason = should_persist(package)
    if not ok:
        return {"success": True, "stored": False, "reason": reason}

    target_store = store or default_store()
    base = Path(root) if root is not None else Path(target_store.root)
    relative = package_relative_path(package)
    markdown = render_package_markdown(package, checked=checked)
    path = base / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(markdown, encoding="utf-8")
    metadata, body = parse_frontmatter(markdown)
    document = KnowledgeDocument(path=relative, body=body.strip(), metadata=metadata)
    added = target_store.upsert(document)
    return {
        "success": True,
        "stored": True,
        "reason": "Verified research saved to persistent RAG.",
        "path": relative,
        "claim_count": len(storable_claims(package)),
        "chunk_count": added,
    }


def parse_package(payload: str | dict[str, Any]) -> ResearchPackage:
    if isinstance(payload, ResearchPackage):
        return payload
    if isinstance(payload, str):
        data = json.loads(payload)
    else:
        data = payload
    if not isinstance(data, dict):
        raise ValueError("Research package must be a JSON object.")
    return ResearchPackage.model_validate(data)
