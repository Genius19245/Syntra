import html
import os
import random
import re
import threading
from base64 import urlsafe_b64decode
from concurrent.futures import ThreadPoolExecutor, as_completed
from functools import lru_cache
from urllib.parse import parse_qs, quote, unquote, urlparse

import requests
from bs4 import BeautifulSoup
from google.adk.tools.tool_context import ToolContext
from requests.adapters import HTTPAdapter

from ..retrieval.authority import source_tier
from ..retrieval.session import (
    claim_coverage_met,
    remember_query,
    remember_url,
    web_blocked,
)
from ..retrieval.session import (
    seen_urls as session_seen_urls,
)

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

_thread_local = threading.local()
_URL_LINE = re.compile(r"^\s*URL:\s*(\S+)", re.MULTILINE)
_HTML_TAG = re.compile(r"<[^>]+>")
_SEARCH_HITS: dict[str, tuple[tuple[str, str, str], ...]] = {}


def _http() -> requests.Session:
    session = getattr(_thread_local, "session", None)
    if session is None:
        session = requests.Session()
        adapter = HTTPAdapter(pool_connections=4, pool_maxsize=8, max_retries=1)
        session.mount("https://", adapter)
        session.mount("http://", adapter)
        _thread_local.session = session
    return session


def _host(url: str) -> str:
    return urlparse(url).netloc.lower().removeprefix("www.")


def _is_blocked(url: str) -> bool:
    host = _host(url)
    return any(part in host for part in _BLOCKED_HOSTS)


def _authority(url: str) -> int:
    """Lower is better. Delegates to the shared 1–5 source-tier ranking."""
    return source_tier(url)


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


def _plain(html_text: str) -> str:
    text = html.unescape(_HTML_TAG.sub(" ", html_text or ""))
    return " ".join(text.split())


def _wiki_title(url: str) -> str | None:
    parsed = urlparse(url)
    if not parsed.netloc.endswith("wikipedia.org") or "/wiki/" not in parsed.path:
        return None
    title = unquote(parsed.path.split("/wiki/", 1)[-1]).replace("_", " ").strip()
    return title or None


def _canonical_wiki_url(url: str) -> str | None:
    title = _wiki_title(url)
    if not title:
        return None
    return "https://en.wikipedia.org/wiki/" + quote(title.replace(" ", "_"))


def _read_html(url: str, timeout: int) -> tuple[str, str]:
    with _http().get(
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
    response = _http().get(
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
    response = _http().get(
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
    title = _wiki_title(url)
    if not title:
        return None
    response = _http().get(
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
    final_url = "https://en.wikipedia.org/wiki/" + quote(
        display_title.replace(" ", "_")
    )
    return (
        f"Title: {display_title}\n"
        f"Organisation: en.wikipedia.org\n"
        f"URL: {final_url}\n\n"
        f"{extract}"
    )


def _collect_search_hits(
    query: str,
) -> tuple[tuple[tuple[str, str, str], ...], tuple[str, ...]]:
    cached = _SEARCH_HITS.get(query)
    if cached is not None:
        return cached, ()

    collected: list[tuple[str, str, str]] = []
    errors: list[str] = []

    def _wiki() -> tuple[list[tuple[str, str, str]], str | None]:
        try:
            return _wikipedia_search(query), None
        except requests.RequestException as exc:
            return [], f"Wikipedia search failed: {exc}"

    def _bing() -> tuple[list[tuple[str, str, str]], str | None]:
        try:
            return _bing_search(query), None
        except requests.RequestException as exc:
            return [], f"Web search failed: {exc}"

    with ThreadPoolExecutor(max_workers=2) as pool:
        futures = [pool.submit(_wiki), pool.submit(_bing)]
        for future in as_completed(futures):
            hits, error = future.result()
            collected.extend(hits)
            if error:
                errors.append(error)

    unique: list[tuple[str, str, str]] = []
    seen: set[str] = set()
    for title, url, snippet in sorted(collected, key=lambda item: _authority(item[1])):
        if url in seen or _is_blocked(url) or not title:
            continue
        seen.add(url)
        unique.append((title, url, snippet))
        if len(unique) >= _MAX_RESULTS:
            break

    hits = tuple(unique)
    if hits:
        if len(_SEARCH_HITS) >= 32:
            _SEARCH_HITS.pop(next(iter(_SEARCH_HITS)))
        _SEARCH_HITS[query] = hits
    return hits, tuple(errors)


def _urls_from_search(query: str, listing: str) -> list[str]:
    hits = _SEARCH_HITS.get(query)
    if hits:
        return [url for _, url, _ in hits]
    return _URL_LINE.findall(listing)


def _format_search_hits(
    unique: tuple[tuple[str, str, str], ...],
    errors: tuple[str, ...],
) -> str:
    if not unique:
        if errors:
            return "Search failed: " + " ".join(errors)
        return "No useful search results were found. Try a more specific query."

    lines = []
    for index, (title, url, snippet) in enumerate(unique, start=1):
        tier = source_tier(url)
        lines.append(
            f"{index}. {title}\n"
            f"   Organisation: {_host(url)}\n"
            f"   Source tier: {tier}\n"
            f"   URL: {url}\n"
            f"   Snippet: {snippet}"
        )
    return "\n\n".join(lines)


def search_web(query: str) -> str:
    """
    Search for educational sources.

    Use this first to discover a small set of URLs.
    Rank by the source hierarchy: government, universities, and
    scientific organisations first; Wikipedia only for orientation.
    Then call fetch_page on the best 1-3 results.
    """
    query = " ".join((query or "").split())
    if not query:
        return "No useful search results were found. Try a more specific query."
    return _search_web_cached(query)


@lru_cache(maxsize=32)
def _search_web_cached(query: str) -> str:
    unique, errors = _collect_search_hits(query)
    return _format_search_hits(unique, errors)


def fetch_page(url: str) -> str:
    """
    Fetch a source page and return its title plus main readable text.

    Call this after search_web on promising URLs. Do not fetch social,
    shopping, or clearly low-quality pages.
    """
    href = _unwrap_url(url)
    if not href:
        return "Page retrieval failed: invalid URL."
    href = _canonical_wiki_url(href) or href
    return _fetch_page_cached(href)


@lru_cache(maxsize=32)
def _fetch_page_cached(href: str) -> str:
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
        f"Title: {title}\nOrganisation: {_host(final_url)}\nURL: {final_url}\n\n{body}"
    )


def fetch_pages(
    urls: list[str],
    tool_context: ToolContext | None = None,
) -> str:
    """Fetch up to 3 source pages at the same time."""
    cleaned: list[str] = []
    seen: set[str] = set()
    already = (
        set(session_seen_urls(tool_context)) if tool_context is not None else set()
    )
    for url in urls or []:
        href = (url or "").strip()
        if not href or href in seen or href in already:
            continue
        seen.add(href)
        cleaned.append(href)
        if len(cleaned) >= 3:
            break
    if not cleaned:
        return "No URLs were provided."
    if tool_context is not None:
        for href in cleaned:
            remember_url(tool_context, href)
    if len(cleaned) == 1:
        return fetch_page(cleaned[0])
    with ThreadPoolExecutor(max_workers=len(cleaned)) as pool:
        pages = list(pool.map(fetch_page, cleaned))
    return "\n\n---\n\n".join(
        f"SOURCE {index}\n{page}" for index, page in enumerate(pages, start=1)
    )


def _requested_queries(query: str, queries: list[str] | None) -> list[str]:
    requested: list[str] = []
    seen: set[str] = set()
    for raw in (query, *(queries or [])):
        text = " ".join(str(raw or "").split())
        if not text:
            continue
        key = text.lower()
        if key in seen:
            continue
        seen.add(key)
        requested.append(text)
    return requested


def _gather_one(
    query: str,
    tool_context: ToolContext | None = None,
) -> str:
    if not query or not str(query).strip():
        return "Search query cannot be empty."
    query = " ".join(str(query).split())
    if tool_context is not None and not remember_query(tool_context, query):
        return f"Skipped duplicate query: {query}"
    listing = search_web(query)
    urls = _urls_from_search(query, listing)
    selected: list[str] = []
    already = (
        set(session_seen_urls(tool_context)) if tool_context is not None else set()
    )
    for url in urls:
        if url in already or url in selected:
            continue
        selected.append(url)
        if len(selected) >= 2:
            break
    if not selected:
        return listing
    pages = fetch_pages(selected, tool_context=tool_context)
    return f"SEARCH RESULTS\n{listing}\n\nFETCHED PAGES\n{pages}"


def gather_sources(
    query: str = "",
    queries: list[str] | None = None,
    tool_context: ToolContext | None = None,
) -> str:
    """
    Search once, then fetch the top 2 authoritative pages in parallel.

    Pass queries to search several terms in one call. Prefer this over
    separate search_web + fetch_page calls, or one gather_sources per query.
    Skips duplicate queries and URLs already retrieved in this session.
    """
    if web_blocked(tool_context):
        return "Skipped web research: SYNTRA cache already covered this topic."
    if claim_coverage_met(tool_context):
        return "Skipped further web research: three teachable claims already covered."
    if not queries:
        return _gather_one(str(query or "").strip(), tool_context)

    requested = _requested_queries(query, queries)
    if not requested:
        return "Search query cannot be empty."
    if len(requested) == 1:
        return _gather_one(requested[0], tool_context)

    skipped: list[str] = []
    to_run: list[str] = []
    for item in requested:
        if tool_context is not None and not remember_query(tool_context, item):
            skipped.append(f"Skipped duplicate query: {item}")
        else:
            to_run.append(item)

    listings: list[str] = []
    if to_run:
        with ThreadPoolExecutor(max_workers=len(to_run)) as pool:
            listings = list(pool.map(search_web, to_run))

    already = (
        set(session_seen_urls(tool_context)) if tool_context is not None else set()
    )
    blocks: list[tuple[str, str, list[str]]] = []
    selected_urls: list[str] = []
    for item, listing in zip(to_run, listings):
        selected: list[str] = []
        for url in _urls_from_search(item, listing):
            if url in already or url in selected:
                continue
            selected.append(url)
            already.add(url)
            if len(selected) >= 2:
                break
        blocks.append((item, listing, selected))
        selected_urls.extend(selected)

    if tool_context is not None:
        for href in selected_urls:
            remember_url(tool_context, href)

    pages_by_url: dict[str, str] = {}
    if selected_urls:
        with ThreadPoolExecutor(max_workers=len(selected_urls)) as pool:
            fetched = list(pool.map(fetch_page, selected_urls))
        pages_by_url = dict(zip(selected_urls, fetched))

    sections: list[str] = []
    for item, listing, selected in blocks:
        if selected:
            pages = (
                pages_by_url[selected[0]]
                if len(selected) == 1
                else "\n\n---\n\n".join(
                    f"SOURCE {index}\n{pages_by_url[url]}"
                    for index, url in enumerate(selected, start=1)
                )
            )
            body = f"SEARCH RESULTS\n{listing}\n\nFETCHED PAGES\n{pages}"
        else:
            body = listing
        sections.append(f"QUERY: {item}\n{body}")
    sections.extend(skipped)
    return "\n\n====\n\n".join(sections)
