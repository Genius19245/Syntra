"""Persist verified research packages into the local knowledge corpus."""

from __future__ import annotations

import json
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from ..schema import PackageClaim, ResearchPackage
from .indexer import KnowledgeDocument
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


def should_persist(
    package: ResearchPackage,
    claims: list[PackageClaim] | None = None,
) -> tuple[bool, str]:
    freshness = ""
    if package.research_method and package.research_method.freshness:
        freshness = str(package.research_method.freshness.value)
    if freshness == "TIME_SENSITIVE":
        return False, "Time-sensitive research is not stored in RAG."
    if not package.topic.strip():
        return False, "Package has no topic."
    kept = storable_claims(package) if claims is None else claims
    if not kept:
        return False, "No verified claims to store."
    return True, "ok"


def package_relative_path(package: ResearchPackage) -> str:
    subject = slugify(package.subject or "general", "general")
    level = slugify(
        normalize_level(package.education_level) or "unspecified", "unspecified"
    )
    topic = slugify(package.topic, "topic")
    return f"previous_research/{subject}/{level}/{topic}.md"


def _render_package_parts(
    package: ResearchPackage,
    *,
    checked: str,
    claims: list[PackageClaim],
) -> tuple[str, dict[str, Any], str]:
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
        "education_level": normalize_level(package.education_level)
        or package.education_level,
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
    body_lines = [f"# {package.topic.strip()}", ""]
    if package.key_concepts:
        body_lines.append("## Key concepts")
        for concept in package.key_concepts:
            body_lines.append(f"- {concept}")
        body_lines.append("")
    if package.learning_objectives:
        body_lines.append("## Learning objectives")
        for objective in package.learning_objectives:
            body_lines.append(f"- {objective}")
        body_lines.append("")
    for index, claim in enumerate(claims, start=1):
        body_lines.append(f"## Claim {index}")
        body_lines.append("")
        body_lines.append(claim.claim.strip())
        body_lines.append("")
        body_lines.append(f"Evidence: {claim.evidence.strip()}")
        if claim.verification:
            body_lines.append(f"Verdict: {claim.verification.verdict}")
            body_lines.append(f"Confidence: {claim.verification.confidence}")
        if claim.sources:
            body_lines.append("Sources:")
            for source in claim.sources:
                label = source.organisation
                if source.url:
                    label = f"{label} ({source.url})"
                body_lines.append(f"- {label}")
        body_lines.append("")
    if package.misconceptions:
        body_lines.append("## Misconceptions")
        for item in package.misconceptions:
            body_lines.append(f"- {item}")
        body_lines.append("")
    if package.uncertainties:
        body_lines.append("## Uncertainties")
        for item in package.uncertainties:
            body_lines.append(f"- {item}")
        body_lines.append("")
    body = "\n".join(body_lines).strip()
    markdown = "\n".join(lines) + "\n" + body + "\n"
    return markdown, metadata, body


def render_package_markdown(
    package: ResearchPackage,
    *,
    checked: str | None = None,
    claims: list[PackageClaim] | None = None,
) -> str:
    checked = checked or datetime.now(timezone.utc).date().isoformat()
    claims = storable_claims(package) if claims is None else claims
    markdown, _, _ = _render_package_parts(package, checked=checked, claims=claims)
    return markdown


def persist_research_package(
    package: ResearchPackage,
    *,
    store: KnowledgeStore | None = None,
    root: Path | None = None,
    checked: str | None = None,
) -> dict[str, Any]:
    """Write verified claims to previous_research/ and refresh the store."""
    claims = storable_claims(package)
    ok, reason = should_persist(package, claims=claims)
    if not ok:
        return {"success": True, "stored": False, "reason": reason}

    target_store = store or default_store()
    base = Path(root) if root is not None else Path(target_store.root)
    relative = package_relative_path(package)
    markdown, metadata, body = _render_package_parts(
        package,
        checked=checked or datetime.now(timezone.utc).date().isoformat(),
        claims=claims,
    )
    path = base / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(markdown, encoding="utf-8")
    document = KnowledgeDocument(path=relative, body=body, metadata=metadata)
    added = target_store.upsert(document)
    return {
        "success": True,
        "stored": True,
        "reason": "Verified research saved to persistent RAG.",
        "path": relative,
        "claim_count": len(claims),
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
        raise TypeError("Research package must be a JSON object.")
    return ResearchPackage.model_validate(data)
