#!/usr/bin/env python3
"""Docs-link liveness + drift canary for AGENTS.md.

AGENTS.md is moving from RESTATING the public Minimal docs to ROUTING to them.
Routing beats restating because a restatement drifts silently -- AGENTS.md has
already taught `min` command spellings that no longer match the shipped
sandbox helper. But routing trades that failure mode for two new ones, and this
script watches both:

  1. LIVENESS -- the linked page must still be there. A dead link is strictly
     worse than the duplication it replaced: an agent that follows it gets
     nothing at all, where before it got stale-but-useful prose. BLOCKING.

  2. DRIFT -- the linked page's text changed. AGENTS.md is not automatically
     wrong when that happens (it links, it does not restate), but the section
     that routes there deserves a re-read. REPORT-ONLY.

That asymmetry is the whole design. See the workflow header for why this repo
deliberately splits the two verdicts where gominimal/minimal-skills fails on
both.

WHAT EACH LIVENESS VERDICT MEANS -- read before acting on a row.

  dead       404/410, or the redirect chain lands under `/auth/`. Actionable,
             and the only verdict that fails this check. Fix by repointing the
             link or removing it.
  unknown    Timeout, TLS failure, 403, 5xx, or any other code. NOT actionable
             and NOT a failure -- a runner's egress is not the last word on
             whether a page exists. Collapsing this into `dead` is the single
             easiest way to make a blocking check untrustworthy, at which point
             people start ignoring it.
  ok         2xx and not auth-gated.

`/auth/` is checked explicitly because it does NOT show up as an error code:
`https://minimal.dev/start/<page>` answers 200 after redirecting to
`/auth/login`, so a naive status check passes an auth-gated page that no agent
can actually read. Per the URL contract in gominimal/minimal-skills
`evals/SCHEMA.md`, only `/docs/reference/` and `/docs/concepts/` are publicly
linkable; `/start/` (published from `docs/guide/`) is not.

DRIFT IS HASHED OVER PAGE CONTENT, NOT THE PAGE.

The hash covers the visible text inside the page's `<main>` element, with tags
stripped and whitespace collapsed -- not the raw HTML. Hashing whole pages does
not work here: site chrome (nav, footer, the sidebar listing every other
reference page) is embedded in every page, so one unrelated docs page being
added re-hashes the entire set at once. That is not hypothetical -- at the time
of writing, all 9 URLs in minimal-skills' whole-page snapshot report drift
simultaneously, which is the signature of a chrome change rather than 9 edits.
A canary that cries wolf on every deploy gets its snapshot bumped unread, which
is the same as not having one.

Network: unauthenticated HTTPS GETs against minimal.dev only. No secrets, no
auth, no writes. Untrusted values are Markdown-escaped before reaching the
summary.

Modes:
  (default)   check liveness + drift; exit 1 only if a link is dead.
  --update    refresh the snapshot from what is live now, then exit 0.
  --report-only  never exit non-zero for a liveness verdict either.
"""

from __future__ import annotations

import argparse
import hashlib
import html
import json
import os
import re
import subprocess
import sys
import tempfile

DEFAULT_SOURCE = "AGENTS.md"
DEFAULT_SNAPSHOT = ".github/docs-snapshots.json"

# Trailing punctuation is stripped separately -- a URL at the end of a sentence
# or inside `<...>` must not carry the delimiter into the request.
_URL_RE = re.compile(r"https://minimal\.dev/[A-Za-z0-9._~:/?#\[\]@!$&'()*+,;=%-]+")
_TRAILING = ".,;:!?)]}>\"'`"


def extract_urls(path: str) -> list[str]:
    """Every distinct https://minimal.dev/ URL referenced by the file."""
    try:
        with open(path, encoding="utf-8") as f:
            text = f.read()
    except OSError:
        return []
    urls = set()
    for raw in _URL_RE.findall(text):
        url = raw.rstrip(_TRAILING)
        # Fragments address a section of the same page; the page is the unit
        # that can die or drift, so collapse to it and avoid double-fetching.
        url = url.split("#", 1)[0]
        if url:
            urls.add(url)
    return sorted(urls)


def content_text(body: str) -> str:
    """Visible text of the page's <main> element, whitespace-collapsed.

    Falls back to the whole document if <main> is absent, which is noisier but
    still better than no signal.
    """
    start = body.find("<main")
    end = body.rfind("</main>")
    seg = body[start:end] if (start != -1 and end != -1 and end > start) else body
    seg = re.sub(r"(?is)<(script|style|svg)\b.*?</\1>", " ", seg)
    seg = re.sub(r"(?s)<[^>]+>", " ", seg)
    seg = html.unescape(seg)
    return re.sub(r"\s+", " ", seg).strip()


def fetch(url: str) -> tuple[str, str, str]:
    """(verdict, detail, content_hash). See the module docstring for verdicts."""
    fd, tmp = tempfile.mkstemp(prefix="docs-link-")
    os.close(fd)
    try:
        p = subprocess.run(
            ["curl", "-sS", "-o", tmp, "-w", "%{http_code}\t%{url_effective}",
             "--location", "--proto", "=https", "--tlsv1.2", "--max-time", "25",
             "--user-agent", "gominimal-pkgs-docs-link-check/1.0", url],
            capture_output=True, text=True, timeout=45)
        code, _, final = p.stdout.strip().partition("\t")
        # Auth-gating masquerades as success: /start/ pages answer 200 at
        # /auth/login. Check the landing URL, not just the code.
        if "/auth/" in final:
            return "dead", f"auth-gated (redirects to {final})", ""
        if code in ("404", "410"):
            return "dead", code, ""
        if code.startswith("2"):
            try:
                with open(tmp, encoding="utf-8", errors="replace") as f:
                    body = f.read()
            except OSError:
                return "unknown", "body unreadable", ""
            text = content_text(body)
            if not text:
                return "unknown", f"{code} but no extractable content", ""
            return "ok", code, hashlib.sha256(text.encode("utf-8")).hexdigest()
        # 3xx that never resolved, 403, 429, 5xx, 000 all land here ON PURPOSE.
        return "unknown", code or "no response", ""
    except (subprocess.TimeoutExpired, OSError) as e:
        return "unknown", f"fetch failed ({type(e).__name__})", ""
    finally:
        try:
            os.unlink(tmp)
        except OSError:
            pass


def load_snapshot(path: str) -> dict[str, str]:
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def md_cell(s) -> str:
    return (str(s).replace("\\", "\\\\").replace("|", "\\|")
            .replace("`", "\\`").replace("\r", " ").replace("\n", " "))


def emit(markdown: str) -> None:
    path = os.environ.get("GITHUB_STEP_SUMMARY")
    if path:
        with open(path, "a") as f:
            f.write(markdown)
    else:
        print("\n" + markdown)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", default=DEFAULT_SOURCE,
                    help=f"file to scan for docs URLs (default: {DEFAULT_SOURCE})")
    ap.add_argument("--snapshot", default=DEFAULT_SNAPSHOT,
                    help=f"content-hash snapshot (default: {DEFAULT_SNAPSHOT})")
    ap.add_argument("--update", action="store_true",
                    help="rewrite the snapshot from what is live now, then exit 0")
    ap.add_argument("--report-only", action="store_true",
                    help="never exit non-zero, even for a dead link")
    args = ap.parse_args()

    urls = extract_urls(args.source)
    if not urls:
        # Legitimate while AGENTS.md still inlines everything it will later
        # route to. Say so plainly rather than failing an un-armed canary.
        emit(f"## docs-link-check\n\nNo `https://minimal.dev/` URLs in "
             f"`{md_cell(args.source)}` — nothing to check. The canary arms "
             f"itself as soon as AGENTS.md starts routing to the public docs.\n")
        return 0

    snapshot = load_snapshot(args.snapshot)
    results = []
    for url in urls:
        verdict, detail, digest = fetch(url)
        old = snapshot.get(url)
        if verdict != "ok":
            drift = "—"
        elif old is None:
            drift = "new"
        elif old != digest:
            drift = "changed"
        else:
            drift = "same"
        results.append((verdict, drift, url, detail, digest))

    if args.update:
        fresh = {u: d for v, _, u, _, d in results if v == "ok" and d}
        skipped = [u for v, _, u, _, _ in results if v != "ok"]
        merged = {**snapshot, **fresh}
        # Drop URLs no longer referenced, but never drop one we merely failed
        # to reach this run -- that would silently disarm it.
        keep = set(urls)
        merged = {u: h for u, h in merged.items() if u in keep}
        with open(args.snapshot, "w", encoding="utf-8") as f:
            json.dump(dict(sorted(merged.items())), f, indent=2)
            f.write("\n")
        note = ""
        if skipped:
            note = ("\n> ⚠️ Not refreshed (unreachable this run): "
                    + ", ".join(f"`{md_cell(u)}`" for u in skipped) + "\n")
        emit(f"## docs-link-check (snapshot updated)\n\nWrote **{len(merged)}** "
             f"content hashes to `{md_cell(args.snapshot)}`.\n{note}")
        return 0

    dead = [r for r in results if r[0] == "dead"]
    unknown = [r for r in results if r[0] == "unknown"]
    moved = [r for r in results if r[1] in ("changed", "new")]

    icon = {"dead": "❌", "unknown": "❓", "ok": "✅"}
    out = ["## docs-link-check\n",
           f"\nChecked **{len(urls)}** `minimal.dev` URL(s) referenced by "
           f"`{md_cell(args.source)}`.\n",
           f"\n**{len(dead)} dead · {len(unknown)} unknown · "
           f"{len(moved)} drifted**\n"]

    if dead:
        out.append("\n> ❌ **Dead** means 404/410 or an `/auth/` redirect — the "
                   "page an agent is being sent to cannot be read. This fails "
                   "the check. Repoint the link, or drop it and restore the "
                   "inline guidance. Note that `/start/` pages are auth-gated "
                   "and answer 200 *after* redirecting to login: they are not "
                   "publicly linkable.\n")
    if unknown:
        out.append("\n> ❓ **Unknown** is not a failure and does not fail this "
                   "check. A timeout, 403 or 5xx from a runner means the page "
                   "was not measured, not that it is gone.\n")
    if moved:
        out.append("\n> ⚠️ **Drift** is advisory. The page's text changed, so "
                   "the section of AGENTS.md that routes there is worth a "
                   "re-read — but a link is not wrong just because its target "
                   "was edited. When you have read the change, refresh the "
                   "snapshot:\n>\n> ```\n> python3 "
                   ".github/scripts/docs_link_check.py --update\n> ```\n")

    order = {"dead": 0, "unknown": 1, "ok": 2}
    results.sort(key=lambda r: (order.get(r[0], 9), r[1] != "changed", r[2]))

    out.append("\n| | url | liveness | drift |\n|---|---|---|---|\n")
    for verdict, drift, url, detail, _ in results:
        out.append(f"| {icon.get(verdict, '·')} | {md_cell(url)} | "
                   f"{md_cell(verdict)} ({md_cell(detail)}) | "
                   f"{md_cell(drift)} |\n")

    emit("".join(out))

    if dead and not args.report_only:
        for _, _, url, detail, _ in dead:
            print(f"::error::dead docs link in {args.source}: {url} ({detail})")
        return 1
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:  # noqa: BLE001
        # A crash is a bug in this script, not a verdict about the docs. Say
        # which it is so a red check is never ambiguous.
        print(f"docs_link_check: {type(e).__name__}: {e}", file=sys.stderr)
        sys.exit(2)
