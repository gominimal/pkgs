#!/bin/bash
# ghc-8.2.2: one rung of the GHC ladder (7.6.3 -> 7.8.4 -> 7.10.3 -> 8.2.2 -> 8.6.5 -> 8.10.7 -> 9.2.8 -> 9.6.7 -> ghc).
# Builds GHC 8.2.2 from the pinned source tarball with the previous rung (/usr/lib/ghc-7.10.3) as the
# boot compiler and installs the whole compiler to /usr/lib/ghc-8.2.2 for the next rung.
# phases: P0 preconditions, P1 sysroot CC wrapper, P2 configure + make, P3 install, P4 gate.
set -eu
trap 'echo "ghc-${VERSION}: failed at line $LINENO: $BASH_COMMAND" >&2' ERR

if [ -n "$OUTPUT_DIR" ] && [ -d "$OUTPUT_DIR" ]; then
  for _e in "$OUTPUT_DIR"/* "$OUTPUT_DIR"/.[!.]* "$OUTPUT_DIR"/..?*; do [ -e "$_e" ] || [ -L "$_e" ] && rm -r "$_e"; done
fi
mkdir -p "$OUTPUT_DIR"

VERSION=8.2.2
BOOT_VERSION=7.10.3
SRC_TARBALL="ghc-${VERSION}-src.tar.xz"
SRC_SHA=bb8ec3634aa132d09faa270bbd604b82dfa61f04855655af6f9d14a9eedc05fc
BUILDROOT="$(pwd)"
PREFIX="/usr/lib/ghc-${VERSION}"
DST="${OUTPUT_DIR}${PREFIX}"
BOOT="/usr/lib/ghc-${BOOT_VERSION}/bin/ghc"
GCC_VERSION=15.2.0
SR=/usr/lib/glibc-bedrock-2.42
LOADER="${SR}/lib/ld-linux-x86-64.so.2"
JOBS="$(nproc 2>/dev/null || echo 4)"
export HOME="${BUILDROOT}/home"; mkdir -p "$HOME"
export TMPDIR="${BUILDROOT}/tmp"; mkdir -p "$TMPDIR"   # GHC writes its temporary files here   # ghc-cabal reads the user package db location
export TAR_OPTIONS=--no-same-owner   # the build system untars bundled tarballs (libffi) itself; the sandbox cannot chown

# --- P0 preconditions ---
[ "$(uname -m)" = x86_64 ] || { echo "ghc-${VERSION}: amd64 ladder rung on $(uname -m)" >&2; exit 1; }
for t in readelf gcc ld ar ranlib nm objdump strip as objcopy make perl sed grep tar xz find xargs sha256sum python3; do
  command -v "$t" >/dev/null 2>&1 || { echo "ghc-${VERSION}: '$t' not on PATH" >&2; exit 1; }
done
BGCC="$(command -v gcc)"
GCCVER="$("${BGCC}" -dumpversion 2>/dev/null || echo unknown)"
[ "${GCCVER}" = "${GCC_VERSION}" ] || { echo "ghc-${VERSION}: gcc -dumpversion='${GCCVER}', expected '${GCC_VERSION}'" >&2; exit 1; }
[ -e "${SR}/lib/libc.so" ] || { echo "ghc-${VERSION}: glibc sysroot missing at ${SR}" >&2; exit 1; }
[ -e "${LOADER}" ] || { echo "ghc-${VERSION}: glibc loader missing at ${LOADER}" >&2; exit 1; }
[ -f /usr/include/gmp.h ] || { echo "ghc-${VERSION}: gmp.h missing" >&2; exit 1; }
[ -x "${BOOT}" ] || { echo "ghc-${VERSION}: boot compiler missing at ${BOOT}" >&2; exit 1; }
BOOTVER="$("${BOOT}" --numeric-version 2>/dev/null || echo unknown)"
[ "${BOOTVER}" = "${BOOT_VERSION}" ] || { echo "ghc-${VERSION}: boot compiler reports '${BOOTVER}', expected ${BOOT_VERSION}" >&2; exit 1; }
[ -f "${SRC_TARBALL}" ] || { echo "ghc-${VERSION}: source ${SRC_TARBALL} absent" >&2; exit 1; }
echo "${SRC_SHA}  ${SRC_TARBALL}" | sha256sum -c - || { echo "ghc-${VERSION}: source sha mismatch" >&2; exit 1; }

# --- P1 CC wrapper against the versioned sysroot ---
# The sysroot's libc.so is a linker script with staging paths; regenerate it. The copy that ships
# with the compiler lives under the install prefix so the wrapper GHC records in `settings` works
# after installation.
mkfixlib() {
  mkdir -p "$1"
  sed -E "s@[^ ()]*/(libc\.so\.6|libc_nonshared\.a|ld-linux-x86-64\.so\.2)@${SR}/lib/\1@g" "${SR}/lib/libc.so" > "$1/libc.so"
  if grep -q '/build/output' "$1/libc.so"; then echo "ghc-${VERSION}: libc.so fixup failed" >&2; exit 1; fi
}
# Pre-9.0 C on a modern gcc: gnu17 (C23 reads the K&R `malloc()` declarations in utils/hp2ps as
# zero-argument functions), no PIE (static objects are linked into PIE-unaware binaries), tentative
# definitions as commons, warnings stay warnings.
CCFLAGS="-isystem ${SR}/include -isystem /usr/include -std=gnu17 -fno-pie -no-pie -fcommon -Wno-error -Wno-implicit-function-declaration -Wno-incompatible-pointer-types -Wno-int-conversion"
# The wrapper resolves gcc and its include dir when invoked, so the shipped copy also works in a
# sandbox whose gcc differs from this one.
mkwrapper() { # $1 wrapper path, $2 fixlib dir
  cat > "$1" <<WRAP
#!/bin/sh
G=\$(command -v gcc); GI=\$("\$G" -print-file-name=include)
for a in "\$@"; do case "\$a" in -c|-S|-E|-M|-MM) exec "\$G" -nostdinc -isystem "\$GI" ${CCFLAGS} "\$@" ;; esac; done
exec "\$G" -nostdinc -isystem "\$GI" ${CCFLAGS} "\$@" -L$2 -B${SR}/lib -L${SR}/lib -L/usr/lib -Wl,--dynamic-linker=${LOADER} -Wl,-rpath,${SR}/lib:/usr/lib -Wl,--build-id=none
WRAP
  chmod 0755 "$1"
}
CCDIR="${BUILDROOT}/cc"; mkdir -p "${CCDIR}"
mkfixlib "${CCDIR}/fixlib"
mkwrapper "${CCDIR}/gcc" "${CCDIR}/fixlib"
CC="${CCDIR}/gcc"
export CC   # library configures inside the tree compile their probes with it

# --- P2 configure + make ---
mkdir src && tar -xJf "${SRC_TARBALL}" -C src --strip-components=1 --no-same-owner
cd src
# ghc-pkg writes package.cache in directory-listing order; sort the .conf list so the cache is
# byte-stable across filesystems.
grep -q 'filter (".conf" `isSuffixOf`) fs' utils/ghc-pkg/Main.hs || { echo "ghc-${VERSION}: ghc-pkg conf listing changed shape" >&2; exit 1; }
sed -i 's/filter (".conf" `isSuffixOf`) fs/sort (filter (".conf" `isSuffixOf`) fs)/' utils/ghc-pkg/Main.hs
# Vanilla libraries only, no docs, no dynamic linking, no split objects.
cat > mk/build.mk <<'EOF'
GhcLibWays = v
HADDOCK_DOCS = NO
BUILD_SPHINX_HTML = NO
BUILD_SPHINX_PDF = NO
BUILD_MAN = NO
BUILD_DOCBOOK_HTML = NO
LATEX_DOCS = NO
DYNAMIC_GHC_PROGRAMS = NO
DYNAMIC_BY_DEFAULT = NO
SplitObjs = NO
SplitSections = NO
V = 0
EOF
# Stage0 utilities (hp2ps, unlit) default to the boot compiler's C compiler; use this rung's wrapper.
printf 'CC_STAGE0 = %s\n' "${CC}" >> mk/build.mk
# hp2ps declares malloc/realloc K&R-style; C23 reads `()` as no parameters.
sed -i 's/extern void\* malloc();/extern void* malloc(long unsigned int);/; s/extern void \*realloc();/extern void *realloc(void *, long unsigned int);/' utils/hp2ps/Utilities.c
./configure --prefix="${PREFIX}" GHC="${BOOT}" CC="${CC}" > ../configure.log 2>&1 \
  || { tail -30 ../configure.log >&2; echo "ghc-${VERSION}: configure failed" >&2; exit 1; }
make -j"${JOBS}" > ../make.log 2>&1 || { grep -n -B3 -m3 -E ' error:|Segmentation|internal error|\*\*\*' ../make.log | grep -v warning >&2; tail -20 ../make.log >&2; echo "ghc-${VERSION}: make failed" >&2; exit 1; }

# --- P3 install ---
make install DESTDIR="${OUTPUT_DIR}" > ../install.log 2>&1 || { tail -20 ../install.log >&2; echo "ghc-${VERSION}: install failed" >&2; exit 1; }
SETTINGS="$(find "${DST}" -type f -name settings | head -1)"
[ -n "${SETTINGS}" ] || { echo "ghc-${VERSION}: no settings file under ${DST}" >&2; exit 1; }
LIBD="$(dirname "${SETTINGS}")"
iself() { [ -f "$1" ] && [ "$(head -c 4 "$1" | tr -d '\0')" = $'\x7fELF' ]; }
GHCBIN=""; for c in "${LIBD}/bin/ghc" "${LIBD}/ghc"; do iself "$c" && GHCBIN="$c" && break; done
PKGBIN=""; for c in "${LIBD}/bin/ghc-pkg" "${LIBD}/ghc-pkg"; do iself "$c" && PKGBIN="$c" && break; done
[ -n "${GHCBIN}" ] && [ -n "${PKGBIN}" ] || { echo "ghc-${VERSION}: compiler binaries not found under ${LIBD}" >&2; exit 1; }
DB="$(find "${LIBD}" -maxdepth 1 -type d -name 'package.conf.d' | head -1)"
[ -n "${DB}" ] || { echo "ghc-${VERSION}: package db not found under ${LIBD}" >&2; exit 1; }
# a FILE symbol named ghc<pid>_N.c means a process id leaked into the output
n=$(find "${LIBD}" -type f -exec readelf -sW {} + 2>/dev/null | awk '$4=="FILE" && $8 ~ /^ghc[0-9]+_[0-9]+\.[cs]$/' | wc -l)
[ "$n" = 0 ] || { echo "ghc-${VERSION}: $n pid-named FILE symbols in the install" >&2; exit 1; }
# The shipped C compiler wrapper; `settings` names it, so later compilers configured against this
# one inherit it.
mkfixlib "${DST}/lib/glibc-fixlib"
mkwrapper "${DST}/bin/ghc-cc" "${PREFIX}/lib/glibc-fixlib"
cp "${SETTINGS}" "${BUILDROOT}/settings.build"
sed -i "s|${CCDIR}/gcc|${PREFIX}/bin/ghc-cc|g" "${SETTINGS}"
grep -q "${PREFIX}/bin/ghc-cc" "${SETTINGS}" || { echo "ghc-${VERSION}: settings does not name the shipped C compiler" >&2; exit 1; }
# text files only: ELF binaries legitimately embed the build directory
TEXTS=$(for f in "${DST}"/bin/* "${LIBD}"/settings "${DB}"/*.conf; do [ -f "$f" ] && ! iself "$f" && printf '%s\n' "$f"; done; true)
if [ -n "${TEXTS}" ] && echo "${TEXTS}" | xargs grep -l "${BUILDROOT}" 2>/dev/null | grep -q .; then
  echo "${TEXTS}" | xargs grep -l "${BUILDROOT}" >&2; echo "ghc-${VERSION}: build paths survive in the install" >&2; exit 1; fi

# --- P4 gate on the installed layout ---
# The install lives under ${DST}, not ${PREFIX}, until the package is placed: gate with a copy of
# the db pointed at ${DST} and with the build-time wrapper as the C compiler.
GATEDB="${LIBD}/gate.conf.d"; cp -r "${DB}" "${GATEDB}"   # beside the real db: ${pkgroot}-relative confs resolve
sed -i "s|${PREFIX}|${DST}|g" "${GATEDB}"/*.conf
"${PKGBIN}" --global-package-db "${GATEDB}" recache
cp "${BUILDROOT}/settings.build" "${SETTINGS}"
printf 'import Data.List\nmain = putStrLn ("GHC-GATE:" ++ show (product [1..5 :: Integer] - (2^(70::Int) - 2^(70::Int))) ++ ":" ++ show (length (nub [1..50::Int])))\n' > ../gate.hs
"${GHCBIN}" -B"${LIBD}" -no-global-package-db -package-db "${GATEDB}" -O -o ../gate ../gate.hs -outputdir ../gate.d > ../gate.log 2>&1 && OUT="$(../gate)" || { cat ../gate.log >&2; echo "ghc-${VERSION}: installed compiler failed the gate" >&2; exit 1; }
[ "$OUT" = "GHC-GATE:120:50" ] || { echo "ghc-${VERSION}: gate printed '$OUT'" >&2; exit 1; }
"${GHCBIN}" -B"${LIBD}" --info | grep -q '"Unregisterised","NO"' || { echo "ghc-${VERSION}: not a registerised compiler" >&2; exit 1; }
[ "$("${GHCBIN}" -B"${LIBD}" --numeric-version)" = "${VERSION}" ] || { echo "ghc-${VERSION}: wrong compiler version installed" >&2; exit 1; }
sed -i "s|${CCDIR}/gcc|${PREFIX}/bin/ghc-cc|g" "${SETTINGS}"
find "${GATEDB}" -delete

mkdir -p "${OUTPUT_DIR}/usr/share/ghc-${VERSION}"
cat > "${OUTPUT_DIR}/usr/share/ghc-${VERSION}/BUILDINFO" <<EOF
ghc ${VERSION}
boot: ghc ${BOOT_VERSION} (${BOOT})
source: ${SRC_TARBALL} sha256 ${SRC_SHA}
c compiler: gcc ${GCC_VERSION} via ${PREFIX}/bin/ghc-cc
sysroot: ${SR}
EOF
echo "ghc-${VERSION}: installed to ${PREFIX}"
