#!/usr/bin/env python3
"""Backfill Vertex embeddings on research_cache docs that lack a vector.

Uses Application Default Credentials. Does not read or write gitignored
Firebase project files.

  python scripts/backfill_embeddings.py
  python scripts/backfill_embeddings.py --dry-run
  python scripts/backfill_embeddings.py --clusters
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / "backend"
if str(BACKEND) not in sys.path:
    sys.path.insert(0, str(BACKEND))

from research_agent.rag.firebase_cache import default_cache


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Embed older SYNTRA research_cache documents for vector search."
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Count docs missing embeddings without writing.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=400,
        help="Maximum cache documents to scan.",
    )
    parser.add_argument(
        "--clusters",
        action="store_true",
        help="Remap topic_cluster where aliases resolve a stable id.",
    )
    args = parser.parse_args()
    result = default_cache().backfill_embeddings(
        limit=args.limit, dry_run=args.dry_run, clusters=args.clusters
    )
    scanned = result.get("scanned", 0)
    missing = result.get("missing", 0)
    updated = result.get("updated", 0)
    skipped = result.get("skipped", 0)
    print(
        f"scanned={scanned} missing={missing} "
        f"updated={updated} skipped={skipped} dry_run={args.dry_run}"
    )
    if not result.get("success"):
        print(result.get("reason") or "Backfill failed.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
