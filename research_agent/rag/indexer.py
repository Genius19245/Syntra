"""Load markdown knowledge files with YAML-like frontmatter."""

from __future__ import annotations

import os
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

KNOWLEDGE_ROOT = Path(
    os.environ.get("SYNTRA_KNOWLEDGE_ROOT")
    or Path(__file__).resolve().parent.parent / "knowledge"
)
_HEADING = re.compile(r"\n(?=## )")


@dataclass
class KnowledgeDocument:
    path: str
    body: str
    metadata: dict[str, Any] = field(default_factory=dict)

    @property
    def title(self) -> str:
        return str(self.metadata.get("title") or Path(self.path).stem)


def parse_frontmatter(text: str) -> tuple[dict[str, Any], str]:
    stripped = text.lstrip("\ufeff")
    if not stripped.startswith("---"):
        return {}, stripped
    parts = stripped.split("---", 2)
    if len(parts) < 3:
        return {}, stripped
    raw_meta, body = parts[1], parts[2]
    metadata: dict[str, Any] = {}
    for line in raw_meta.splitlines():
        line = line.strip()
        if not line or line.startswith("#") or ":" not in line:
            continue
        key, value = line.split(":", 1)
        metadata[key.strip()] = _scalar(value.strip())
    return metadata, body.lstrip("\n")


def _scalar(value: str) -> Any:
    if value.startswith(("'", '"')) and value.endswith(("'", '"')) and len(value) >= 2:
        return value[1:-1]
    lowered = value.lower()
    if lowered in {"true", "false"}:
        return lowered == "true"
    if value.isdigit() or (value.startswith("-") and value[1:].isdigit()):
        return int(value)
    try:
        return float(value)
    except ValueError:
        return value


def chunk_document(document: KnowledgeDocument) -> list[KnowledgeDocument]:
    """Split markdown on ## headings so claims retrieve independently."""
    body = document.body.strip()
    if not body or "## " not in body:
        return [document]
    parts = [part.strip() for part in _HEADING.split("\n" + body) if part.strip()]
    if len(parts) <= 1:
        return [document]
    chunks: list[KnowledgeDocument] = []
    for index, part in enumerate(parts):
        heading = part.split("\n", 1)[0].lstrip("# ").strip()
        metadata = dict(document.metadata)
        metadata["chunk"] = index
        metadata["chunk_title"] = heading
        chunks.append(
            KnowledgeDocument(
                path=f"{document.path}#{index}",
                body=part,
                metadata=metadata,
            )
        )
    return chunks or [document]


def index_knowledge(root: Path | None = None) -> list[KnowledgeDocument]:
    base = Path(root) if root is not None else KNOWLEDGE_ROOT
    if not base.exists():
        return []
    documents: list[KnowledgeDocument] = []
    for path in sorted(base.rglob("*.md")):
        if path.name.lower() == "readme.md":
            continue
        text = path.read_text(encoding="utf-8")
        metadata, body = parse_frontmatter(text)
        if not body.strip():
            continue
        document = KnowledgeDocument(
            path=str(path.relative_to(base)),
            body=body.strip(),
            metadata=metadata,
        )
        documents.extend(chunk_document(document))
    return documents
