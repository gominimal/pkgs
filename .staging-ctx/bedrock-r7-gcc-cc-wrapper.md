# R7+ prep — the `gcc-cc` wrapper (gcc-4.0.4 as CC onto the clean musl sysroot)

**Written 2026-07-01, right after R6 (gcc-4.0.4) first built.** Banks the single highest-leverage
lesson from R6 so R7+ don't rediscover it three times over.

> **UPDATE 2026-07-03:** VALIDATED and DONE. The Option-(B) per-rung wrapper below was baked into
> every sealed rung R7→R11 (musl-1.2.5, gmp/mpfr/mpc, gcc-4.7.4, binutils-2.41, gcc-10.4.0) — **B3 is
> CLOSED**, whole spine SLSA-L4 attested. R12 (gcc-15.2.0) is BUILT+FUNCTIONAL and rebuilding-to-SEAL
> (seal was blocked by a content-hash aliasing bug on the shared linux_headers mirror slot; unblocked
> 2026-07-03 via a trust-neutral clean-envelope stopgap, durable spec-qualified-mirror fix = issue #14).
> B4 = the musl→glibc hop (TARGET=glibc, conventional path; recipe designed, NOT yet built). This doc's
> forward-looking sections below are now retrospective — read them as "what we decided and shipped."

## The problem

R0–R6 used **tcc-musl2** as CC via the `musl-cc` wrapper. From **R7 up, CC is our gcc-4.0.4** — and
gcc reaches for the coin-flip `/usr` (glibc vs musl, first-writer-wins in minimal's unordered rootfs —
see MEMORY `minimal_rootfs_nondeterministic_pollution`) in **three** independent ways. We watched all
three in R6's own libgcc build:

| vector | symptom in R6 | fix |
|---|---|---|
| system **headers** | `/usr/include/bits/errno.h` → absent `linux/errno.h` | `CPATH=$MB/include` (or `-nostdinc -isystem`) |
| `-lm` / `-lc` **libs** | link drags in glibc `_dl_x86_cpu_features` | `-L $MB/lib` (musl math is in libc.a; libm.a is an empty stub) |
| **crt** (driver-injected) | crt1.o/crti.o/crtn.o pulled from glibc `/usr/lib` | `-B $MB/lib` so the driver finds musl's crt first |

`$MB = /usr/lib/musl-bedrock` = R4b's single-writer clean musl sysroot (`include/` + `lib/`).

## Candidate wrapper (VALIDATED — baked into sealed R7–R11)

```sh
#!/bin/sh
# gcc-cc — our from-source gcc-4.0.4 forced onto R4b's clean musl-bedrock sysroot, never the coin-flip /usr.
MB=/usr/lib/musl-bedrock
GI=/usr/lib/gcc/x86_64-linux-gnu/4.0.4/include   # gcc's OWN compiler headers (stddef/stdarg/...) — keep these
for a in "$@"; do case "$a" in
  -c|-S|-E) exec /usr/bin/gcc -nostdinc -isystem "$GI" -isystem "$MB/include" "$@" ;;  # COMPILE: musl hdrs only
esac; done
# LINK: -B makes the driver find musl crt1/crti/crtn; -static musl; gcc's own crtbegin/crtend (musl-built in R6) are fine.
exec /usr/bin/gcc -nostdinc -isystem "$GI" -isystem "$MB/include" -B "$MB/lib" -L "$MB/lib" -static "$@"
```

Notes / risks to confirm on R7:
- `-nostdinc -isystem $GI` is the DETERMINISTIC form (no glibc fallback). The cheap form is just
  `export CPATH=$MB/include; export LIBRARY_PATH=$MB/lib` — that worked for R6's *own* libgcc build, but it
  leaves `/usr/include` as a fallback (fine only because R6's crtstuff needs no glibc-only header). Prefer
  `-nostdinc` for R7+ source we don't control.
- R7 musl / R8 gmp-mpfr-mpc mostly **compile + archive** (few executable links) — so the COMPILE path is
  the load-bearing half. Get that right first.
- gcc uses `crt1.o` for `-static` (matches musl's `crt1.o`); gcc's own `crtbegin.o/crtend.o` come from its
  install dir (R6-built, musl) — do NOT try to substitute those.

## The one decision to make AT R6 SEAL — DECIDED: Option (B), per-rung wrapper

> **DECIDED 2026-07-03 (executed across sealed R7–R11):** shipped **Option (B)** — the per-rung wrapper.
> No gcc-build sysroot bake was needed; the wrapper held clean through the modern-C++ pivot (R11
> gcc-10.4.0). Option (A) was never required.

**Bake the sysroot into gcc, or wrap per-rung?**
- **(A) bake:** configure gcc-4.0.4 `--with-sysroot=<musl-layout>` so the *installed* gcc defaults to musl
  and R7+ can pass runtime `--sysroot` (or need nothing). Cleanest, but: runtime `--sysroot` only works if
  gcc was built `--with-sysroot`, AND the sysroot needs a `usr/include` + `usr/lib` layout (musl-bedrock is
  currently `include`/`lib`) — so it needs a small layout tweak in R4b (or a build-side symlink shim).
- **(B) wrapper (above):** zero gcc-build change, proven-shaped by R6's own recipe, but every R7+ build.sh
  sources it. Lower risk to land now.

Recommendation: ship **(B)** for R7 to keep moving; revisit **(A)** if the wrapper gets unwieldy. If we DO
bake (A), the layout shim is: `mkdir -p /build/sysroot/usr && ln -s $MB/include /build/sysroot/usr/include
&& ln -s $MB/lib /build/sysroot/usr/lib` then `--with-sysroot=/build/sysroot` (build-side only, no re-vendor).

## Mechanical checklist for EVERY new bedrock rung (auto-apply, don't rediscover)

- [ ] `chmod +x build.sh` (new draft files land 644 → `execve EACCES`)
- [ ] `tar --no-same-owner -xf` (userns can't chown to the archived uid)
- [ ] gcc-cc wrapper above (headers + `-L $MB/lib` + `-B $MB/lib`)
- [ ] **gcc rungs only (R9/R11):** no-op `fixinc.sh` stub at `build/fixincludes/fixinc.sh` (or `--disable-fixincludes` if the newer gcc has it)
- [ ] Model-B for autotools tarballs: mtime-guard (touch generated files newest) + regen-tool stubs that fail LOUD
- [ ] real `source_commit` in main-repo manifest (never `000…0` — signer's verify_intoto rejects the sentinel)
- [ ] `chain_enforce` cascade order: build each dep STANDALONE (→ attested) before the consumer
- [ ] gcc-4.0.4 is 2005/C89-era: expect `-std=`/compat seds on newer source (musl-1.2.5, gmp/mpfr)

## Cost model (from R6)

RemoteCache carries the whole closure: the FIRST full compile is the cost; every wall-clear after is ~14s.
Don't panic at a slow first R7 build — the walls after it are cheap.
