#!/usr/bin/env python3
"""Backfill Vertex embeddings on research_cache docs that lack a vector.

Uses Application Default Credentials. Does not read or write gitignored
Firebase project files.

  python scripts/backfill_embeddings.py
  python scripts/backfill_embeddings.py --dry-run
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from research_agent.rag.firebase_cache import default_cache  # noqa: E402


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
    args = parser.parse_args()
    result = default_cache().backfill_embeddings(
        limit=args.limit, dry_run=args.dry_run
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
