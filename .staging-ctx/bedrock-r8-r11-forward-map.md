# R8→R11 forward map (written 2026-07-01; updated: R7 musl-1.2.5 + R8 gmp/mpfr/mpc now ✅ SEALED trust-grade L4, R9 gcc-4.7.4 building)

> **UPDATE 2026-07-03:** This whole ladder is now **history — R8, R9, R10, R11 are ALL SEALED trust-grade L4. B3 IS CLOSED** (hex0 seed → … → gcc-10.4.0 pivot, every rung attested in CS). The tables/risk-notes below are a correct *historical* record of the plan, but every "building"/"when sealed"/"pending" phrasing is superseded. Current frontier: **R12 = gcc-15.2.0** (first modern gcc ≥12.1, required by glibc-2.42; artifact BUILT + FUNCTIONAL, SEALING now — was blocked by the content-hash aliasing bug, unblocked 2026-07-03 via a trust-neutral stopgap; durable fix = issue #14). Next phase **B4 = musl→glibc** (glibc-2.42, conventional path, recipe DESIGNED but NOT built; 368 pkg recipes change zero lines, only the 7 toolchain leaves' cycle-breakers flip). Beware the correctness ceiling (float/locale/TLS/IFUNC gate at R12+B4). See memory `r5_binutils_progress`.

Companion to `bedrock-r7-gcc-cc-wrapper.md`. Captures the CC/sysroot progression + a wrapper
gotcha that will bite R8 if not anticipated, so the upper rungs go as fast as gcc did.

## Sources — mirror status (checked 2026-07-01)
All R8–R11 toolchain tarballs are **already in `gs://minimal-staging-archives/`**:
| pkg | file | sha256 (ladder pin) |
|---|---|---|
| gmp-6.2.1 | `gmp-6.2.1.tar.xz` | `fd482991…` |
| mpfr-4.1.0 | `mpfr-4.1.0.tar.xz` | `0c98a3f1…` |
| mpc-1.2.1 | `mpc-1.2.1.tar.gz` | `17503d2c…` |
| gcc-4.7.4 | `gcc-4.7.4.tar.bz2` (FULL, not core — needs C++) | `92e61c6dc3a0…` |
| binutils-2.41 | `binutils-2.41.tar.xz` | `ae9a5789e234…` |
| gcc-10.4.0 ★ pivot | `gcc-10.4.0.tar.xz` (FULL) | `c9297d5bcd7c…` (mirrored+verified 2026-07-01; 10.5.0 retired — 4.7.4 can't build its C++11-host req) |

**Gap:** `linux-4.14.336` is NOT mirrored. Deferred — musl is self-contained, the toolchain rungs
build without kernel headers. Mirror only if/when a rung fails on `#include <linux/*.h>` (watch R9).
(Get the exact sha at mirror time; curl kernel.org → verify → `gcloud storage cp` to the archives bucket.)

> **UPDATE 2026-07-03:** `linux-4.14.336` was a **red herring** — no R8–R11 rung ever needed it, and B4 does NOT use it either. Ground truth: the kernel-UAPI headers come from the **production `linux-headers-6.12.43`** (there is a `stage0-linux-headers-6.12.43` rung). That header pair is byte-identical → shares one content-addressed mirror slot → is the CENTER of the issue-#14 content-hash **aliasing bug** that blocked R12's seal. Do NOT re-attest `stage0-linux-headers` in any cascade (it re-poisons the shared `sha256/083cdb.intoto` slot).

## The CC / sysroot progression
> **UPDATE 2026-07-03:** every rung in this table (R7–R11) is now **SEALED** — this is a correct historical record of the plan, not a live to-do.

| Rung | Package | CC | gcc-cc sysroot (`-B/-L`, libc hdrs) | Notes |
|---|---|---|---|---|
| R7 | musl-1.2.5 | gcc-4.0.4 | R4b `/usr/lib/musl-bedrock` (1.1.24) for probes; **PUBLISHES** `/usr/lib/musl-bedrock-1.2.5` | freestanding wrapper |
| R8 | gmp / mpfr / mpc | gcc-4.0.4 | `/usr/lib/musl-bedrock-1.2.5` (R7) | **libc-using wrapper** |
| R9 | gcc-4.7.4 | gcc-4.0.4 | `/usr/lib/musl-bedrock-1.2.5` | first C++; uses R8 gmp/mpfr/mpc |
| R10 | binutils-2.41 | **gcc-4.7.4** | `/usr/lib/musl-bedrock-1.2.5` | CC switches to R9's gcc |
| R11 | gcc-10.4.0 ★ | **gcc-4.7.4** | `/usr/lib/musl-bedrock-1.2.5` | the pivot; closes B3. **10.4.0 not 10.5.0** — 4.7.4's g++ can't build 10.5's C++11-host req; 10.4.0 = last C++98-bootstrappable |

Key idea: gcc-4.0.4 is *itself* a 1.1.24-linked binary, but the wrapper makes it **produce**
musl-1.2.5-linked output — a compiler's own libc ≠ the libc it targets. So the whole R8–R11 chain
links the modern musl-1.2.5 while the compilers underneath stay sealed.

## ⚠️ Wrapper gotcha: freestanding (R7) vs libc-using (R8+)
R7 (building musl itself) compiles **freestanding** — musl ships its own headers, so the wrapper adds
ONLY gcc's `-isystem <freestanding>`. **R8+ are normal libc-using programs** (`#include <stdio.h>` …),
so their wrapper MUST also add the musl libc headers on the COMPILE path:

```sh
# R8+ gcc-cc (libc-using): SR = /usr/lib/musl-bedrock-1.2.5
GI="$(gcc -print-file-name=include)"        # (gcc-4.7.4 for R10/R11)
for a in "$@"; do case "$a" in -c|-S|-E)
  exec /usr/bin/gcc -nostdinc -isystem "$GI" -isystem "$SR/include" "$@" ;;      # <-- +$SR/include vs R7
esac; done
exec /usr/bin/gcc -nostdinc -isystem "$GI" -isystem "$SR/include" -B "$SR/lib" -L "$SR/lib" -static "$@"
```

The R7 wrapper deliberately omits `-isystem $SR/include` on compile (freestanding); copying it verbatim
to R8 would fail every `#include <stdio.h>`. This is the single easiest mistake to make on R8.

## Per-rung risk & notes
- **R8 (gmp/mpfr/mpc)** — *most de-risked rung* (pure C static libs, no exotic needs). Three libs with
  a build order: **gmp → mpfr (needs gmp) → mpc (needs gmp+mpfr)**. Each `--disable-shared --with-pic=no`,
  `--with-gmp=`/`--with-mpfr=` pointing at the prior. Likely one build.ncl producing all three, or three
  chained rungs. Watch: gmp's `configure` runs CPU-feature `.asm` selection — force a generic ABI
  (`--disable-assembly` or `ABI=64`) so gcc-4.0.4 + binutils-2.30 aren't handed exotic asm.
- **R9 (gcc-4.7.4)** — *highest upper-spine risk* (U2/U3). First C++ (`cc1plus`/`g++`). **Do a local
  configure-probe first** (ladder TODO): confirm the shipped tree is Model-B-complete (no autoreconf/
  bison/flex regen) — its pass1.sh upstream DOES invoke autotools, so this is UNVERIFIED. `fixincludes`
  no-op stub applies again. `--enable-languages=c,c++`. config.sub swap + cache-var env (per ladder).
- **R10 (binutils-2.41)** — *cleanest upper rung* (modern, musl-native config.sub 2023). Built by R9's
  gcc-4.7.4. Mirrors R5's binutils recipe shape but with gcc, not tcc → no @PLT strip, no asm-rm.
- **R11 (gcc-10.4.0)** — the ★ pivot. **Retargeted from 10.5.0 (U3 resolved):** endgame-prep proved
  4.7.4's g++ CANNOT build 10.5.0 (10.5 back-ported a C++11 HOST requirement 4.7.4 lacks); 10.4.0 is the
  last C++98-bootstrappable gcc, which 4.7.4 builds directly → ZERO new rung. `includes.patch` + mtime
  guards (Model-B). ~~When green + sealed, **B3 closes**.~~ **DONE 2026-07-03: R11 green + sealed → B3 CLOSED.**

## Reusable reflexes (every rung, from R6+R7)
`chmod +x build.sh` · `tar --no-same-owner` for chown-hostile tarballs (musl `.gz` was fine; xz/bz2 rungs
need bzip2/xz in the closure) · gcc-cc wrapper (libc-using variant) · `fixincludes` stub on gcc rungs ·
versioned single-writer sysroot if the rung publishes a libc · real `source_commit` · `chain_enforce`
cascade order (dep standalone→attested→consumer) · RemoteCache ⇒ slow first build, ~14s wall-clears.

## R8 learnings (banked 2026-07-01 — from its three walls; ALL plumbing, zero codegen)
1. **`tar --no-same-owner` is mandatory** — R8 wall #1 (gmp's tree is owned uid 1006; plain `tar -xf`
   exits non-zero "Cannot change ownership … Invalid argument"). R7 got lucky (uid-0 tarball). Every
   upper rung's untar needs it (R9 `.tar.bz2`, R10/R11 `.tar.xz`).
2. **Autotools LIBRARY rungs: install to a WRITABLE staging prefix, NOT DESTDIR-to-`/usr`.** R8 wall #2:
   mpc's link failed — libtool reads `libmpfr.la`→`libgmp.la` by the **logical** libdir
   (`/usr/lib/gcc-math/lib`), but `--prefix=/usr/lib/gcc-math DESTDIR=$OUTPUT_DIR` puts the libs at
   `$OUTPUT_DIR/...` and `/usr` is bind-mounted READ-ONLY → "not a valid libtool archive". FIX:
   `--prefix=$BUILDROOT/<stage>` (logical==physical, no DESTDIR) so the `.la` cross-refs resolve during
   the build; then `cp -a` the tree to `$OUTPUT_DIR/usr/…` and **`rm -f …/*.la`** (they bake the dead build
   path; consumers link the static `.a`). **⚠️ R10 (binutils-2.41) is the EXCEPTION — do NOT reuse this
   idiom.** Binutils installs *executables* (`ld`/`as`/…), and `--prefix=$BUILDROOT/<stage>` would bake
   `/build/...` into the installed `ld`'s compiled-in search/lib paths → R10 must use standard
   `--prefix=/usr` + `DESTDIR=$OUTPUT_DIR`; the writable-staging-prefix trick is only safe for R8's
   static-lib-only rung.
   gcc rungs (R9/R11) READ R8's static `.a` via `--with-gmp=/usr/lib/gcc-math` (which is why R8 drops .la).
3. **Version strings CANNOT contain `+`** — R8 wall #3: the BUILD fully succeeded, but sign-staging
   rejected the version `gmp-6.2.1+mpfr-4.1.0+mpc-1.2.1` ("only `[A-Za-z0-9._-]` allowed in sign-staging
   prefix components"). Combined/multi-source rungs must anchor on ONE version (R8 → `6.2.1`) or join with
   `-`/`.`, never `+`. (Presented as `build_script_failed`, but it's post-build — check `orch why`.)
4. **`diffutils` on PATH** — configure's `cmp`/`diff` (non-fatal in R8; added to R9 preemptively). `file`
   was also missing (only a warning).
5. **Wedge:** verify builder `status==RUNNING` after ANY deploy (it can boot-then-terminate on an empty
   queue → tasks sit pending). Full note: memory `r5_binutils_progress`.
