# R10 (stage0-binutils-2.41) — prep findings (2026-07-01, DRAFT — not built/enqueued)

> **UPDATE 2026-07-03:** SUPERSEDED. R10 binutils-2.41 was BUILT + SEALED (trust-grade SLSA-L4);
> **B3 is CLOSED** (spine sealed through R11 gcc-10.4.0). This draft was superseded first by the
> later `r10-binutils-2.41-preflight.md` and then by the seal itself. The "Open questions" below
> (R9 static `libstdc++.a`, native install set, unprefixed tool names) are all RESOLVED by the
> successful build. The pivot rung referenced as "gcc-10.5.0" in the wall discussion (point 7) is
> retired — the actual pivot is **gcc-10.4.0** (R11). Retained below for historical context only.

binutils-2.41 = modern as/ld/ar/nm/objcopy/objdump/ranlib/readelf/strip, built BY gcc-4.7.4 (R9),
linked static against musl-1.2.5 (R7). The gcc-built analog of R5 (which tcc built). Source:
`gs://minimal-staging-archives/binutils-2.41.tar.xz`,
sha256 `ae9a5789e23459e59606e6714723f2d3ffc31c03174191ef0d015bdf06007450`
(**confirmed by download+shasum**, matches the truncated `ae9a5789e234…` in the forward map — the
`bedrock-ladder-R4-R11-2026-06-25.md` the task cited does NOT exist; only `bedrock-r8-r11-forward-map.md`).

## Tarball recon (extracted + inspected locally)
- **Top-level `configure` exists** → R10 uses a single top-level out-of-tree configure, NOT R5's
  per-subdir hand-loop. R5 hand-looped only because tcc + i386 opcodes made the top-level path
  fragile; gcc has no such trouble. Much less surface.
- **config.sub timestamp = 2023-06-23** → knows `x86_64-linux-{gnu,musl}` natively → **no donor
  config.sub swap** (unlike the early hand-swapped rungs). Confirmed the task's expectation.
- **New-vs-2.30 subdirs present:** `gold/` (C++ linker), `gprofng/` (profiler, bison/flex + Linux),
  `libctf/`, `libsframe/`, `libctf`/`libsframe` are C. `gold`+`gprofng` are the risk — **disabled**.

## Key recipe decisions (why)
1. **CC/CXX = R9's gcc-cc / gcc-cxx wrappers**, copied verbatim from R9 (libc-using variant onto
   `/usr/lib/musl-bedrock-1.2.5`). All R5 tcc-isms dropped: no @PLT strip, no asm-rm, no
   libtcc1<->libc "libc twice" link dance.
2. **AR=ar RANLIB=ranlib = real binutils-2.30 (R5)**, not `tcc -ar`.
3. **`--prefix=/usr` + `make install DESTDIR=$OUTPUT_DIR`, then `rm usr/lib/*.la`** — the SAME as R5
   binutils and R6/R9 gcc. **This deliberately contradicts the forward-map note** ("R10 installs
   libtool libs → same [R8 writable-staging-prefix] idiom"): see the correction below. Then `rm` the
   `.la` (they bake the dead build path; downstream links the static `.a`).
4. **`--disable-shared --disable-nls --disable-werror --disable-gold --disable-gprofng
   --disable-plugins --enable-deterministic-archives --enable-64-bit-bfd --enable-install-libbfd
   --with-sysroot=`**. `--enable-install-libbfd` guarantees libbfd.a/libopcodes.a + bfd.h land in
   `/usr` (native binutils otherwise may skip installing them → empty OutputLib/headers globs).
   `--disable-werror` matters: gcc-4.7.4 will emit warnings on 2023 source that 2.41 may `-Werror`.
5. **Model-B mtime guard + LOUD regen stubs** (bison/flex/perl/pod2man/help2man/texi2pod/makeinfo).
   Baseline everything old, then bump every `*.c/*.h/*.info/configure/Makefile.in/*.1/*.pod` newer.
6. **A smoke gate**: the freshly-built as+ld must assemble+link a running static-musl exe
   (`-B $OUTPUT_DIR/usr/bin` forces the NEW as/ld) → proves end-to-end, not just "compiled".

## ⚠ CORRECTION to the forward map (load-bearing — flag for the operator)
The forward map says R10 should use R8's **writable-staging-prefix** idiom because it "installs
libtool libs too." **That idiom does NOT transfer to R10** and would produce a **broken as/ld**:
- The R8 idiom exists for a *library-only* rung whose build-time LINK reads a **dependency's
  installed `.la`** at a logical libdir (mpc reading `/usr/lib/gcc-math/lib/libmpfr.la` while `/usr`
  was read-only). binutils has **no cross-package installed-.la build-time dep** — its internal
  `libbfd.la`→`libopcodes.la` refs are **relative, in the build tree**, resolved before install, so
  DESTDIR is irrelevant to them.
- binutils installs **prefix-baking BINARIES** (`ld` bakes its search/sysroot paths, `as` its
  libdir). `--prefix=$BUILDROOT/stage` would bake a `/build/...` path into `ld` → it looks for libs
  under the dead build dir at runtime. `--prefix=/usr` (the final location) + DESTDIR is mandatory —
  exactly what R5/R6/R9 already do. With `--disable-shared`, libtool does no install-time relink, so
  there is no read-only-/usr write either.
Confidence: high. If a build-time `.la` resolution error DOES appear, revisit — but the mechanism the
forward map cites is a library-rung phenomenon, not a binaries-rung one.

## Predicted walls, ranked by likelihood
1. **[HIGH] `as`/`ld`/`ranlib` not on PATH — the omitted R5 dep.** The task's stated dep list
   (gcc-4.7.4 + musl-1.2.5 + diffutils + xz + shell tools) has **no binutils-2.30**. But R9's gcc
   *shells out* to `as`/`ld` to assemble+link its own output (gcc bundles neither). First compile
   dies `as: command not found`. **Fixed in the draft build.ncl** by adding `stage0-binutils-2.30`
   to build_deps (mirrors R9, which re-imports R5 explicitly — build_deps are not transitive here).
   The build.sh also `command -v as` preflights and fails loud.
2. **[HIGH] Model-B regen trigger** (bison/flex parsers: `ld/ldgram.c`, `ld/ldlex.c`,
   `binutils/{arparse,deffilep,mcparse,rcparse,sysinfo}.c`, `gas/*`; + pod2man/texi2pod man pages).
   2.41's generated set differs from 2.30 and R5 did NO explicit mtime guard (it relied on tarball
   mtimes). If any `.y/.l/.pod` extracts newer than its shipped output, make runs the absent tool.
   Mitigated by the aggressive mtime guard; the LOUD stubs name any miss → add to the touch list.
3. **[MED] top-level `AC_PROG_CXX` probe / C++ surface.** 2.41's top-level configure probes a C++
   compiler. gold+gprofng (the real C++ consumers) are disabled, so the gcc-cxx wrapper only serves a
   headerless `int main(){}` probe (`-nostdinc` is safe there; g++ finds its own static libstdc++.a
   from R9). Risk: (a) if R9 didn't actually build/install `libstdc++.a` static, the probe's `-static`
   link fails → set `CXX=false`/`--disable-…` further, or verify R9's libstdc++.a exists; (b) if some
   enabled subdir compiles real C++ after all, the wrapper needs the libstdc++ include dirs (drop
   `-nostdinc` for CXX). Open question below.

### Lower-likelihood
4. **[LOW] gcc-4.7.4 too old for 2.41 C source.** 2.41 (2023) core stays portable C (binutils keeps
   old-host support; it's GCC-itself, not binutils, that needs C++11 — which is why R9 exists for
   R11). gcc-4.7.4 does C99 + partial C11. Watch for `_Static_assert`/anonymous-union/`_Generic`
   usage; `--disable-werror` already downgrades warnings.
5. **[LOW] libctf/libsframe static-musl quirks.** Both are C, low risk. Fallback: `--disable-libctf`
   (ld/objdump lose CTF display — acceptable for bedrock). libsframe has no disable knob but is small.
6. **[LOW] zlib crc/inffixed regen.** R5 carried `-DDYNAMIC_CRC_TABLE=1 -DBUILDFIXED=1` as tcc
   workarounds. Under gcc the bundled zlib ships all generated tables; the draft omits those defines.
   If a `make crc32.h`/`makefixed` step fires, re-add them (or `--with-system-zlib` is NOT an option —
   no system zlib in the sysroot).
7. **[LOW] `--disable-plugins` vs downstream LTO.** R11 (gcc-10.4.0) will `--disable-lto` (lto-plugin
   is a .so that can't link static musl), so ld needs no plugin support. If a later rung DOES want
   plugin-ld, flip to `--enable-plugins` (static musl `dlopen` links fine, returns NULL at runtime).

## Open questions (resolve at/ before first cloud build)
- **Does R9 install a STATIC `libstdc++.a`?** The CXX probe's `-static` link depends on it. R9's
  outputs glob `usr/lib/gcc/**` + `usr/libexec/**` + `usr/bin/*`; libstdc++.a location under 4.7.4 is
  `usr/lib/gcc/x86_64-linux-gnu/4.7.4/` or `usr/lib/` — confirm it's captured. If not, either add it
  to R9's outputs or set `CXX=false` and confirm 2.41 top-level tolerates a non-working C++ when
  gold/gprofng are off (it should — gold-off makes C++ non-fatal).
- **Does native 2.41 install `readelf`/`strip`/`ranlib` unprefixed under `--program-prefix=""`?**
  Expected yes; the smoke gate + `usr/bin/*` glob will show the actual set. `size/strings/c++filt/
  addr2line` ride along.
- **`--enable-install-libbfd` header set:** confirm `usr/include/{bfd.h,ansidecl.h,bfdlink.h,…}`
  actually populate (the headers OutputData glob). If bfd.h is generated from bfd-in2.h at build,
  the mtime guard must not have blocked it (it's a build-time gen, not a bison regen — fine).
- **Peak RAM / `-j`:** draft uses `-j1` (conservative). binutils is far lighter than gcc; `-j` could
  be raised if the queue timeout is tight, but `-j1` removes the OOM variable for the first build.

## Reflexes applied (from the forward map + R8 learnings)
`chmod +x build.sh` (done) · `tar --no-same-owner` (xz tarball, chown-hostile) · gcc-cc libc-using
wrapper copied from R9 · `diffutils` in the closure for configure's cmp/diff · version string has no
`+` (`2.41`) · `--enable-deterministic-archives` for reproducible `.a` · real `source_commit` needed
in the manifest at pin time (not `000`) · verify builder `status==RUNNING` after any deploy.
