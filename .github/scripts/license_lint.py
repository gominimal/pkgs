#!/usr/bin/env python3
"""Report-only license_spdx lint (gominimal/inbox#281, #53).

For each changed package (or the whole catalog with --all), check that
`license_spdx` is declared and is a valid SPDX license expression. Nothing else
validates this today — the attrs schema only checks String-ness — so a typo'd
id silently poisons the licensing data the attribution work (inbox#282) will
consume.

Validation is offline: license/exception ids come from the vendored
`spdx_license_ids.txt` / `spdx_exception_ids.txt` beside this script
(generated from spdx/license-list-data; regenerate by re-running the commands
in those files' headers). `LicenseRef-<idstring>` is accepted per the SPDX
spec (the catalog uses it for proprietary/no-OSI-id software).

Grammar (SPDX v2 license expressions):
    expr    := term ((AND | OR) term)*
    term    := "(" expr ")" | simple (WITH exception-id)?
    simple  := license-id["+"] | ["DocumentRef-" idstring ":"] "LicenseRef-" idstring

REPORT-ONLY: exits 0 for any policy verdict (missing / invalid); non-zero only
on a programming error, which the workflow downgrades to a warning. MUST NOT
be a branch-protection required check. Values are untrusted build.ncl text and
are Markdown-escaped before reaching the summary.
"""

from __future__ import annotations

import argparse
import os
import re
import sys

# Both declaration shapes in the catalog: `license_spdx = "..."` inside an
# attrs record, and the dotted `attrs.license_spdx = "..."` (cairo, freetype…).
_ATTR_RE = re.compile(r'^\s*(?:attrs\.)?license_spdx\s*=\s*"([^"]*)"', re.M)
_LICENSEREF_RE = re.compile(r"^(DocumentRef-[A-Za-z0-9.-]+:)?LicenseRef-[A-Za-z0-9.-]+$")
_TOKEN_RE = re.compile(r"\(|\)|[^\s()]+")


def load_ids(name: str) -> frozenset[str]:
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), name)
    with open(path, encoding="utf-8") as f:
        return frozenset(ln.strip() for ln in f if ln.strip() and not ln.startswith("#"))


class ExprError(ValueError):
    pass


def validate_expression(expr: str, licenses: frozenset[str], exceptions: frozenset[str]) -> None:
    """Raise ExprError with a human reason if `expr` is not a valid SPDX
    license expression against the vendored id lists."""
    tokens = _TOKEN_RE.findall(expr)
    if not tokens:
        raise ExprError("empty expression")
    pos = 0

    def peek() -> str | None:
        return tokens[pos] if pos < len(tokens) else None

    def take() -> str:
        nonlocal pos
        if pos >= len(tokens):
            raise ExprError("unexpected end of expression")
        t = tokens[pos]
        pos += 1
        return t

    def simple(tok: str) -> None:
        if _LICENSEREF_RE.match(tok):
            return
        base = tok[:-1] if tok.endswith("+") else tok
        if base not in licenses:
            raise ExprError(f"unknown license id `{tok}`")

    def term() -> None:
        tok = take()
        if tok == "(":
            expr_()
            if peek() != ")":
                raise ExprError("unbalanced `(`")
            take()
        elif tok == ")" or tok in ("AND", "OR", "WITH"):
            raise ExprError(f"unexpected `{tok}`")
        else:
            simple(tok)
            if peek() == "WITH":
                take()
                exc = peek()
                if exc is None or exc in ("(", ")", "AND", "OR", "WITH"):
                    raise ExprError("WITH must be followed by an exception id")
                take()
                if exc not in exceptions:
                    raise ExprError(f"unknown exception id `{exc}`")

    def expr_() -> None:
        term()
        while peek() in ("AND", "OR"):
            take()
            term()

    expr_()
    if pos != len(tokens):
        raise ExprError(f"trailing tokens from `{tokens[pos]}`")


def declared_license(name: str) -> str | None:
    try:
        with open(os.path.join("packages", name, "build.ncl"), encoding="utf-8") as f:
            m = _ATTR_RE.search(f.read())
            return m.group(1) if m else None
    except OSError:
        return None


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
    grp = ap.add_mutually_exclusive_group(required=True)
    grp.add_argument("--all", action="store_true")
    grp.add_argument("--packages-file")
    args = ap.parse_args()

    licenses = load_ids("spdx_license_ids.txt")
    exceptions = load_ids("spdx_exception_ids.txt")

    if args.all:
        try:
            names = sorted(d for d in os.listdir("packages")
                           if os.path.isfile(os.path.join("packages", d, "build.ncl")))
        except OSError:
            names = []
    else:
        try:
            with open(args.packages_file) as f:
                names = [ln.strip() for ln in f if ln.strip()]
        except OSError as e:
            emit("## license lint (informational, non-blocking)\n\n"
                 f"> Could not read packages file ({type(e).__name__}); skipping.\n")
            return 0

    rows, ok, missing, invalid = [], 0, 0, 0
    for name in names:
        val = declared_license(name)
        if val is None:
            missing += 1
            rows.append((name, "—", "❓ missing license_spdx"))
            print(f"{name}: MISSING")
            continue
        try:
            validate_expression(val, licenses, exceptions)
            ok += 1
            if not args.all:  # keep PR summaries focused; --all lists all
                rows.append((name, val, "✅ valid"))
            print(f"{name}: ok ({val})")
        except ExprError as e:
            invalid += 1
            rows.append((name, val, f"❌ {e}"))
            print(f"{name}: INVALID ({val}): {e}")

    out = [
        "## license lint (informational, non-blocking)", "",
        "Every package should declare `license_spdx` as a valid [SPDX license "
        "expression](https://spdx.org/licenses) (gominimal/inbox#281 / #53). "
        "Validated offline against the vendored SPDX id lists.", "",
        f"**{ok} valid · {missing} missing · {invalid} invalid**", "",
    ]
    shown = [r for r in rows if args.all and not r[2].startswith("✅") or not args.all]
    if shown:
        out += ["| package | license_spdx | verdict |", "| --- | --- | --- |"]
        out += ["| " + " | ".join(md_cell(c) for c in r) + " |" for r in shown]
    else:
        out.append("✅ Nothing to flag.")
    out += ["",
            "> Report-only; never blocks and is intentionally excluded from "
            "branch-protection required checks. Internal aggregate packages "
            "(base, toolchain, …) intentionally omit license_spdx pending the "
            "aggregate-licensing decision in inbox#281."]
    emit("\n".join(out) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
