#!/bin/sh
# ============================================================================================
# build.sh — B4.1 (stage0-linux-headers-6.12.43) driver.  DRAFT 2026-07-02.
# ============================================================================================
# THE BRIDGE PROOF: the FIRST consumer of the R11 pivot (gcc-10.4.0) AS A COMPILER, and the first
# B4 rung.  Re-roots minimal's production linux-headers (packages/linux_headers) onto the seed-rooted
# from-source toolchain — pivot gcc-10.4.0 (R11) + binutils-2.41 (R10) + musl-1.2.5 sysroot (R7).
# Its whole job is to prove the extract_to_root / toolchain bridge seam end-to-end at ~0 codegen
# risk BEFORE we commit to the heavy glibc-vs-musl target decision (both targets need these headers).
#
# WHY ~0 RISK: `make headers` compiles exactly ONE thing — the host tool scripts/unifdef — then runs
# a sed/sh header-export.  The emitted kernel UAPI headers are LIBC-INDEPENDENT (they are the kernel's
# own <linux/*.h>/<asm/*.h>), so the compiler choice cannot change the output bytes.  There is no
# target codegen, no libc link into the artifact.  Production runs a bare `make headers`; we do the
# same, only forcing HOSTCC onto the from-source pivot so unifdef itself is seed-rooted.
#
# DEP MODEL (mirrors R10 exactly — the proven no-multi-gcc-coin-flip pattern):
#   * the ONLY gcc dep is R11 (the pivot) → /usr/bin/gcc is unambiguously gcc-10.4.0.  R10 sealed with
#     this shape one rung down (R9 direct, R6 transitive, no collision), so it holds here.
#   * R11's gcc SHELLS OUT to as/ld to assemble+link unifdef → R10 binutils-2.41 MUST be on PATH.
#   * unifdef links STATIC against musl → R7's clean single-writer sysroot + the -B/-L/-static wrapper.
set -ex
VERSION="${MINIMAL_ARG_VERSION:-6.12.43}"
TARBALL="linux-${VERSION}.tar.xz"   # .tar.xz -> needs xz in the closure
SRC="linux-${VERSION}"
BUILDROOT="$(pwd)"
SR=/usr/lib/musl-bedrock-1.2.5      # R7: clean single-writer musl-1.2.5 sysroot (libc.a + crt*.o + headers)

# --- infra guards (fail LOUD, not 200 lines into a cryptic "as: not found" / "stdio.h: No such file") ---
command -v gcc >/dev/null 2>&1 || { echo "linux-headers infra: gcc (R11 pivot, gcc-10.4.0) not on PATH" >&2; exit 1; }
command -v as  >/dev/null 2>&1 || { echo "linux-headers infra: as (R10 binutils-2.41) not on PATH — the pivot gcc needs it to assemble unifdef" >&2; exit 1; }
[ -f "${SR}/lib/libc.a" ] || { echo "linux-headers infra: R7 musl-1.2.5 sysroot missing at ${SR}" >&2; exit 1; }

# ============================================================================================
# HOSTCC WRAPPER — force the pivot gcc onto R7's clean musl sysroot (its baked search points at the
# coin-flip /usr).  libc-using variant (unifdef #includes <stdio.h>/<stdlib.h>/<string.h>/<ctype.h>):
# -nostdinc + EXPLICIT gcc-freestanding + musl C headers; -B/-L the sysroot + -static on link (musl is
# static-only).  Copied VERBATIM from R10's gcc-cc (only role differs).  See MEMORY
# minimal_rootfs_nondeterministic_pollution for why the deterministic sysroot wiring is mandatory.
# ============================================================================================
GI="$(gcc -print-file-name=include)"
[ -d "${GI}" ] || { echo "linux-headers infra: pivot-gcc freestanding include dir not found ('${GI}')" >&2; exit 1; }
cat > "${BUILDROOT}/gcc-cc" <<WRAP
#!/bin/sh
GI="${GI}"; SR="${SR}"
for a in "\$@"; do case "\$a" in -c|-S|-E) exec /usr/bin/gcc -nostdinc -isystem "\$GI" -isystem "\$SR/include" "\$@" ;; esac; done
exec /usr/bin/gcc -nostdinc -isystem "\$GI" -isystem "\$SR/include" -B "\$SR/lib" -L "\$SR/lib" -static "\$@"
WRAP
chmod +x "${BUILDROOT}/gcc-cc"
GCCCC="${BUILDROOT}/gcc-cc"

# --- unpack (--no-same-owner: sandbox userns; tar's default chown-to-archived-uid fails, the R8 wall) ---
tar --no-same-owner -xf "${TARBALL}"
cd "${SRC}"

# ============================================================================================
# make headers — the ONLY host compile is scripts/unifdef (HOSTCC=gcc-cc); the UAPI export is sed/sh.
# CC is set to the same wrapper defensively (config-independent; `make headers` needs no .config and
# runs no target codegen — production proves this with a bare invocation).  ARCH is left to default
# (host = x86_64 -> x86, same as production) so the emitted headers match production's set.
# ============================================================================================
make HOSTCC="${GCCCC}" CC="${GCCCC}" headers

mkdir -p "${OUTPUT_DIR}/usr"
cp -rv usr/include "${OUTPUT_DIR}/usr/"

# --- sanity gate: the load-bearing UAPI dirs must be present + non-empty (fail-shut) ---
for d in linux asm asm-generic; do
  [ -d "${OUTPUT_DIR}/usr/include/${d}" ] || { echo "LINUX-HEADERS-GATE: FAIL — usr/include/${d} missing" >&2; exit 1; }
done
[ -f "${OUTPUT_DIR}/usr/include/linux/version.h" ] || { echo "LINUX-HEADERS-GATE: FAIL — linux/version.h missing" >&2; exit 1; }
echo "LINUX-HEADERS-GATE: PASS (usr/include/{linux,asm,asm-generic} exported; linux/version.h present)" >&2
