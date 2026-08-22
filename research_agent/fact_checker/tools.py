import json
import os
import random
import threading
from base64 import urlsafe_b64decode
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Any
from urllib.parse import parse_qs, unquote, urlparse

import requests
from bs4 import BeautifulSoup
from requests.adapters import HTTPAdapter

REQUEST_TIMEOUT = 15

_BROWSER_USER_AGENTS = (
    (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/126.0 Safari/537.36"
    ),
    (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"
    ),
    "Mozilla/5.0 (X11; Linux x64; rv:131.0) Gecko/20100101 Firefox/131.0",
)

HEADERS = {
    "User-Agent": _BROWSER_USER_AGENTS[0],
    "Accept": "text/html,application/xhtml+xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
}

_QUERY_EXCLUSIONS = (
    "-site:pinterest.com -site:reddit.com -site:quora.com "
    "-site:tiktok.com -site:instagram.com"
)

_thread_local = threading.local()


def _http() -> requests.Session:
    session = getattr(_thread_local, "session", None)
    if session is None:
        session = requests.Session()
        adapter = HTTPAdapter(pool_connections=4, pool_maxsize=8, max_retries=1)
        session.mount("https://", adapter)
        session.mount("http://", adapter)
        _thread_local.session = session
    return session


def announce_tool(tool, args, tool_context):
    """Print tool activity so `adk run` is not silent during fact checking."""
    detail = (
        args.get("claim")
        or args.get("query")
        or args.get("url")
        or ""
    )
    suffix = f": {detail[:120]}" if detail else ""
    print(f"[{tool.name}]{suffix}", flush=True)


def _html_headers() -> dict[str, str]:
    user_agent = os.getenv("SYNTRA_USER_AGENT") or random.choice(
        _BROWSER_USER_AGENTS
    )
    return {
        "User-Agent": user_agent,
        "Accept": "text/html,application/xhtml+xml;q=0.9,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.9",
    }


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


def _unwrap_url(url: str | None) -> str:
    if not url:
        return ""

    href = url.strip()
    if href.startswith("//"):
        href = "https:" + href
    if href.startswith(("/l/", "/html/")):
        href = "https://duckduckgo.com" + href

    href = _decode_bing_url(href)
    parsed = urlparse(href)

    if "duckduckgo.com" in parsed.netloc:
        uddg = parse_qs(parsed.query).get("uddg")
        if uddg:
            href = unquote(uddg[0])

    return href


def _parse_ddg_results(html: str, max_results: int) -> list[dict[str, str]]:
    soup = BeautifulSoup(html, "html.parser")
    results: list[dict[str, str]] = []

    for result in soup.select(".result")[:max_results]:
        title_element = result.select_one(".result__title")
        link_element = result.select_one(".result__a")
        snippet_element = result.select_one(".result__snippet")

        if not link_element:
            continue

        link = _unwrap_url(link_element.get("href", ""))
        if not link:
            continue

        results.append({
            "title": (
                title_element.get_text(" ", strip=True)
                if title_element
                else ""
            ),
            "url": link,
            "snippet": (
                snippet_element.get_text(" ", strip=True)
                if snippet_element
                else ""
            ),
        })

    return results


def _parse_bing_results(html: str, max_results: int) -> list[dict[str, str]]:
    soup = BeautifulSoup(html, "html.parser")
    results: list[dict[str, str]] = []

    for item in soup.select("li.b_algo"):
        link = item.select_one("h2 a")
        if not link:
            continue

        href = _unwrap_url(link.get("href"))
        parsed = urlparse(href)
        if parsed.scheme not in ("http", "https"):
            continue

        caption = item.select_one(".b_caption p") or item.select_one("p")
        results.append({
            "title": link.get_text(" ", strip=True),
            "url": href,
            "snippet": (
                caption.get_text(" ", strip=True) if caption else ""
            ),
        })
        if len(results) >= max_results:
            break

    return results


def _dedupe_results(
    results: list[dict[str, str]],
    max_results: int,
) -> list[dict[str, str]]:
    unique: list[dict[str, str]] = []
    seen: set[str] = set()

    for result in results:
        url = result.get("url", "")
        if not url or url in seen:
            continue
        seen.add(url)
        unique.append(result)
        if len(unique) >= max_results:
            break

    return unique


# ============================================================
# 1. SEARCH WEB
# ============================================================

def search_web(query: str, max_results: int = 8) -> dict[str, Any]:
    """
    Search the web for independent evidence relating to a claim.

    The Fact Checker should use this to find independent sources
    rather than relying on sources supplied by the Research Agent.
    """

    if not query or not str(query).strip():
        return {
            "success": False,
            "error": "Search query cannot be empty.",
            "results": [],
        }

    query = str(query).strip()
    results: list[dict[str, str]] = []
    errors: list[str] = []

    def _ddg() -> tuple[list[dict[str, str]], str | None]:
        try:
            response = _http().get(
                "https://html.duckduckgo.com/html/",
                params={"q": query},
                headers=_html_headers(),
                timeout=REQUEST_TIMEOUT,
            )
            response.raise_for_status()
            if "anomaly-modal" in response.text:
                return [], None
            return _parse_ddg_results(response.text, max_results), None
        except requests.RequestException as exc:
            return [], f"DuckDuckGo search failed: {exc}"

    def _bing() -> tuple[list[dict[str, str]], str | None]:
        try:
            response = _http().get(
                "https://www.bing.com/search",
                params={"q": f"{query} {_QUERY_EXCLUSIONS}", "count": 10},
                headers=_html_headers(),
                timeout=REQUEST_TIMEOUT,
            )
            response.raise_for_status()
            return _parse_bing_results(response.text, max_results=max_results), None
        except requests.RequestException as exc:
            return [], f"Bing search failed: {exc}"

    with ThreadPoolExecutor(max_workers=2) as pool:
        futures = [pool.submit(_ddg), pool.submit(_bing)]
        for future in as_completed(futures):
            hits, error = future.result()
            results.extend(hits)
            if error:
                errors.append(error)

    results = _dedupe_results(results, max_results)

    if results:
        return {
            "success": True,
            "query": query,
            "results": results,
            "result_count": len(results),
        }

    return {
        "success": False,
        "error": (
            " ".join(errors)
            if errors
            else "No independent evidence was found."
        ),
        "query": query,
        "results": [],
        "result_count": 0,
    }


# ============================================================
# 2. FETCH SOURCE
# ============================================================

def fetch_page(url: str, max_chars: int = 18000) -> dict[str, Any]:
    """
    Retrieve and extract readable text from a source.

    Used by the Fact Checker to inspect the actual evidence
    rather than relying on search snippets.
    """

    url = _unwrap_url(url)

    if not url:
        return {
            "success": False,
            "error": "URL cannot be empty.",
        }

    parsed = urlparse(url)

    if parsed.scheme not in ("http", "https"):
        return {
            "success": False,
            "error": "Only HTTP and HTTPS URLs are supported.",
        }

    try:
        response = _http().get(
            url,
            headers=_html_headers(),
            timeout=REQUEST_TIMEOUT,
        )

        response.raise_for_status()

        soup = BeautifulSoup(response.text, "html.parser")

        # Remove irrelevant page elements.
        for element in soup([
            "script",
            "style",
            "noscript",
            "nav",
            "footer",
            "header",
            "aside",
        ]):
            element.decompose()

        content = (
            soup.find("article")
            or soup.find("main")
            or soup.body
        )

        if not content:
            return {
                "success": False,
                "url": url,
                "error": "Could not extract page content.",
            }

        lines = [
            line.strip()
            for line in content.get_text(
                separator="\n"
            ).splitlines()
            if line.strip()
        ]

        text = "\n".join(lines)

        return {
            "success": True,
            "url": str(response.url) or url,
            "domain": urlparse(str(response.url) or url).netloc,
            "title": (
                soup.title.get_text(strip=True)
                if soup.title
                else ""
            ),
            "content": text[:max_chars],
        }

    except requests.RequestException as e:
        return {
            "success": False,
            "url": url,
            "error": f"Failed to fetch source: {e!s}",
        }

    except (ValueError, TypeError, AttributeError) as e:
        return {
            "success": False,
            "url": url,
            "error": f"Unexpected error: {e!s}",
        }


# ============================================================
# 3. EXTRACT SOURCE DOMAIN
# ============================================================

def get_source_domain(url: str) -> dict[str, Any]:
    """
    Extract the domain of a source.

    This allows the Fact Checker to compare evidence
    from independent organisations.
    """

    try:
        parsed = urlparse(_unwrap_url(url))

        domain = parsed.netloc.lower()

        domain = domain.removeprefix("www.")

        if not domain:
            return {
                "success": False,
                "error": "Could not extract a domain from the URL.",
            }

        return {
            "success": True,
            "domain": domain,
        }

    except (ValueError, TypeError, AttributeError) as e:
        return {
            "success": False,
            "error": str(e),
        }


# ============================================================
# 4. SOURCE AUTHORITY CHECK
# ============================================================

_TIER_TO_AUTHORITY = {
    1: "very_high",
    2: "high",
    3: "medium",
    4: "low",
    5: "unknown",
}


def assess_source_authority(url: str) -> dict[str, Any]:
    """
    Perform a basic source-authority classification.

    IMPORTANT:
    This does not decide whether a claim is true.

    It only provides metadata that the Fact Checker can use
    when evaluating evidence.
    """
    from ..retrieval.authority import evaluate_source

    try:
        result = evaluate_source(url)
        if not result.get("success"):
            return {
                "success": False,
                "error": result.get("error", "Could not classify source."),
            }
        tier = int(result.get("source_tier") or 4)
        return {
            "success": True,
            "domain": result.get("host", ""),
            "authority": _TIER_TO_AUTHORITY.get(tier, "unknown"),
            "source_tier": tier,
            "reason": result.get("reason", ""),
        }

    except (ValueError, TypeError, AttributeError) as e:
        return {
            "success": False,
            "error": str(e),
        }


# ============================================================
# 5. SEARCH FOR INDEPENDENT CONFIRMATION
# ============================================================

def find_independent_evidence(
    claim: str,
    max_results: int = 10,
) -> dict[str, Any]:
    """
    Search specifically for independent evidence supporting
    or contradicting a factual claim.

    This is the main evidence-gathering tool for the Fact Checker.
    """

    if not claim or not str(claim).strip():
        return {
            "success": False,
            "error": "Claim cannot be empty.",
            "evidence": [],
        }

    claim = str(claim).strip()
    queries = [
        f"{claim} educational evidence",
        f"{claim} university",
    ]
    evidence: list[dict[str, Any]] = []
    seen_domains: set[str] = set()

    def _search(query: str) -> list[dict[str, str]]:
        result = search_web(query=query, max_results=max_results)
        if not result["success"]:
            return []
        return result["results"]

    with ThreadPoolExecutor(max_workers=2) as pool:
        futures = [pool.submit(_search, query) for query in queries]
        hits: list[dict[str, str]] = []
        for future in as_completed(futures):
            hits.extend(future.result())

    for result in hits:
        url = result["url"]
        domain_result = get_source_domain(url)
        if not domain_result["success"]:
            continue
        domain = domain_result["domain"]
        if domain in seen_domains:
            continue
        seen_domains.add(domain)
        evidence.append({
            "title": result["title"],
            "url": url,
            "domain": domain,
            "snippet": result["snippet"],
            "authority": assess_source_authority(url),
        })
        if len(evidence) >= max_results:
            break

    return {
        "success": True,
        "claim": claim,
        "evidence": evidence,
        "evidence_count": len(evidence),
    }


# ============================================================
# 6. VERIFY SOURCE CONTENT
# ============================================================

def verify_source_claim(
    url: str,
    claim: str,
) -> dict[str, Any]:
    """
    Retrieve a source and identify whether the source text
    contains evidence relevant to the supplied claim.

    The LLM performs the actual semantic judgement.
    This tool provides the source text.
    """

    page = fetch_page(url)

    if not page["success"]:
        return {
            "success": False,
            "url": url,
            "claim": claim,
            "error": page.get("error", "Failed to fetch source."),
        }

    return {
        "success": True,
        "url": url,
        "claim": claim,
        "source_title": page.get("title", ""),
        "source_domain": page.get("domain", ""),
        "source_content": page.get("content", ""),
    }


# ============================================================
# 7. COMPARE SOURCES
# ============================================================

def compare_sources(
    urls: list[str],
    max_chars_per_source: int = 8000,
) -> dict[str, Any]:
    """
    Fetch multiple sources so the Fact Checker can compare
    independent evidence.
    """

    if not urls:
        return {
            "success": False,
            "error": "At least one URL is required.",
            "sources": [],
        }

    unique_urls: list[str] = []
    seen_domains: set[str] = set()
    for url in urls:
        domain_result = get_source_domain(url)
        if not domain_result["success"]:
            continue
        domain = domain_result["domain"]
        if domain in seen_domains:
            continue
        seen_domains.add(domain)
        unique_urls.append(url)

    def _load(url: str) -> dict[str, Any]:
        return {
            "url": url,
            "domain": get_source_domain(url).get("domain", ""),
            "authority": assess_source_authority(url),
            "page": fetch_page(url, max_chars=max_chars_per_source),
        }

    if unique_urls:
        with ThreadPoolExecutor(max_workers=min(4, len(unique_urls))) as pool:
            sources = list(pool.map(_load, unique_urls))
    else:
        sources = []

    return {
        "success": True,
        "sources": sources,
        "source_count": len(sources),
    }


def _parse_claim_item(item: Any) -> dict[str, Any]:
    if isinstance(item, dict):
        claim = str(item.get("claim") or "").strip()
        return {"claim": claim, "supplied": item}
    text = str(item or "").strip()
    if text.startswith("{"):
        try:
            data = json.loads(text)
            if isinstance(data, dict):
                return {
                    "claim": str(data.get("claim") or text).strip(),
                    "supplied": data,
                }
        except json.JSONDecodeError:
            pass
    return {"claim": text, "supplied": {"claim": text}}


def verify_claims(claims: list[str]) -> dict[str, Any]:
    """
    Independently verify up to 3 claims in parallel.

    For each claim: one search, then fetch the best independent page.
    Prefer this over looping search_web / fetch_page per claim.
    Do not treat sources supplied with the claim as already verified.
    """
    parsed = [_parse_claim_item(claim) for claim in (claims or [])]
    parsed = [item for item in parsed if item["claim"]][:3]
    if not parsed:
        return {
            "success": False,
            "error": "At least one claim is required.",
            "verifications": [],
        }

    def _verify(item: dict[str, Any]) -> dict[str, Any]:
        claim = item["claim"]
        search = search_web(query=claim, max_results=4)
        results = search.get("results") or []
        page = None
        chosen = None
        for result in results:
            page = fetch_page(result["url"], max_chars=8000)
            if page.get("success"):
                chosen = result
                break
        chosen_authority = None
        if chosen and chosen.get("url"):
            chosen_authority = assess_source_authority(chosen["url"])
        return {
            "claim": claim,
            "supplied_evidence": item.get("supplied") or {},
            "search": search,
            "chosen_source": chosen,
            "chosen_source_authority": chosen_authority,
            "page": page,
        }

    with ThreadPoolExecutor(max_workers=len(parsed)) as pool:
        verifications = list(pool.map(_verify, parsed))

    return {
        "success": True,
        "verifications": verifications,
        "claim_count": len(verifications),
    }
