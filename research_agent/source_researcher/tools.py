import os
import random
from base64 import urlsafe_b64decode
from functools import lru_cache
from urllib.parse import parse_qs, quote, unquote, urlparse

import requests
from bs4 import BeautifulSoup
from requests.adapters import HTTPAdapter

_API_HEADERS = {
    "User-Agent": "SYNTRA/1.0 (educational research agent)",
    "Accept": "application/json",
}
_BROWSER_USER_AGENTS = (
    (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"
    ),
    (
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"
    ),
    (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:131.0) "
        "Gecko/20100101 Firefox/131.0"
    ),
    "Mozilla/5.0 (X11; Linux x86_64; rv:131.0) Gecko/20100101 Firefox/131.0",
)


def _html_headers() -> dict[str, str]:
    user_agent = os.getenv("SYNTRA_USER_AGENT") or random.choice(_BROWSER_USER_AGENTS)
    return {
        "User-Agent": user_agent,
        "Accept": "text/html,application/xhtml+xml;q=0.9,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.9",
    }
_BLOCKED_HOSTS = (
    "pinterest.",
    "reddit.com",
    "quora.com",
    "tiktok.com",
    "instagram.com",
    "facebook.com",
    "twitter.com",
    "x.com",
    "ebay.",
    "amazon.",
    "temu.",
    "bing.com",
    "duckduckgo.com",
)
_QUERY_EXCLUSIONS = (
    "-site:pinterest.com -site:reddit.com -site:quora.com "
    "-site:tiktok.com -site:instagram.com"
)
_MAX_RESULTS = 6
_MAX_PAGE_BYTES = 800_000
_MAX_PAGE_CHARS = 6_000

_session = requests.Session()
_adapter = HTTPAdapter(pool_connections=4, pool_maxsize=8, max_retries=1)
_session.mount("https://", _adapter)
_session.mount("http://", _adapter)


def announce_tool(tool, args, tool_context):
    """Print tool activity so `adk run` is not silent during research."""
    detail = args.get("request") or args.get("query") or args.get("url") or ""
    suffix = f": {detail[:120]}" if detail else ""
    print(f"[{tool.name}]{suffix}", flush=True)


def _host(url: str) -> str:
    return urlparse(url).netloc.lower().removeprefix("www.")


def _is_blocked(url: str) -> bool:
    host = _host(url)
    return any(part in host for part in _BLOCKED_HOSTS)


_TIER1_HOSTS = (
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
    "arxiv.org",
    "ncbi.nlm.nih.gov",
)
_TIER2_HOSTS = (
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
    "britannica.com",
    "khanacademy.org",
    "nationalgeographic.com",
    "si.edu",
)


def _host_matches(host: str, suffixes: tuple[str, ...]) -> bool:
    return any(host == suffix or host.endswith("." + suffix) for suffix in suffixes)


def _authority(url: str) -> int:
    """Lower is better. Matches the Source Researcher hierarchy."""
    host = _host(url)
    # Tier 3 — supporting only. Check before generic .org.
    if host.endswith(("wikipedia.org", "wikimedia.org")):
        return 2
    # Tier 1 — government, universities, scientific orgs, peer-reviewed.
    if (
        host.endswith((".edu", ".gov", ".mil", ".gov.uk"))
        or ".ac." in host
        or _host_matches(host, _TIER1_HOSTS)
    ):
        return 0
    # Tier 2 — educational organisations and academic publishers.
    if _host_matches(host, _TIER2_HOSTS) or host.endswith(".org"):
        return 1
    return 3


def _decode_bing_url(href: str) -> str:
    parsed = urlparse(href)
    if "bing.com" not in parsed.netloc:
        return href
    encoded = parse_qs(parsed.query).get("u", [""])[0]
    if not encoded:
        return href
    encoded = encoded.removeprefix("a1")
    padding = "=" * (-len(encoded) % 4)
    try:
        return urlsafe_b64decode(encoded + padding).decode("utf-8")
    except (ValueError, UnicodeDecodeError):
        return href


def _unwrap_url(href: str | None) -> str | None:
    if not href:
        return None
    href = href.strip()
    if href.startswith("//"):
        href = "https:" + href

    href = _decode_bing_url(href)
    parsed = urlparse(href)
    if "duckduckgo.com" in parsed.netloc:
        uddg = parse_qs(parsed.query).get("uddg")
        if uddg:
            href = unquote(uddg[0])
            parsed = urlparse(href)

    if parsed.scheme not in {"http", "https"}:
        return None
    return parsed._replace(fragment="").geturl()


def _plain(html: str) -> str:
    return BeautifulSoup(html, "html.parser").get_text(" ", strip=True)


def _read_html(url: str, timeout: int) -> tuple[str, str]:
    with _session.get(
        url, timeout=timeout, stream=True, headers=_html_headers()
    ) as response:
        response.raise_for_status()
        content_type = response.headers.get("Content-Type", "").lower()
        if "html" not in content_type and "text/" not in content_type:
            raise ValueError(f"Unsupported content type: {content_type or 'unknown'}")

        chunks: list[bytes] = []
        total = 0
        for chunk in response.iter_content(chunk_size=8192):
            if not chunk:
                continue
            remaining = _MAX_PAGE_BYTES - total
            if remaining <= 0:
                break
            chunks.append(chunk[:remaining])
            total += len(chunks[-1])

        encoding = response.encoding or "utf-8"
        html = b"".join(chunks).decode(encoding, errors="replace")
        return html, str(response.url)


_STOPWORDS = {
    "about",
    "and",
    "for",
    "from",
    "into",
    "lesson",
    "science",
    "the",
    "with",
    "year",
}


def _key_terms(query: str) -> list[str]:
    terms = [
        token.lower().strip(".,:;?!")
        for token in query.split()
        if len(token) > 3 and token.lower() not in _STOPWORDS
    ]
    terms.sort(key=len, reverse=True)
    return terms[:3]


def _title_matches(title: str, terms: list[str]) -> bool:
    if not terms:
        return True
    lowered = title.lower()
    return any(term in lowered for term in terms)


def _wikipedia_search(query: str) -> list[tuple[str, str, str]]:
    terms = _key_terms(query)
    response = _session.get(
        "https://en.wikipedia.org/w/api.php",
        params={
            "action": "query",
            "list": "search",
            "srsearch": query,
            "srlimit": 5,
            "utf8": 1,
            "format": "json",
        },
        headers=_API_HEADERS,
        timeout=10,
    )
    response.raise_for_status()
    hits = []
    for item in response.json().get("query", {}).get("search", []):
        title = item.get("title") or ""
        if (
            not title
            or "disambiguation" in title.lower()
            or not _title_matches(title, terms)
        ):
            continue
        url = "https://en.wikipedia.org/wiki/" + quote(title.replace(" ", "_"))
        snippet = _plain(item.get("snippet") or "")
        hits.append((title, url, snippet))
        if len(hits) >= 2:
            break
    return hits


def _bing_search(query: str) -> list[tuple[str, str, str]]:
    response = _session.get(
        "https://www.bing.com/search",
        params={"q": f"{query} {_QUERY_EXCLUSIONS}", "count": 10},
        headers=_html_headers(),
        timeout=10,
    )
    response.raise_for_status()
    soup = BeautifulSoup(response.text, "html.parser")
    hits = []
    for item in soup.select("li.b_algo"):
        link = item.select_one("h2 a")
        if not link:
            continue
        href = _unwrap_url(link.get("href"))
        if not href or _is_blocked(href):
            continue
        caption = item.select_one(".b_caption p") or item.select_one("p")
        hits.append(
            (
                link.get_text(" ", strip=True),
                href,
                caption.get_text(" ", strip=True) if caption else "",
            )
        )
    return hits


def _wikipedia_extract(url: str) -> str | None:
    parsed = urlparse(url)
    if not parsed.netloc.endswith("wikipedia.org"):
        return None
    title = unquote(parsed.path.split("/wiki/")[-1]).replace("_", " ")
    if not title:
        return None
    response = _session.get(
        "https://en.wikipedia.org/w/api.php",
        params={
            "action": "query",
            "prop": "extracts",
            "explaintext": 1,
            "redirects": 1,
            "titles": title,
            "format": "json",
        },
        headers=_API_HEADERS,
        timeout=12,
    )
    response.raise_for_status()
    pages = response.json().get("query", {}).get("pages", {})
    page = next(iter(pages.values()), {})
    extract = (page.get("extract") or "").strip()
    if not extract:
        return None
    if len(extract) > _MAX_PAGE_CHARS:
        extract = extract[:_MAX_PAGE_CHARS] + "\n[Content truncated]"
    display_title = page.get("title") or title
    final_url = "https://en.wikipedia.org/wiki/" + quote(display_title.replace(" ", "_"))
    return (
        f"Title: {display_title}\n"
        f"Organisation: en.wikipedia.org\n"
        f"URL: {final_url}\n\n"
        f"{extract}"
    )


@lru_cache(maxsize=32)
def search_web(query: str) -> str:
    """
    Search for educational sources.

    Use this first to discover a small set of URLs.
    Rank by the source hierarchy: government, universities, and
    scientific organisations first; Wikipedia only for orientation.
    Then call fetch_page on the best 1-3 results.
    """
    collected: list[tuple[str, str, str]] = []
    errors: list[str] = []

    try:
        collected.extend(_wikipedia_search(query))
    except requests.RequestException as exc:
        errors.append(f"Wikipedia search failed: {exc}")

    try:
        collected.extend(_bing_search(query))
    except requests.RequestException as exc:
        errors.append(f"Web search failed: {exc}")

    unique: list[tuple[str, str, str]] = []
    seen: set[str] = set()
    for title, url, snippet in sorted(collected, key=lambda item: _authority(item[1])):
        if url in seen or _is_blocked(url) or not title:
            continue
        seen.add(url)
        unique.append((title, url, snippet))
        if len(unique) >= _MAX_RESULTS:
            break

    if not unique:
        if errors:
            return "Search failed: " + " ".join(errors)
        return "No useful search results were found. Try a more specific query."

    lines = []
    for index, (title, url, snippet) in enumerate(unique, start=1):
        lines.append(
            f"{index}. {title}\n"
            f"   Organisation: {_host(url)}\n"
            f"   URL: {url}\n"
            f"   Snippet: {snippet}"
        )
    return "\n\n".join(lines)


@lru_cache(maxsize=32)
def fetch_page(url: str) -> str:
    """
    Fetch a source page and return its title plus main readable text.

    Call this after search_web on promising URLs. Do not fetch social,
    shopping, or clearly low-quality pages.
    """
    href = _unwrap_url(url)
    if not href:
        return "Page retrieval failed: invalid URL."
    if _is_blocked(href):
        return f"Skipped low-quality domain: {_host(href)}"

    try:
        wiki = _wikipedia_extract(href)
        if wiki:
            return wiki
        html, final_url = _read_html(href, timeout=12)
    except ValueError as exc:
        return f"Page retrieval failed: {exc}"
    except requests.RequestException as exc:
        return f"Page retrieval failed: {exc}"

    soup = BeautifulSoup(html, "html.parser")
    for element in soup(["script", "style", "noscript", "svg", "form"]):
        element.decompose()
    for element in soup.select("nav, footer, header, aside, [role='navigation']"):
        element.decompose()

    title = soup.title.get_text(" ", strip=True) if soup.title else _host(final_url)
    root = (
        soup.find("article")
        or soup.find("main")
        or soup.find(attrs={"role": "main"})
        or soup.body
        or soup
    )

    parts: list[str] = []
    used = 0
    for tag in root.find_all(["h1", "h2", "h3", "p", "li"]):
        text = tag.get_text(" ", strip=True)
        if len(text) < 40 and tag.name in {"p", "li"}:
            continue
        line = f"## {text}" if tag.name in {"h1", "h2", "h3"} else text
        if used + len(line) + 1 > _MAX_PAGE_CHARS:
            parts.append("[Content truncated]")
            break
        parts.append(line)
        used += len(line) + 1

    body = "\n".join(parts).strip()
    if not body:
        return f"No readable educational content found at {final_url}"

    return (
        f"Title: {title}\n"
        f"Organisation: {_host(final_url)}\n"
        f"URL: {final_url}\n\n"
        f"{body}"
    )
