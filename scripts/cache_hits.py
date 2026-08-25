#!/usr/bin/env python3
"""List research_cache documents by hit_count (which topics pay off).

Uses Application Default Credentials and the Firebase Admin SDK, same
as backfill_embeddings.py. Flutter never reads this collection.

Read-only. Does not dump package bodies. Does not call Vertex.

  python scripts/cache_hits.py
  python scripts/cache_hits.py --limit 10
  SYNTRA_FIRESTORE_BACKEND=memory python scripts/cache_hits.py
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / "backend"
if str(BACKEND) not in sys.path:
    sys.path.insert(0, str(BACKEND))

from research_agent.rag.firebase_cache import default_cache

COLUMNS = ("hits", "topic", "subject", "level", "board", "updated_at")
TOPIC_WIDTH = 48


def format_hit_table(rows: list[dict[str, Any]]) -> str:
    if not rows:
        return "No research_cache documents found."
    cells = [{col: _cell(row, col) for col in COLUMNS} for row in rows]
    widths = {col: len(col) for col in COLUMNS}
    for line in cells:
        for col in COLUMNS:
            widths[col] = max(widths[col], len(line[col]))
    header = "  ".join(col.upper().ljust(widths[col]) for col in COLUMNS)
    body = [
        "  ".join(line[col].ljust(widths[col]) for col in COLUMNS) for line in cells
    ]
    return "\n".join([header, *body])


def _cell(row: dict[str, Any], col: str) -> str:
    value = row.get(col, "")
    if col == "hits":
        try:
            return str(int(value or 0))
        except (TypeError, ValueError):
            return "0"
    text = str(value or "").replace("\n", " ").strip()
    if col == "topic" and len(text) > TOPIC_WIDTH:
        return text[: TOPIC_WIDTH - 3] + "..."
    return text


def run(limit: int = 20, cache: Any | None = None) -> int:
    store = cache if cache is not None else default_cache()
    if getattr(store, "backend", None) is None:
        print(
            "Cache backend unavailable. Check Application Default Credentials "
            "or set SYNTRA_FIRESTORE_BACKEND=memory.",
            file=sys.stderr,
        )
        return 1
    rows = store.list_hits(limit=limit)
    print(format_hit_table(rows))
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Show SYNTRA research_cache topics ranked by hit_count."
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=20,
        help="Maximum rows to print (highest hit_count first).",
    )
    args = parser.parse_args()
    return run(limit=max(0, args.limit))


if __name__ == "__main__":
    raise SystemExit(main())
