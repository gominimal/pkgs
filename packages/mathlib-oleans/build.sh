#!/bin/sh
# mathlib-oleans: compile ALL of Mathlib from source, offline, for the lean we
# ship, and install the licences and notices for that code. LEAN_PATH and
# MANIFEST are the thin `mathlib` package's (see build.ncl), so editing them
# does not rebuild this.
#
# Offline-lake mechanism adapted from nixpkgs `pkgs/build-support/lake`
# (MIT License, Copyright (c) 2003-2026 Eelco Dolstra and the Nixpkgs/NixOS
# contributors): dependencies live in `.lake/packages/<name>` as pinned
# sources, `.lake/package-overrides.json` points lake at them, and the cloud
# cache / Reservoir lookups are disabled. Nothing is fetched: no `lake exe
# cache get`.
set -eu
export HOME="$(pwd)/home"; mkdir -p "$HOME"
export LAKE_NO_CACHE=1
export RESERVOIR_API_URL=""
export MATHLIB_NO_CACHE_ON_UPDATE=1

ROOT="$(pwd)"
cd leanprover-community-mathlib4-56a0058

# 1. A Mathlib tag supports exactly one Lean. Refuse to compile it against
#    another rather than produce oleans that fail at import time.
want="leanprover/lean4:v$(lean --version | sed -n 's/^Lean (version \([0-9.]*\).*/\1/p')"
have="$(cat lean-toolchain)"
if [ "$have" != "$want" ]; then
  echo "ERROR: mathlib lean-toolchain is '$have' but the lean we ship is '$want'." >&2
  echo "       Bump lean, mathlib-oleans, mathlib and aeneas-latest together (see build.ncl)." >&2
  exit 1
fi

# 2. Vendored dependencies into place (Lake package name -> extracted top-dir).
#    Names are the `name` fields of Mathlib's lake-manifest.json.
mkdir -p .lake/packages
mv "$ROOT/leanprover-community-plausible-dfa4f38" ".lake/packages/plausible"
mv "$ROOT/leanprover-community-LeanSearchClient-d6b4c7b" ".lake/packages/LeanSearchClient"
mv "$ROOT/leanprover-community-import-graph-a41f0e9" ".lake/packages/importGraph"
mv "$ROOT/leanprover-community-ProofWidgets4-df72b02" ".lake/packages/proofwidgets"
mv "$ROOT/leanprover-community-aesop-4a174c4" ".lake/packages/aesop"
mv "$ROOT/leanprover-community-quote4-dce0ad7" ".lake/packages/Qq"
mv "$ROOT/leanprover-community-batteries-66e4691" ".lake/packages/batteries"
mv "$ROOT/leanprover-lean4-cli-c24fe60" ".lake/packages/Cli"

# 3. The on-disk overrides file: lake resolves every `require` to these dirs.
{
  printf '{"schemaVersion":"1.2.0","packages":['
  first=1
  for d in .lake/packages/*/; do
    n="$(basename "$d")"
    [ "$first" = 1 ] || printf ','
    first=0
    printf '{"type":"path","name":"%s","inherited":false,"dir":".lake/packages/%s"}' "$n" "$n"
  done
  printf ']}'
} > .lake/package-overrides.json

# 4. Licences and third-party notices for the code compiled below. The
#    ProofWidgets oleans embed its widget JS (npm code and two WebAssembly
#    modules, one EPL-2.0/CPL-1.0), so this package carries the same texts and
#    source offer as `mathlib`, installed by the same script from the same
#    files (packages/mathlib/notices.ncl). It checks each notice against the
#    pinned bundles and fails closed. It needs only the unpacked sources, so
#    it runs before the compile: a stale notice fails in seconds, not after
#    ~35 min of `lake build`.
P=.lake/packages
sh "$ROOT/install-licences.sh" "$ROOT" "$OUTPUT_DIR/usr/share/licenses/mathlib-oleans" \
  mathlib=. plausible=$P/plausible LeanSearchClient=$P/LeanSearchClient \
  importGraph=$P/importGraph proofwidgets=$P/proofwidgets aesop=$P/aesop \
  Qq=$P/Qq batteries=$P/batteries Cli=$P/Cli

# 5. Build the `Mathlib` library (the default target; not Archive,
#    Counterexamples, MathlibTest or the scripts' executables).
#
#    Parallelism: Lake 4.35 has no jobs flag. Its build jobs are Lean tasks
#    on the lake process's thread pool, so LEAN_NUM_THREADS bounds how many
#    `lean` children run at once (and each child inherits it as its own
#    thread cap). The `lean_num_threads` build arg is the target, set per
#    arch in build.ncl (32 amd64, 16 arm64) for the build-bot machines. This
#    box may be smaller (a local `min package build` on a laptop), so the
#    count actually used is
#      min(lean_num_threads, CPUs, free memory / 1.5 GiB), at least 1,
#    where free memory is /proc/meminfo's MemAvailable, or the cgroup's
#    memory.max headroom if that is smaller.
#    1.5 GiB per job: a 6-job run peaked at ~7.0 GiB (~1.2 GiB per job), and
#    one `lean` can reach 2.8 GiB. The count changes the wall time, not the
#    bytes: output trees were identical at 4, 6 and 8 jobs and at the
#    build-bot's 32/16 (pkgs#1244), so the spec hash does not see this cap.
case "${MINIMAL_ARG_LEAN_NUM_THREADS:-}" in
  ''|*[!0-9]*|0*) echo "mathlib-oleans: lean_num_threads must be a positive integer, got '${MINIMAL_ARG_LEAN_NUM_THREADS:-}'." >&2; exit 1 ;;
esac
jobs="$MINIMAL_ARG_LEAN_NUM_THREADS"
cpus="$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 0)"
mem_kib="$(sed -n 's/^MemAvailable: *\([0-9]*\) kB$/\1/p' /proc/meminfo 2>/dev/null || true)"
case "$cpus" in ''|*[!0-9]*) cpus=0 ;; esac
case "$mem_kib" in ''|*[!0-9]*) mem_kib=0 ;; esac
cg_max="$(cat /sys/fs/cgroup/memory.max 2>/dev/null || true)"
cg_cur="$(cat /sys/fs/cgroup/memory.current 2>/dev/null || true)"
case "$cg_max" in ''|*[!0-9]*) cg_max= ;; esac # "max" = no limit
case "$cg_cur" in ''|*[!0-9]*) cg_cur=0 ;; esac
if [ -n "$cg_max" ]; then
  cg_kib=$(((cg_max - cg_cur) / 1024))
  if [ "$cg_kib" -lt 1 ]; then cg_kib=1; fi
  if [ "$mem_kib" -eq 0 ] || [ "$cg_kib" -lt "$mem_kib" ]; then mem_kib="$cg_kib"; fi
fi
if [ "$cpus" -gt 0 ] && [ "$cpus" -lt "$jobs" ]; then jobs="$cpus"; fi
if [ "$mem_kib" -gt 0 ]; then
  by_mem=$((mem_kib / 1572864))
  if [ "$by_mem" -lt "$jobs" ]; then jobs="$by_mem"; fi
fi
if [ "$jobs" -lt 1 ]; then jobs=1; fi
echo "mathlib-oleans: $jobs lean jobs (target $MINIMAL_ARG_LEAN_NUM_THREADS, $cpus CPUs, $((mem_kib / 1048576)) GiB available)"
export LEAN_NUM_THREADS="$jobs"
lake build Mathlib

# 6. Fail closed on an incomplete build: every Mathlib module must have its
#    .olean, the two sidecars lean refuses to load without, and its .ir
#    (without which lean cannot run an imported module's `initialize`).
LIB=.lake/build/lib/lean
missing=0
for f in Mathlib.lean $(find Mathlib -name '*.lean'); do
  m="${f%.lean}"
  for ext in olean olean.server olean.private ir; do
    if [ ! -f "$LIB/$m.$ext" ]; then
      echo "mathlib-oleans: missing $LIB/$m.$ext" >&2
      missing=$((missing + 1))
    fi
  done
done
if [ "$missing" -ne 0 ]; then
  echo "mathlib-oleans: $missing module files missing after lake build; refusing to package." >&2
  exit 1
fi

# 7. Install: one directory per Lake package, under usr/lib/lean/mathlib.
#    Not usr/lib/lean/pkgs, which is aeneas-latest's root: a closure resolves
#    a path conflict per file, so two packages that ever install the same
#    module under one root could pair one build's .olean with the other's
#    .olean.server/.olean.private/.ir. Its own root keeps this tree whole.
OUT="$OUTPUT_DIR/usr/lib/lean/mathlib"
install_pkg() { # name srcdir
  mkdir -p "$OUT/$1/lib"
  cp -a "$2/.lake/build/lib/lean/." "$OUT/$1/lib/"
}
install_pkg mathlib .
for d in .lake/packages/*/; do
  n="$(basename "$d")"
  if [ -d "$d/.lake/build/lib/lean" ]; then install_pkg "$n" "$d"; fi
done
# Lake's per-module build records are build-tree state, not library content.
find "$OUT" \( -name '*.trace' -o -name '*.hash' -o -name '*.log.json' \) -type f -delete

# 8. What this was compiled from, for `mathlib` to check its own sources
#    against (it ships the notices for these exact widget bundles and the
#    lake-manifest.json consumers compare their pins with).
INFO="$OUTPUT_DIR/usr/share/mathlib-oleans"
mkdir -p "$INFO"
printf 'mathlib-oleans %s\n' "$MINIMAL_ARG_VERSION" > "$INFO/VERSION"
cp lean-toolchain lake-manifest.json "$INFO/"
( cd .lake/packages/proofwidgets/widget &&
  LC_ALL=C sha256sum package-lock.json $(LC_ALL=C ls js/*.js) ) > "$INFO/proofwidgets-widget.sha256"
