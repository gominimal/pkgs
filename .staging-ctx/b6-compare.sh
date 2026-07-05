#!/usr/bin/env bash
# ============================================================================================
# b6-compare.sh — B6 differential proof: Gate-0 provenance check + normalized byte compare.
# Companion to .staging-ctx/b6-differential-plan-2026-07-03.md §5 and
# packages/coreutils-bedrock-diff/ (the twin recipe).  Runs on the operator machine.
#
# Usage:
#   .staging-ctx/b6-compare.sh                          # coreutils vs coreutils-bedrock-diff, latest
#   .staging-ctx/b6-compare.sh -a coreutils-9.10 -b coreutils-bedrock-diff-9.10
#   .staging-ctx/b6-compare.sh --workdir /path/keep     # keep fetched/extracted trees
#   B6_TOOLCHAIN_PKGS="gcc-15.2.0-glibc ..."            # pin tier-1 reference seals (default: the 3 B5/B4 pkgs, latest)
#   FORCE_GATE0_BREADCRUMB=1 ...                        # accept breadcrumb-only Gate-0 (see below)
#
# Exit codes:
#   0 = PASS-STRICT   Gate-0 passed AND artifacts byte-identical after tar-metadata
#                     neutralization (per-file compare), modulo the excluded breadcrumb.
#   2 = TRIAGE        Gate-0 passed; diffs exist but every one normalizes away or is in the
#                     expected-codegen bucket; NO nondeterminism found.  -> diffoscope per plan.
#   3 = NONDET-FAIL   a nondeterminism class fired (build-id present, path leak, interp drift).
#   1 = GATE/INFRA    Gate-0 failed (twinning collision / CAVEAT A) or fetch/parse error.
#
# ── GATE 0 (do FIRST — defeats the silent-empty-diff hazard, plan CAVEAT A) ─────────────────
# The twin MUST have consumed the sealed B5/B4 toolchain bytes, else twinning/cache substitution
# silently filled the slots and an "empty diff" is meaningless.  Two evidence tiers:
#   tier 1 (consumed-bytes): the twin's in-toto resolvedDependencies DIGESTS contain the sealed
#           B5/B4 toolchain ARTIFACT shas (read from those pkgs' release envelopes, fetched
#           below), and none of those shas appear in production's resolvedDependencies.
#           NB (verified against hermetic-builder-rs 2026-07-04): resolvedDependencies URIs are
#           CAS-shaped (gs://<mirror>/sha256/<sha>) so this is digest MEMBERSHIP, never uri-name
#           matching; and declaredSources CANNOT serve as evidence — collect_declared_sources()
#           records what the recipes DECLARE (graph-shaped, invariant under slot substitution),
#           and both closures declare the very same gcc-15.2.0/binutils-2.46.0/glibc-2.42 source
#           tarballs (production from-source targets == B5/B4 targets), so name-matching there
#           can neither prove nor refute twinning.  Tier 1 requires the twin to have been sealed
#           with --chain-enforce (else resolvedDependencies are EMPTY — queue-mode default, see
#           MEMORY feedback_verify_deps_permissive_with_empty_resolved).  If the twin predates
#           the latest toolchain seals, pin B6_TOOLCHAIN_PKGS="<pkg>-<ver> ..." explicitly.
#   tier 2 (fallback — resolvedDependencies empty): the twin artifact's
#           usr/share/coreutils-bedrock-diff/B6-TOOLCHAIN.txt breadcrumb (written only after
#           the in-build B6-TWIN-GATE proved the B5 gcc/as markers) says toolchain=B5-from-source,
#           and the production artifact contains no such file.  Tier 2 alone requires
#           FORCE_GATE0_BREADCRUMB=1 (explicit, so nobody claims tier-1 rigor by accident).
#
# ── EXPECTED BENIGN DIFFS and their neutralization ──────────────────────────────────────────
#   1. tar member mtime/uid/gid/order      -> compare EXTRACTED per-file contents, never raw tars.
#   2. usr/share/coreutils-bedrock-diff/** -> twin-only Gate-0 breadcrumb; EXCLUDED by path.
#   3. .comment section (compiler id string, e.g. "GCC: (GNU) 15.2.0" vs prebuilt-Debian id)
#                                          -> masked by the ELF normalizer before re-hash.
#   4. .note.gnu.build-id                  -> must be ABSENT on both sides (--build-id=none);
#                                             if PRESENT anywhere -> NONDET-FAIL (knob regression),
#                                             not a neutralization.
#   5. PT_INTERP                           -> engineered EQUAL (/lib64/ld-linux-x86-64.so.2) by the
#                                             twin's prod-mode link; normalizer masks .interp but
#                                             REPORTS any drift as NONDET-FAIL.
#   6. Compiler-version codegen deltas     -> NOT neutralizable (plan §0: B6-triage bucket).
#                                             Files whose diff survives normalization land here;
#                                             triage each with diffoscope (in-tree pkg, v306).
#   7. Regenerated man pages (help2man embeds a date) -> should NOT occur (both builds use the
#                                             dist-shipped pages); a *.1 diff is reported in the
#                                             triage bucket with an explicit man-page warning.
#   8. Embedded header paths ($SR/include vs /usr/include in e.g. assert strings) -> same glibc-2.42
#                                             header CONTENT both sides so unlikely; a hit shows up
#                                             as the "glibc-bedrock" path-leak scan -> NONDET-FAIL.
# ============================================================================================
set -euo pipefail

BUCKET="${RELEASE_BUCKET:-minimalmertic-release-channel-stable}"
PROJECT="${GCP_PROJECT:-minimalmertic}"
PKG_A="coreutils"                  # production
PKG_B="coreutils-bedrock-diff"     # B5 twin
WORKDIR=""
while [ $# -gt 0 ]; do
  case "$1" in
    -a) PKG_A="$2"; shift 2 ;;
    -b) PKG_B="$2"; shift 2 ;;
    --workdir) WORKDIR="$2"; shift 2 ;;
    --bucket) BUCKET="$2"; shift 2 ;;
    --project) PROJECT="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done
[ -n "$WORKDIR" ] || WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/b6-compare.XXXXXX")"
mkdir -p "$WORKDIR"
echo "workdir: $WORKDIR"

BREADCRUMB_REL="usr/share/coreutils-bedrock-diff"

# ── resolve <pkg> -> latest <pkg>-<version> release dir (same convention as `orch verify`) ──
resolve_dir() {
  local pkg="$1"
  if [[ "$pkg" =~ -[0-9][0-9.]*$ ]]; then echo "$pkg"; return; fi
  # exact-name match: version suffix must be purely numeric-dotted so `coreutils` never
  # accidentally resolves a `coreutils-bedrock-diff-9.10` listing (and vice versa).
  gcloud storage ls "gs://${BUCKET}/" --project "$PROJECT" \
    | sed -e 's@/$@@' -e "s@^gs://${BUCKET}/@@" \
    | grep -E "^${pkg}-[0-9][0-9.]*$" | sort -V | tail -n1 \
    | { read -r d && echo "$d" || { echo "ERROR: no release dir gs://${BUCKET}/${pkg}-<ver>/" >&2; exit 1; }; }
}

DIR_A="$(resolve_dir "$PKG_A")"
DIR_B="$(resolve_dir "$PKG_B")"
echo "production : gs://${BUCKET}/${DIR_A}/"
echo "twin       : gs://${BUCKET}/${DIR_B}/"

fetch() { # fetch <dir> <slot>  -> $WORKDIR/<slot>.tar.zst + <slot>.intoto.jsonl
  local dir="$1" slot="$2"
  gcloud storage cp "gs://${BUCKET}/${dir}/${dir}.tar.zst" "$WORKDIR/${slot}.tar.zst" --project "$PROJECT"
  gcloud storage cp "gs://${BUCKET}/${dir}/${dir}.tar.zst.intoto.jsonl" "$WORKDIR/${slot}.intoto.jsonl" --project "$PROJECT"
}
fetch "$DIR_A" A
fetch "$DIR_B" B

# ── Gate-0 tier-1 reference shas: the sealed toolchain artifacts' release envelopes.
# Override B6_TOOLCHAIN_PKGS (space-separated, version-pinned allowed) if the twin was sealed
# against non-latest toolchain seals.  A fetch failure only degrades tier 1 (fail-shut: Gate-0
# then needs the explicit breadcrumb tier), it never fakes a pass.
# glibc-bedrock-2.42 MUST be version-pinned: its NAME ends in a version-shaped suffix (-2.42), so
# resolve_dir's already-pinned heuristic fires and skips appending the real version (bit 2026-07-04).
TOOLCHAIN_PKGS="${B6_TOOLCHAIN_PKGS:-gcc-15.2.0-glibc binutils-2.46-glibc glibc-bedrock-2.42-2.42}"
for tp in $TOOLCHAIN_PKGS; do
  if td="$(resolve_dir "$tp")"; then
    gcloud storage cp "gs://${BUCKET}/${td}/${td}.tar.zst.intoto.jsonl" \
      "$WORKDIR/tool-${tp}.intoto.jsonl" --project "$PROJECT" \
      || echo "WARN: no release envelope for toolchain pkg ${tp} (tier-1 degraded)" >&2
  else
    echo "WARN: no release dir for toolchain pkg ${tp} (tier-1 degraded)" >&2
  fi
done

SHA_A="$(shasum -a 256 "$WORKDIR/A.tar.zst" | cut -d' ' -f1)"
SHA_B="$(shasum -a 256 "$WORKDIR/B.tar.zst" | cut -d' ' -f1)"
echo "shaA(prod) = $SHA_A"
echo "shaB(twin) = $SHA_B"

# ── extract both (zstd tars; member metadata differences are neutralized by extraction) ──
extract() {
  local slot="$1"; mkdir -p "$WORKDIR/$slot"
  if tar --help 2>/dev/null | grep -q zstd; then
    tar --zstd -xf "$WORKDIR/${slot}.tar.zst" -C "$WORKDIR/$slot"
  else
    zstd -dc "$WORKDIR/${slot}.tar.zst" | tar -xf - -C "$WORKDIR/$slot"
  fi
}
extract A
extract B

# ============================================================================================
# GATE 0
# ============================================================================================
export B6_WORKDIR="$WORKDIR" B6_BREADCRUMB_REL="$BREADCRUMB_REL" B6_TOOLCHAIN_PKGS_EFF="$TOOLCHAIN_PKGS"
gate0_rc=0
python3 - <<'PYGATE0' || gate0_rc=$?
import base64, json, os, re, sys
wd = os.environ["B6_WORKDIR"]; bc_rel = os.environ["B6_BREADCRUMB_REL"]
want_tools = os.environ.get("B6_TOOLCHAIN_PKGS_EFF", "").split()

def stmt_of(path):
    env = json.load(open(path))
    return json.loads(base64.b64decode(env["payload"]))

def load(slot):
    stmt = stmt_of(f"{wd}/{slot}.intoto.jsonl")
    bd = stmt["predicate"]["buildDefinition"]
    rd = {(d.get("digest") or {}).get("sha256", "")
          for d in bd.get("resolvedDependencies") or []}
    rd.discard("")
    ds = [(d.get("uri") or "", (d.get("digest") or {}).get("sha256", ""))
          for d in bd.get("declaredSources") or []]
    return stmt, rd, ds

stmt_a, rd_a, ds_a = load("A")
stmt_b, rd_b, ds_b = load("B")
print(f"\n── Gate-0: attestation dependency slots ──")
print(f"A(prod) subject: {stmt_a['subject'][0]['name']} sha256={stmt_a['subject'][0]['digest']['sha256']}")
print(f"B(twin) subject: {stmt_b['subject'][0]['name']} sha256={stmt_b['subject'][0]['digest']['sha256']}")
print(f"A(prod) resolvedDependencies: {len(rd_a)} digest(s); declaredSources: {len(ds_a)}")
print(f"B(twin) resolvedDependencies: {len(rd_b)} digest(s); declaredSources: {len(ds_b)}")

# INFORMATIONAL ONLY — declaredSources are what the recipes DECLARE (graph-shaped): they are
# invariant under twinning/cache substitution AND both closures declare the same toolchain
# source tarballs, so this listing is context for the operator, NEVER pass/fail evidence.
TOOL_RE = re.compile(r"/(gcc|binutils|glibc|linux[-_]headers|musl|tcc|mes)[^/]*\.tar", re.I)
for label, ds in (("A(prod)", ds_a), ("B(twin)", ds_b)):
    hits = sorted({(u, s) for (u, s) in ds if TOOL_RE.search(u)})
    print(f"{label} declared toolchain-ish sources (informational, graph-declared): {len(hits)}")
    for uri, sha in hits:
        print(f"    {sha[:16]}  {uri}")

# ── tier 1 (consumed-bytes): sealed toolchain artifact shas ∈ twin's resolvedDependencies ──
tool_env = {}
for name in want_tools:
    p = f"{wd}/tool-{name}.intoto.jsonl"
    if os.path.exists(p):
        s = stmt_of(p)
        tool_env[name] = s["subject"][0]["digest"]["sha256"]
missing_env = [n for n in want_tools if n not in tool_env]
for n in sorted(tool_env):
    print(f"toolchain seal {n}: artifact sha256={tool_env[n]}")

if rd_b and tool_env and not missing_env:
    absent = {n: s for n, s in tool_env.items() if s not in rd_b}
    if absent:
        print("GATE-0 FAIL: the twin's consumed closure (resolvedDependencies) does NOT contain "
              "the sealed toolchain artifact(s) — twinning/substitution, or the twin predates the "
              "latest seals (pin B6_TOOLCHAIN_PKGS to the versions the twin built against):",
              file=sys.stderr)
        for n, s in sorted(absent.items()):
            print(f"    {n} = {s}", file=sys.stderr)
        sys.exit(10)
    overlap = {n: s for n, s in tool_env.items() if s in rd_a}
    if overlap:
        print("GATE-0 FAIL: PRODUCTION's consumed closure also contains the B5/B4 toolchain "
              f"artifact(s) {sorted(overlap)} — both sides consumed the same toolchain bytes; "
              "the diff is not a differential (plan §5).", file=sys.stderr)
        sys.exit(10)
    # breadcrumb cross-check (nearly free; the twin build writes it unconditionally after the
    # in-build B6-TWIN-GATE) — a missing/contradicting breadcrumb under tier 1 = artifact mixup.
    bc = f"{wd}/B/{bc_rel}/B6-TOOLCHAIN.txt"
    if not os.path.exists(bc) or "toolchain=B5-from-source" not in open(bc).read():
        print("GATE-0 FAIL: tier-1 digests check out but the twin breadcrumb is missing/wrong — "
              "artifact mixup between slots?", file=sys.stderr)
        sys.exit(10)
    if os.path.exists(f"{wd}/A/{bc_rel}/B6-TOOLCHAIN.txt"):
        print("GATE-0 FAIL: PRODUCTION artifact contains the twin breadcrumb — artifact mixup.",
              file=sys.stderr)
        sys.exit(10)
    print("GATE-0 PASS (tier 1): all sealed toolchain artifact shas are in the twin's "
          "resolvedDependencies and none in production's; breadcrumb consistent.")
    sys.exit(0)

if not rd_b:
    print("note: twin resolvedDependencies EMPTY (not sealed with --chain-enforce, or emit degraded) "
          "— tier 1 unavailable, falling to tier 2.")
elif missing_env:
    print(f"note: reference envelope(s) missing for {missing_env} — tier 1 unavailable, falling to tier 2.")

# tier 2: breadcrumb fallback (resolvedDependencies empty — queue-mode default)
bc = f"{wd}/B/{bc_rel}/B6-TOOLCHAIN.txt"
prod_bc = f"{wd}/A/{bc_rel}/B6-TOOLCHAIN.txt"
if not os.path.exists(bc):
    print("GATE-0 FAIL: no tier-1 evidence AND no B6-TOOLCHAIN.txt breadcrumb in the twin artifact.", file=sys.stderr)
    sys.exit(10)
txt = open(bc).read()
print(f"\n── twin breadcrumb ({bc_rel}/B6-TOOLCHAIN.txt) ──\n{txt}")
if "toolchain=B5-from-source" not in txt:
    print("GATE-0 FAIL: breadcrumb present but does not attest toolchain=B5-from-source.", file=sys.stderr)
    sys.exit(10)
if os.path.exists(prod_bc):
    print("GATE-0 FAIL: PRODUCTION artifact also contains the twin breadcrumb — artifact mixup.", file=sys.stderr)
    sys.exit(10)
if os.environ.get("FORCE_GATE0_BREADCRUMB") == "1":
    print("GATE-0 PASS (tier 2, FORCED): breadcrumb-only evidence (attestation resolvedDependencies empty). "
          "This relies on the in-build B6-TWIN-GATE; do NOT record the North-Star row as tier-1 verified.")
    sys.exit(0)
print("GATE-0 HOLD: only breadcrumb (tier 2) evidence available — twin resolvedDependencies were empty "
      "or reference seals unavailable. Re-seal the twin with --chain-enforce for tier 1, or re-run with "
      "FORCE_GATE0_BREADCRUMB=1 to accept tier 2 explicitly.", file=sys.stderr)
sys.exit(10)
PYGATE0
if [ "$gate0_rc" -ne 0 ]; then
  echo "Gate-0 FAILED (rc=$gate0_rc) — comparison is void, see plan CAVEAT A." >&2
  exit 1
fi
echo "Gate-0: OK"

# ============================================================================================
# BYTE COMPARE — per-file over the extracted trees, breadcrumb excluded.
# ============================================================================================
list_hashes() { # list_hashes <slot>
  (cd "$WORKDIR/$1" && find . -type f ! -path "./${BREADCRUMB_REL}/*" -print0 \
    | xargs -0 shasum -a 256 | awk '{print $2 "  " $1}' | sort)
}
list_hashes A > "$WORKDIR/hashes.A"
list_hashes B > "$WORKDIR/hashes.B"

if cmp -s "$WORKDIR/hashes.A" "$WORKDIR/hashes.B"; then
  echo ""
  echo "════════════════════════════════════════════════════════════════════"
  echo "B6 VERDICT: PASS-STRICT — every file byte-identical (breadcrumb excluded)."
  echo "  shaA=$SHA_A"
  echo "  shaB=$SHA_B"
  echo "  Record in the North-Star B6 row WITH the Gate-0 tier used above."
  echo "════════════════════════════════════════════════════════════════════"
  exit 0
fi

# file-set differences
comm -23 <(cut -d' ' -f1 "$WORKDIR/hashes.A") <(cut -d' ' -f1 "$WORKDIR/hashes.B") > "$WORKDIR/only.A" || true
comm -13 <(cut -d' ' -f1 "$WORKDIR/hashes.A") <(cut -d' ' -f1 "$WORKDIR/hashes.B") > "$WORKDIR/only.B" || true
join <(sort "$WORKDIR/hashes.A") <(sort "$WORKDIR/hashes.B") -j1 -o 1.1,1.2,2.2 2>/dev/null \
  | awk '$2 != $3 {print $1}' > "$WORKDIR/differing" || true

echo ""
echo "── file-set delta ──"
FILESET_DELTA=0
[ -s "$WORKDIR/only.A" ] && { FILESET_DELTA=1; echo "only in A(prod):"; sed 's/^/    /' "$WORKDIR/only.A"; }
[ -s "$WORKDIR/only.B" ] && { FILESET_DELTA=1; echo "only in B(twin):"; sed 's/^/    /' "$WORKDIR/only.B"; }
echo "content-differing files: $(wc -l < "$WORKDIR/differing" | tr -d ' ')"

# ── normalize + classify each differing file (python mini-ELF; no readelf needed on macOS) ──
export B6_DIFFLIST="$WORKDIR/differing"
rc=0
python3 - <<'PYNORM' || rc=$?
import hashlib, os, struct, sys
wd = os.environ["B6_WORKDIR"]

# sections masked before re-hash (expected-benign carriers); .interp/.note build-id drift is
# additionally REPORTED as nondeterminism, never silently eaten.
MASK = {".comment", ".note.gnu.build-id", ".interp"}
# path-leak scan on twin bytes.  NB the LEGITIMATE -ffile-prefix-map target "/builddir" does
# NOT match b"/build/" (no slash after "build"), so the bare sandbox-CWD prefix is safe to scan
# for and catches ANY un-mapped /build/<anything> leak (fixlib dir, source dir, gate dir).
LEAK = [b"glibc-bedrock-2.42", b"/build/"]

def elf_sections(buf):
    if buf[:4] != b"\x7fELF": return None
    is64 = buf[4] == 2
    if not is64: return None
    e_shoff, = struct.unpack_from("<Q", buf, 0x28)
    e_shentsize, = struct.unpack_from("<H", buf, 0x3a)
    e_shnum, = struct.unpack_from("<H", buf, 0x3c)
    e_shstrndx, = struct.unpack_from("<H", buf, 0x3e)
    secs = []
    for i in range(e_shnum):
        off = e_shoff + i * e_shentsize
        name_off, sh_type = struct.unpack_from("<II", buf, off)
        sh_offset, = struct.unpack_from("<Q", buf, off + 0x18)
        sh_size, = struct.unpack_from("<Q", buf, off + 0x20)
        secs.append((name_off, sh_type, sh_offset, sh_size))
    if e_shstrndx >= len(secs): return None
    _, _, stroff, strsz = secs[e_shstrndx]
    strtab = buf[stroff:stroff + strsz]
    out = []
    for name_off, sh_type, off, size in secs:
        end = strtab.find(b"\x00", name_off)
        name = strtab[name_off:end].decode("latin1")
        out.append((name, sh_type, off, size))
    return out

def normalized_sha(path):
    buf = bytearray(open(path, "rb").read())
    secs = elf_sections(bytes(buf))
    info = {"elf": secs is not None, "masked": [], "build_id": False, "interp": None}
    if secs:
        for name, sh_type, off, size in secs:
            if name == ".interp":
                info["interp"] = bytes(buf[off:off + size]).rstrip(b"\x00").decode("latin1", "replace")
            if name == ".note.gnu.build-id":
                info["build_id"] = True
            if name in MASK and sh_type != 8 and size and off + size <= len(buf):  # 8=SHT_NOBITS
                buf[off:off + size] = b"\x00" * size
                info["masked"].append(name)
    return hashlib.sha256(bytes(buf)).hexdigest(), info

difflist = [l.strip() for l in open(os.environ["B6_DIFFLIST"]) if l.strip()]
benign, triage, nondet = [], [], []
for rel in difflist:
    pa, pb = f"{wd}/A/{rel}", f"{wd}/B/{rel}"
    ha, ia = normalized_sha(pa)
    hb, ib = normalized_sha(pb)
    problems = []
    if ia["build_id"] or ib["build_id"]:
        problems.append(f"build-id PRESENT (A={ia['build_id']} B={ib['build_id']}) — --build-id=none regressed")
    if ia["interp"] != ib["interp"]:
        problems.append(f"PT_INTERP drift: A={ia['interp']} B={ib['interp']}")
    twin = open(pb, "rb").read()
    leaks = [l.decode() for l in LEAK if l in twin]
    if leaks:
        problems.append(f"path leak in twin bytes: {leaks}")
    if problems:
        nondet.append((rel, problems))
    elif ha == hb:
        benign.append((rel, ia["masked"] or ib["masked"]))
    else:
        note = " [man page — check for a regenerated help2man date]" if rel.endswith(".1") or "/man/" in rel else ""
        triage.append((rel, note))

print("\n── classification ──")
for rel, masked in benign:
    print(f"  BENIGN  {rel}  (identical after masking {masked})")
for rel, note in triage:
    print(f"  TRIAGE  {rel}  (survives normalization — expected-codegen bucket; run diffoscope){note}")
for rel, probs in nondet:
    print(f"  NONDET  {rel}")
    for p in probs: print(f"          - {p}")

print(f"\ncounts: benign={len(benign)} triage={len(triage)} nondet={len(nondet)}")
if nondet:
    print("\nB6 VERDICT: NONDET-FAIL — nondeterminism classes fired; fix the knob/harness and rebuild (plan §5).", file=sys.stderr)
    sys.exit(3)
if triage:
    print("\nB6 VERDICT: TRIAGE — no nondeterminism; residual deltas are in the expected-codegen bucket.")
    print("Next: diffoscope each TRIAGE file (in-tree pkg, v306), confirm delta ⊆ expected compiler-version")
    print("codegen, then record the row as 'triage: only-expected-codegen, zero nondeterminism' — NOT 'empty diff'.")
    print(f"  e.g.: diffoscope {wd}/A/usr/bin/ls {wd}/B/usr/bin/ls")
    sys.exit(2)
print("\nB6 VERDICT: PASS (all diffs were benign section-note deltas that normalize away).")
sys.exit(0)
PYNORM
# A file-set delta (file present on only one side, breadcrumb already excluded) is never PASS:
# the matching-output-globs precondition of the per-file compare failed. Upgrade 0 -> TRIAGE.
if [ "$FILESET_DELTA" -eq 1 ] && [ "$rc" -eq 0 ]; then
  echo "" >&2
  echo "B6 VERDICT downgraded to TRIAGE: file SETS differ between prod and twin (see 'file-set delta' above) — a per-file byte compare over mismatched sets cannot be recorded as PASS." >&2
  rc=2
fi
exit $rc
