#!/usr/bin/env python3
"""Copy apps' privacy policies into this site's pages at deploy time.

An app whose privacy policy is written in its own repo publishes it as a
web page (Early Bloom: early-bloom.hallowedgains.com/privacy, made from
lib/content/privacy_policy.dart by tool/privacy/privacy_page.dart in
Hallowed-Gains-LLC/Premature-Baby-Tracker). That page marks the part to copy:

    <!-- <id>-policy:start --> ... <!-- <id>-policy:end -->

and this site's page has the same two markers where it goes, inside its own
<section id="<id>">, so the section is styled like the rest of the page.
policies/sources.json lists each source: its id, the page here, and the URL.
The app's repo stays the source of truth; nothing fetched is committed (the
deploy only changes its own checkout), so the markers in the committed page
hold a short placeholder.

Usage:
    scripts/fetch-policies.py             Fetch each policy, put it in its
                                          page, and write
                                          policies/versions.json (id -> SHA-256
                                          of what was copied).
    scripts/fetch-policies.py --versions  Print those hashes as JSON, changing
                                          nothing. The deploy workflow compares
                                          them with the live versions.json to
                                          decide whether to redeploy.

A policy that can't be fetched, or doesn't look like one, fails the run: the
site is never deployed with an app's policy missing or replaced by something
else. Standard library only.
"""

import hashlib
import json
import re
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCES = ROOT / "policies" / "sources.json"
VERSIONS = ROOT / "policies" / "versions.json"

# What a copied section may contain: the plain tags the page styles itself.
# Anything else (a script, a style, an iframe, an event attribute) fails the
# run, so a change on the app's side can't put code on this site.
ALLOWED_TAGS = {"h2", "h3", "p", "ul", "ol", "li", "a", "strong", "em", "br"}
FORBIDDEN = re.compile(r"<[^>]*\son\w+\s*=|javascript:", re.IGNORECASE)


def fail(message: str) -> None:
    print(f"fetch-policies: {message}", file=sys.stderr)
    sys.exit(1)


def markers(policy_id: str) -> tuple[str, str]:
    return (f"<!-- {policy_id}-policy:start -->", f"<!-- {policy_id}-policy:end -->")


def between(text: str, policy_id: str, where: str) -> tuple[int, int]:
    """The span between [policy_id]'s markers in [text] (exactly one pair)."""
    start, end = markers(policy_id)
    if text.count(start) != 1 or text.count(end) != 1:
        fail(f"{where} needs exactly one '{start}' and one '{end}'")
    begin = text.index(start) + len(start)
    finish = text.index(end)
    if finish < begin:
        fail(f"{where} has '{end}' before '{start}'")
    return begin, finish


def fetch_section(source: dict) -> str:
    url = source["url"]
    request = urllib.request.Request(
        url, headers={"User-Agent": "hallowedgains-website-deploy"}
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            page = response.read().decode("utf-8")
    except Exception as error:  # noqa: BLE001 - any failure stops the deploy
        fail(f"couldn't fetch {url}: {error}")
    begin, finish = between(page, source["id"], url)
    section = page[begin:finish].strip()

    tags = {tag.lower() for tag in re.findall(r"</?([A-Za-z][\w-]*)", section)}
    unexpected = tags - ALLOWED_TAGS
    if unexpected:
        fail(f"{url} has tags this site doesn't allow: {sorted(unexpected)}")
    if FORBIDDEN.search(section):
        fail(f"{url} has an event attribute or a javascript: link")
    if "<h2" not in section or "<h3" not in section:
        fail(f"{url} doesn't look like a policy (no headings)")
    return section


def digest(section: str) -> str:
    return hashlib.sha256(section.encode("utf-8")).hexdigest()


def main() -> None:
    args = sys.argv[1:]
    if args not in ([], ["--versions"]):
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    sources = json.loads(SOURCES.read_text())["sources"]
    sections = {source["id"]: fetch_section(source) for source in sources}
    versions = {policy_id: digest(text) for policy_id, text in sections.items()}

    if args == ["--versions"]:
        print(json.dumps(versions, indent=2, sort_keys=True))
        return

    for source in sources:
        page_path = ROOT / source["page"]
        page = page_path.read_text()
        begin, finish = between(page, source["id"], source["page"])
        page = page[:begin] + "\n" + sections[source["id"]] + "\n" + page[finish:]
        page_path.write_text(page)
        print(f"fetch-policies: {source['url']} -> {source['page']}#{source['id']}")

    VERSIONS.write_text(json.dumps(versions, indent=2, sort_keys=True) + "\n")
    print(f"fetch-policies: wrote {VERSIONS.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
