"""Deterministic source-authority ranking.

The source-evaluation skill handles contextual judgement. This module
supplies host/tier metadata only.
"""

from __future__ import annotations

from urllib.parse import urlparse

TIER_LABELS = {
    1: "tier1_authoritative",
    2: "tier2_academic_or_educational",
    3: "tier3_established_educational",
    4: "tier4_general",
    5: "tier5_unverified",
}

EXAM_BOARD_HOSTS: dict[str, tuple[str, ...]] = {
    "aqa": ("aqa.org.uk",),
    "edexcel": ("qualifications.pearson.com", "pearson.com", "edexcel.com"),
    "pearson": ("qualifications.pearson.com", "pearson.com", "edexcel.com"),
    "ocr": ("ocr.org.uk",),
    "cambridge": (
        "cambridgeinternational.org",
        "cambridgeassessment.org.uk",
        "cie.org.uk",
    ),
    "wjec": ("wjec.co.uk",),
    "sqa": ("sqa.org.uk",),
}

_TIER1_SCIENTIFIC = (
    "nasa.gov",
    "noaa.gov",
    "usgs.gov",
    "nih.gov",
    "cdc.gov",
    "ipcc.ch",
    "who.int",
    "esa.int",
    "unep.org",
    "unesco.org",
    "iaea.org",
    "cern.ch",
    "nature.com",
    "science.org",
    "pnas.org",
    "cell.com",
    "thelancet.com",
    "nejm.org",
    "ncbi.nlm.nih.gov",
)

_TIER1_JOURNALS = (
    "springer.com",
    "wiley.com",
    "sciencedirect.com",
    "elsevier.com",
    "jstor.org",
    "cambridge.org",
    "oup.com",
    "oxfordacademic.com",
    "tandfonline.com",
    "sagepub.com",
    "ieee.org",
    "acm.org",
    "aps.org",
    "rsc.org",
    "acs.org",
)

_TIER2_EDU_ORGS = (
    "khanacademy.org",
    "britannica.com",
    "nationalgeographic.com",
    "si.edu",
    "arxiv.org",
)

_TIER3_REVISION = (
    "bbc.co.uk",
    "bbc.com",
    "wikipedia.org",
    "wikimedia.org",
    "physicsandmathstutor.com",
    "savemyexams.com",
    "senecalearning.com",
    "mathsgenie.co.uk",
    "revisionworld.com",
    "s-cool.co.uk",
    "sparknotes.com",
)

_TIER5_UNVERIFIED = (
    "medium.com",
    "substack.com",
    "wordpress.com",
    "blogspot.com",
    "blogger.com",
    "quora.com",
    "reddit.com",
    "pinterest.",
    "tiktok.com",
    "facebook.com",
    "twitter.com",
    "x.com",
    "instagram.com",
    "yahoo.com",
    "answers.com",
)


def host_of(url: str) -> str:
    if not url:
        return ""
    host = urlparse(url).netloc.lower().removeprefix("www.")
    return host


def _host_matches(host: str, suffixes: tuple[str, ...]) -> bool:
    return any(host == suffix or host.endswith("." + suffix) for suffix in suffixes)


def _all_exam_board_hosts() -> tuple[str, ...]:
    hosts: list[str] = []
    for values in EXAM_BOARD_HOSTS.values():
        hosts.extend(values)
    return tuple(dict.fromkeys(hosts))


def matches_exam_board(url: str, exam_board: str | None) -> bool:
    if not exam_board:
        return False
    key = exam_board.strip().lower().replace(" ", "")
    if key.startswith("pearson"):
        key = "pearson"
    hosts = EXAM_BOARD_HOSTS.get(key)
    if not hosts:
        return False
    return _host_matches(host_of(url), hosts)


def is_scientific_authority(url: str) -> bool:
    host = host_of(url)
    return (
        _host_matches(host, _TIER1_SCIENTIFIC)
        or host.endswith((".gov", ".gov.uk", ".mil"))
        or host in {"gov.uk"}
    )


def source_tier(url: str, organisation: str | None = None) -> int:
    """Return authority tier 1 (highest) through 5 (lowest)."""
    host = host_of(url)
    org = (organisation or "").lower()

    if not host:
        if any(name in org for name in ("aqa", "edexcel", "ocr", "cambridge", "nasa")):
            return 1
        return 4

    if any(part in host for part in _TIER5_UNVERIFIED):
        return 5

    if _host_matches(host, _all_exam_board_hosts()) or _host_matches(
        host, _TIER1_SCIENTIFIC
    ):
        return 1

    if (
        host.endswith((".edu", ".gov", ".mil", ".gov.uk"))
        or host in {"gov.uk"}
        or ".ac." in host
        or _host_matches(host, _TIER1_JOURNALS)
    ):
        return 1

    if _host_matches(host, _TIER2_EDU_ORGS):
        return 2

    if _host_matches(host, _TIER3_REVISION):
        return 3

    if host.endswith(".org"):
        return 2

    return 4


def authority_label(tier: int) -> str:
    return TIER_LABELS.get(tier, TIER_LABELS[4])


def contextual_sort_key(
    url: str,
    *,
    exam_board: str | None = None,
    question_intent: str = "scientific_claim",
    organisation: str | None = None,
) -> tuple[int, int]:
    """Lower tuple sorts first.

    Curriculum questions: a matching official exam-board document outranks
    a scientific agency. Scientific claims: a scientific agency outranks a
    revision website, even if the revision site is popular in classrooms.
    """
    tier = source_tier(url, organisation=organisation)
    intent = (question_intent or "scientific_claim").strip().lower()
    board_hit = matches_exam_board(url, exam_board)

    if intent in {"curriculum", "specification", "exam"}:
        if board_hit:
            return (0, tier)
        if is_scientific_authority(url):
            return (1, tier)
        return (tier + 1, tier)

    if intent in {"scientific_claim", "scientific", "claim"}:
        if is_scientific_authority(url):
            return (0, tier)
        if board_hit:
            return (1, tier)
        return (tier, 0)

    if board_hit:
        return (0, tier)
    return (tier, 0)


def evaluate_source(
    url: str,
    exam_board: str = "",
    question_intent: str = "scientific_claim",
    organisation: str = "",
) -> dict:
    """Return deterministic authority metadata for a URL.

    Contextual overrides (exam-board vs scientific-agency) are encoded in
    ``sort_key`` so callers can rank without re-implementing the hierarchy.
    """
    url = (url or "").strip()
    if not url:
        return {
            "success": False,
            "error": "URL cannot be empty.",
        }

    tier = source_tier(url, organisation=organisation or None)
    sort_key = contextual_sort_key(
        url,
        exam_board=exam_board or None,
        question_intent=question_intent or "scientific_claim",
        organisation=organisation or None,
    )
    host = host_of(url)
    return {
        "success": True,
        "url": url,
        "host": host,
        "source_tier": tier,
        "authority_label": authority_label(tier),
        "exam_board_match": matches_exam_board(url, exam_board or None),
        "scientific_authority": is_scientific_authority(url),
        "question_intent": question_intent or "scientific_claim",
        "sort_key": list(sort_key),
        "reason": (
            f"Tier {tier} ({authority_label(tier)}). "
            f"Intent={question_intent or 'scientific_claim'}."
        ),
    }
