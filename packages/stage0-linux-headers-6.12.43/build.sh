#!/bin/sh
# stage0-linux-headers-6.12.43: exports the kernel UAPI headers (usr/include/{linux,asm,asm-generic,...})
# from linux-6.12.43.tar.xz via `make headers`, with stage0-gcc-10.4.0 as HOSTCC for the one host
# tool (scripts/unifdef), linked statically against the musl-1.2.5 sysroot. The headers themselves
# are libc-independent. Output: usr/include in $OUTPUT_DIR.
set -ex
VERSION="${MINIMAL_ARG_VERSION:-6.12.43}"
TARBALL="linux-${VERSION}.tar.xz"
SRC="linux-${VERSION}"
BUILDROOT="$(pwd)"
SR=/usr/lib/musl-bedrock-1.2.5      # musl-1.2.5 sysroot (libc.a + crt*.o + headers)

# --- preconditions ---
command -v gcc >/dev/null 2>&1 || { echo "linux-headers: gcc (gcc-10.4.0) not on PATH" >&2; exit 1; }
command -v as  >/dev/null 2>&1 || { echo "linux-headers: as (binutils-2.41) not on PATH — gcc needs it to assemble unifdef" >&2; exit 1; }
[ -f "${SR}/lib/libc.a" ] || { echo "linux-headers: musl-1.2.5 sysroot missing at ${SR}" >&2; exit 1; }

# --- HOSTCC wrapper: the host gcc onto the musl-1.2.5 sysroot ---
# unifdef includes libc headers, so the sysroot include dir is added on compile; -B/-L the sysroot
# and -static on link, so nothing is taken from the merged /usr.
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

# --- unpack (--no-same-owner: the sandbox user namespace cannot chown to the archived uid) ---
tar --no-same-owner -xf "${TARBALL}"
cd "${SRC}"

# --- make headers: the only host compile is scripts/unifdef; the UAPI export is sed/sh ---
# CC is set to the same wrapper defensively; `make headers` needs no .config and runs no target
# codegen. ARCH defaults from the host (x86_64 -> x86), matching the production linux_headers package.
make HOSTCC="${GCCCC}" CC="${GCCCC}" headers

mkdir -p "${OUTPUT_DIR}/usr"
cp -rv usr/include "${OUTPUT_DIR}/usr/"

# --- sanity gate: the UAPI dirs must be present and non-empty ---
for d in linux asm asm-generic; do
  [ -d "${OUTPUT_DIR}/usr/include/${d}" ] || { echo "LINUX-HEADERS-GATE: FAIL — usr/include/${d} missing" >&2; exit 1; }
done
[ -f "${OUTPUT_DIR}/usr/include/linux/version.h" ] || { echo "LINUX-HEADERS-GATE: FAIL — linux/version.h missing" >&2; exit 1; }
echo "LINUX-HEADERS-GATE: PASS (usr/include/{linux,asm,asm-generic} exported; linux/version.h present)" >&2
