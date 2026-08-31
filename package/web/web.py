"""web: search and fetch pages via a headless browser, for use by an agent
without normal HTTP client access to the JS-heavy modern web.

Uses Bing specifically -- tested against DuckDuckGo (blocked, image
CAPTCHA / 418 page), Startpage (stuck behind a JS challenge), Brave and
Mojeek (also worked, but Bing had the cleanest markup and zero friction).
"""
import base64
import sys
from urllib.parse import quote, urlparse, parse_qs
from playwright.sync_api import sync_playwright

UA = (
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
)


def _decode_bing_url(href):
    """Bing wraps result links in a bing.com/ck/a tracking redirect with
    the real URL base64-encoded (2-char prefix + base64) in the 'u' query
    param. Decode it so callers get a usable direct URL, not a redirect.
    """
    if "bing.com/ck/a" not in href:
        return href
    qs = parse_qs(urlparse(href).query)
    encoded = qs.get("u", [None])[0]
    if not encoded:
        return href
    try:
        body = encoded[2:]  # strip the 2-char prefix Bing adds
        padded = body + "=" * (-len(body) % 4)
        return base64.b64decode(padded).decode()
    except Exception:
        return href


def search(query, limit=8):
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page(user_agent=UA)
        url = f"https://www.bing.com/search?q={quote(query)}"
        page.goto(url, timeout=20000)
        page.wait_for_selector("#b_results", timeout=10000)
        results = page.locator("#b_results > li.b_algo")
        count = min(results.count(), limit)
        for i in range(count):
            item = results.nth(i)
            title_el = item.locator("h2 a").first
            title = title_el.inner_text() if title_el.count() else ""
            href = title_el.get_attribute("href") if title_el.count() else ""
            result_url = _decode_bing_url(href) if href else ""
            snippet_el = item.locator(".b_caption p, .b_algoSlug").first
            snippet = snippet_el.inner_text() if snippet_el.count() else ""
            print(f"{i + 1}. {title}\n   {result_url}\n   {snippet}\n")
        browser.close()


def fetch(url):
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page(user_agent=UA)
        page.goto(url, timeout=20000)
        page.wait_for_load_state("domcontentloaded", timeout=15000)
        print(page.locator("body").inner_text())
        browser.close()


def main():
    args = sys.argv[1:]
    usage = "usage: web search <query...> | web fetch <url>"
    if len(args) >= 2 and args[0] == "search":
        search(" ".join(args[1:]))
    elif len(args) == 2 and args[0] == "fetch":
        fetch(args[1])
    else:
        print(usage, file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main()
