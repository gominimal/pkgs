#!/bin/sh
# stage0-coreutils — build coreutils with tcc-musl, never with gcc.
#
# READ build.ncl FIRST. In particular §A ("this rung does NOT cut the keystone edge") and §B ("it
# still consumes coreutils and bash at BUILD time, and now declares them"). This script is the
# compiler half; the honest scope of the claim lives in build.ncl.
#
# Every compiler setting here corresponds to a MEASURED failure from the 2026-07-31 amd64 probe,
# not to guesswork. Where a value answers an autoconf probe rather than patching source, that is
# deliberate: this rung must not modify shipped coreutils sources.
set -eu

MB=/usr/lib/musl-bedrock            # the cc2 sysroot: headers + crt1/crti/crtn + libc.a
TCC=/usr/bin/tcc-musl2
LIBTCC1=/usr/lib/tcc/libtcc1.a      # the "alloca provider" (same role R12 gives it)
OUT="${OUTPUT_DIR:?OUTPUT_DIR required}"
# Local inputs (build.sh, stage0.answers) sit in the build root; remember it before any cd.
BUILDROOT="$(pwd)"
# The version arrives from build.ncl's `build_args = { include version }`. minimal exports build
# args UPPERCASED AND PREFIXED — sandbox2/src/config.rs::with_build_args builds
# "MINIMAL_ARG_" + key.to_uppercase() — so the variable is MINIMAL_ARG_VERSION, not `version`.
# (Verified against the ~40 packages already doing this, e.g. packages/age/build.sh:15.)
# Nothing here hardcodes a version: a bump is a one-line change in build.ncl's VERSION DECISION POINT.
VERSION="${MINIMAL_ARG_VERSION:?MINIMAL_ARG_VERSION required (build.ncl build_args must include version)}"

# ---- infra guards: name the missing artifact rather than failing 2000 lines into a build ----
[ -x "$TCC" ]            || { echo "stage0-coreutils: no tcc at $TCC" >&2; exit 1; }
[ -d "$MB/include" ]     || { echo "stage0-coreutils: no musl headers at $MB/include" >&2; exit 1; }
[ -f "$MB/lib/crt1.o" ]  || { echo "stage0-coreutils: no crt1.o at $MB/lib" >&2; exit 1; }
[ -f "$LIBTCC1" ]        || { echo "stage0-coreutils: no libtcc1.a at $LIBTCC1" >&2; exit 1; }
command -v ld >/dev/null || { echo "stage0-coreutils: no ld on PATH (need stage0-binutils)" >&2; exit 1; }
# The HOST tools ./configure and make will use. These are declared build_deps as of 2026-08-02
# (bash, make, sed, grep, gawk-bootstrap, diffutils, coreutils); before that they were undeclared
# and this loop is what would have caught it. An undeclared dep is worse than a declared one
# precisely because nothing fails until something subtle does.
# NB `sha256sum` and `head` here are the HOST's, used by the CU-SEAL block at the tail — not the
# ones this rung builds. coreutils 5.0 cannot build sha256sum at all; see build.ncl.
for h in make sed grep awk diff rm mkdir cat cut head install sha256sum; do
  command -v "$h" >/dev/null || {
    echo "stage0-coreutils: host tool '$h' missing — a build_dep in build.ncl is wrong" >&2
    exit 1
  }
done

# ASSERT WE HAVE THE TCC-COMPATIBLE MUSL, not the gcc-built stock one. Getting this wrong is what
# produced "bits/alltypes.h: ';' expected (got \"va_list\")" for an entire debugging session:
# stage0-musl-1.2.5 carries none of the tcc workarounds; the cc2 variant defines __builtin_va_list
# via tcc's SysV __va_list_struct. Checking the marker is cheap; discovering it via a compile
# failure is not.
grep -q '__TINYC_va_list_defined' "$MB/include/bits/alltypes.h" || {
  echo "stage0-coreutils: $MB is NOT the tcc-patched musl (no __TINYC_va_list_defined)" >&2
  echo "  this rung requires stage0-musl-1.1.24-cc2, not stage0-musl-1.2.5" >&2
  exit 1
}

# ---- the compiler wrapper, mirroring stage0-gcc-4.0.4's musl-cc ----
# -nostdinc + explicit -I: the coin-flip /usr/include carries glibc headers that collide with musl
# under minimal's first-writer-wins rootfs (the anti-pollution rationale stage0-gcc-4.0.4 documents).
# $LIBTCC1 on the LINK line only: with musl's alloca.h suppressed, tcc emits a call to alloca.
CC_WRAP="$BUILDROOT/musl-cc"
cat > "$CC_WRAP" <<WRAP
#!/bin/sh
for a in "\$@"; do case "\$a" in -c|-S|-E) exec $TCC -nostdinc -I "$MB/include" "\$@" ;; esac; done
exec $TCC -nostdinc -I "$MB/include" -B "$MB/lib" -L "$MB/lib" "\$@" $LIBTCC1
WRAP
chmod 0755 "$CC_WRAP"

# ---- gate BEFORE the build: a compiler that cannot produce a running binary fails now, not in
# ---- the middle of a 300-file make.
cat > /tmp/cc-probe.c <<'EOF'
#include <stdio.h>
int main(void) { puts("cc-ok"); return 0; }
EOF
"$CC_WRAP" -static -o /tmp/cc-probe /tmp/cc-probe.c
[ "$(/tmp/cc-probe)" = "cc-ok" ] || { echo "stage0-coreutils: tcc cannot build a running binary" >&2; exit 1; }
echo "stage0-coreutils: compiler gate PASS (tcc-musl2 + $MB)" >&2

# CLEAN-TREE DISCIPLINE. coreutils sources carry 2002/2003 mtimes, so re-extracting a tarball over
# an existing tree NEVER invalidates a stale .o. That is exactly how the retracted aarch64 CUA_PASS
# happened: a run that attempted 2 compiles (both failing) inherited 119 objects and all 5 "gated"
# tools from earlier, differently-flagged runs. Inside minimal's sandbox the build dir is fresh per
# build, so there is nothing to clean here — but if you ever port this to a bare VM, wipe the tree
# first or you will certify someone else's artifacts.
SRCDIR="coreutils-$VERSION"
[ -d "$SRCDIR" ] || { echo "stage0-coreutils: no $SRCDIR/ (Source extract=true failed?)" >&2; exit 1; }
cd "$SRCDIR"

export CC="$CC_WRAP"
# CFLAGS — each -D is one of the measured walls in build.ncl. Do not trim this without re-measuring.
#   -D_GNU_SOURCE   : load-bearing twice over. configure.ac has AC_GNU_SOURCE so config.h defines it
#                     anyway for coreutils' own TUs (dropping it is a semantic no-op there — the
#                     retracted aarch64 run "fixed" nothing by removing it), BUT it is what makes
#                     musl DECLARE mempcpy, which -D__mempcpy=mempcpy below depends on.
#   -D_ALLOCA_H     : musl's alloca.h declares `void *alloca(size_t)` while tcc has a builtin of a
#                     different type => "incompatible types for redefinition of 'alloca'".
#                     Pre-defining the guard skips the header; the file on disk is untouched.
#                     MUSL-ONLY. On glibc this flag is actively harmful — never copy it to a glibc rung.
#   -DGETLINE_H_  : REPLACES -D__GLIBC__=2, which was documented here as measured fact and
#                   provably builds NOTHING. Clean-tree VM build 2026-08-02 (minimermetic
#                   commit 381c2c6) plus an independent preprocessor test: declaring
#                   __GLIBC__ makes lib/getopt.c:52 and getopt1.c:49 take
#                       #if !defined _LIBC && defined __GLIBC__ && __GLIBC__ >= 2
#                       # include <gnu-versions.h>
#                   and musl ships no such header. Both files are unconditional members of
#                   libfetish_a_SOURCES, so lib/ dies at object #2 and nothing links. The
#                   earlier run only 'worked' because getopt.o was already on disk from a
#                   build PREDATING the flag -- a dirty tree concealing a real defect.
#                   The actual problem is narrower: lib/getline.h:30 guards its conflicting
#                   `int getline(...)` with `#if __GLIBC__ < 2`, true when __GLIBC__ is
#                   undefined. Suppressing that ONE header via its own include guard
#                   (GETLINE_H_, read from line 17) fixes it without claiming to be glibc;
#                   musl still declares getline in <stdio.h> under _GNU_SOURCE.
#                   -D__mempcpy=mempcpy goes too: it was only a follow-on of the wrong flag.
export CFLAGS="-static -D_GNU_SOURCE -D_ALLOCA_H -DGETLINE_H_"

# Autoconf answers, all responses to measured probe failures under tcc:
export ac_cv_func_malloc_0_nonnull=yes ac_cv_func_realloc_0_nonnull=yes
# COHERENT alloca answer: header absent AND works=no, so configure builds coreutils' own
# lib/alloca.c. Saying works=yes here leaves alloca undefined at link for every tool that uses one
# (du/ls/dir/vdir/ginstall fail; chmod/rm, which use none, link fine) — that asymmetry is how the
# inconsistency was found.
export ac_cv_header_alloca_h=no ac_cv_func_alloca_works=no
# musl 1.1.24 provides these; telling configure so stops coreutils substituting its own REPLACEMENT
# OBJECTS. It does NOT stop any header from declaring them — see -D__GLIBC__=2 above, which is what
# actually cures the getline collision.
export ac_cv_func_getline=yes ac_cv_func_getdelim=yes
export ac_cv_func_strndup=yes ac_cv_func_strnlen=yes
export ac_cv_func_mkstemp=yes ac_cv_func_memrchr=yes

./configure --disable-nls --prefix=/usr

# SCOPE: TOP-LEVEL `make`, WHICH THE 2026-07-31 amd64 PROBE MEASURED AT rc=2 (5 of ~90 tools built).
# Kept at top level because that is the configuration the flags above were measured in, and because
# `set -eu` makes a non-zero rc FAIL THE BUILD rather than silently continue to a gate that would
# then certify whatever happened to exist. Narrowing to `make -C lib && make -C src <tools>` would
# probably get further, but nobody has measured it.
#   >>> OPERATOR TODO: decide the make scope AFTER the first CS run produces a real error tail.
#   >>> Do not narrow it speculatively; the last two "fixes" to this rung were speculative.
make -j"${MAKE_JOBS:-4}"
make DESTDIR="$OUT" install

# ============================== FUNCTIONAL GATE ==============================
# "It built" is NOT accepted as proof. A hash tool must reproduce KNOWN digests — one that runs and
# computes garbage is worse than one that fails.
#
# WHICH TOOL THIS GATE USES, AND WHY THAT IS NOT ENOUGH:
#   It gates md5sum, because md5sum is the only hash tool coreutils 5.0 ships (measured: zero
#   "sha256" references anywhere in the 5.0 tree). md5sum is evidence about THE COMPILER — it shows
#   tcc-musl emitted code that computes correctly. It is NOT evidence about the capability the
#   bedrock needs: 11 of the 24 stage0 build.sh invoke `sha256sum` (their `sha256sum -c
#   stage0.answers` seals) and ZERO invoke md5sum. The two earlier "proofs" of this rung both
#   certified md5sum while claiming the sha256sum requirement was met. It was not.
#
# MEASURED 2026-08-02: THE OLD sha256sum GATE COULD NOT PASS. coreutils 5.0 ships no SHA-2 at all —
# src/Makefile.am bin_PROGRAMS lists md5sum and sha1sum only, and there is no lib/sha256.c. The
# first release with a sha256sum target is 6.0 (2006-08-15); the first on ftp.gnu.org is 6.3.
# See build.ncl's MEASURED block for the full version table and for why bumping to 6.x is not the
# recommended cure. That gate has therefore been REPLACED, not weakened: it was unsatisfiable.
#
#   >>> OPERATOR TODO — THE SINGLE PLACE THE SHA-2 DECISION LANDS IN THIS FILE. When build.ncl's
#   >>> VERSION DECISION POINT is settled at a version that ships SHA-2, re-add `sha256sum` to
#   >>> build.ncl's `outputs` and add the sha256sum vectors to HASH_GATE below. Until then this
#   >>> rung MUST NOT be imported by any rung that seals with `sha256sum -c`.
#   >>> Known vectors for that day:
#   >>>   sha256("abc") = ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
#   >>>   sha256("")    = e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
HASH_TOOL="$OUT/usr/bin/md5sum"
[ -x "$HASH_TOOL" ] || { echo "CU-GATE: FAIL (no md5sum installed at $HASH_TOOL)" >&2; exit 1; }
# Two vectors, so a single lucky constant cannot pass the gate.
printf 'abc' > /tmp/cu-gate-abc.txt
printf ''    > /tmp/cu-gate-empty.txt
GOT_ABC="$("$HASH_TOOL" /tmp/cu-gate-abc.txt   | cut -d' ' -f1)"
GOT_NUL="$("$HASH_TOOL" /tmp/cu-gate-empty.txt | cut -d' ' -f1)"
WANT_ABC=900150983cd24fb0d6963f7d28e17f72
WANT_NUL=d41d8cd98f00b204e9800998ecf8427e
echo "CU-GATE diag: md5sum('abc') = $GOT_ABC" >&2
echo "CU-GATE diag: md5sum('')    = $GOT_NUL" >&2
[ "$GOT_ABC" = "$WANT_ABC" ] || { echo "CU-GATE: FAIL (md5 'abc' expected $WANT_ABC)" >&2; exit 1; }
[ "$GOT_NUL" = "$WANT_NUL" ] || { echo "CU-GATE: FAIL (md5 '' expected $WANT_NUL)" >&2; exit 1; }

# Every tool this rung declares as an OutputBin must exist AND run. The OutputBin globs are a
# second, independent fail-shut (a glob that matches nothing fails the build), but failing here
# gives a name instead of a glob.
GATED_TOOLS="chmod cp mkdir rm cat sort tr install md5sum"
for t in $GATED_TOOLS; do
  [ -x "$OUT/usr/bin/$t" ] || { echo "CU-GATE: FAIL ($t missing)" >&2; exit 1; }
  "$OUT/usr/bin/$t" --version >/dev/null 2>&1 || { echo "CU-GATE: FAIL ($t does not run)" >&2; exit 1; }
done
echo "CU-GATE: PASS — 9 tools built by tcc-musl2 + stage0-musl-1.1.24-cc2 + stage0-binutils-2.30," >&2
echo "  md5sum verified on 2 vectors, no gcc and no glibc in the COMPILER half of this rung." >&2
echo "  NOT a claim that the coreutils edge is cut: this rung's own build_deps include coreutils" >&2
echo "  and bash (build.ncl §B), and it produces NO sha256sum, which 11 of 24 stage0 rungs need." >&2

# ============================== BYTE-IDENTITY SEAL ==============================
# stage0.answers is a declared `| Local` input, so it must exist for the package to DECODE at all
# (decode panics on an unreadable Local input). Making it exist is not enough — an input nothing
# reads is decoration, and decoration is how vacuous passes start. So it is read here.
# Same protocol as stage0-musl-1.1.24-cc2: an `# UNPINNED` first line means RECORD ONLY; once the
# operator pastes real hashes in, every rebuild must match, and SEAL_FATAL=1 makes a mismatch fatal.
# Paths in stage0.answers are RELATIVE to $OUTPUT_DIR, so the check runs from there.
# NOTE the `sha256sum` below is the HOST's (from the declared `coreutils` build_dep), not the one
# this rung builds — which it cannot, see above. That is a further reminder of §B.
SEAL_FATAL="${SEAL_FATAL:-0}"   # flip to 1 once stage0.answers carries real hashes
if head -1 "$BUILDROOT/stage0.answers" 2>/dev/null | grep -q '^# UNPINNED'; then
  echo "CU-SEAL: NOT YET PINNED — record from this roll with, in \$OUTPUT_DIR:" >&2
  echo "    sha256sum $(for t in $GATED_TOOLS; do printf 'usr/bin/%s ' "$t"; done)" >&2
  ( cd "$OUT" && for t in $GATED_TOOLS; do sha256sum "usr/bin/$t"; done ) >&2 || true
else
  if ( cd "$OUT" && sha256sum -c "$BUILDROOT/stage0.answers" ); then
    echo "CU-SEAL: byte-identity OK" >&2
  else
    echo "CU-SEAL: MISMATCH against stage0.answers." >&2
    if [ "$SEAL_FATAL" = 1 ]; then
      echo "  SEAL_FATAL=1 -> failing the build." >&2
      exit 1
    fi
    echo "  SEAL_FATAL=0 (capture window) -> non-fatal; re-capture, then set SEAL_FATAL=1." >&2
  fi
fi
