#!/bin/bash
# ghc-9.6.7: one rung of the GHC ladder (7.6.3 -> 7.8.4 -> 7.10.3 -> 8.2.2 -> 8.6.5 -> 8.10.7 -> 9.2.8 -> 9.6.7 -> ghc).
# Builds GHC 9.6.7 with Hadrian from the pinned source tarball, the previous rung (/usr/lib/ghc-9.2.8)
# as the boot compiler and the offline Hadrian bootstrap sources, and installs the whole compiler to
# /usr/lib/ghc-9.6.7 for the next rung.
# phases: P0 preconditions, P1 sysroot CC wrapper, P2 bootstrap Hadrian, P3 configure + build,
# P4 install, P5 gate.
set -eu
trap 'echo "ghc-${VERSION}: failed at line $LINENO: $BASH_COMMAND" >&2' ERR

if [ -n "$OUTPUT_DIR" ] && [ -d "$OUTPUT_DIR" ]; then
  for _e in "$OUTPUT_DIR"/* "$OUTPUT_DIR"/.[!.]* "$OUTPUT_DIR"/..?*; do [ -e "$_e" ] || [ -L "$_e" ] && rm -r "$_e"; done
fi
mkdir -p "$OUTPUT_DIR"

VERSION=9.6.7
BOOT_VERSION=9.2.8
SRC_TARBALL="ghc-${VERSION}-src.tar.xz"
SRC_SHA=d053bf6ce1d588a75cfe8c9316269486e9d8fb89dcdf6fd92836fa2e3df61305
HBS_TARBALL="hadrian-bootstrap-sources-9.2.5.tar.gz"
HBS_SHA=a081cd21d2917855e5447ef2433a3b7a4d87ddc8229f6e98fde9f51a693bff5e
BUILDROOT="$(pwd)"
PREFIX="/usr/lib/ghc-${VERSION}"
DST="${OUTPUT_DIR}${PREFIX}"
BOOT="/usr/lib/ghc-${BOOT_VERSION}/bin/ghc"
BOOT_PKG="/usr/lib/ghc-${BOOT_VERSION}/bin/ghc-pkg"
GCC_VERSION=15.2.0
SR=/usr/lib/glibc-bedrock-2.42
LOADER="${SR}/lib/ld-linux-x86-64.so.2"
JOBS="$(nproc 2>/dev/null || echo 4)"
export HOME="${BUILDROOT}/home"; mkdir -p "$HOME"
export TMPDIR="${BUILDROOT}/tmp"; mkdir -p "$TMPDIR"   # GHC writes its temporary files here
export TAR_OPTIONS=--no-same-owner   # the build system untars bundled tarballs (libffi) itself; the sandbox cannot chown

# --- P0 preconditions ---
[ "$(uname -m)" = x86_64 ] || { echo "ghc-${VERSION}: amd64 ladder rung on $(uname -m)" >&2; exit 1; }
for t in gcc ld ar ranlib nm objdump strip as objcopy make perl python3 sed grep tar xz gzip find xargs sha256sum; do
  command -v "$t" >/dev/null 2>&1 || { echo "ghc-${VERSION}: '$t' not on PATH" >&2; exit 1; }
done
BGCC="$(command -v gcc)"
GCCVER="$("${BGCC}" -dumpversion 2>/dev/null || echo unknown)"
[ "${GCCVER}" = "${GCC_VERSION}" ] || { echo "ghc-${VERSION}: gcc -dumpversion='${GCCVER}', expected '${GCC_VERSION}'" >&2; exit 1; }
[ -e "${SR}/lib/libc.so" ] || { echo "ghc-${VERSION}: glibc sysroot missing at ${SR}" >&2; exit 1; }
[ -e "${LOADER}" ] || { echo "ghc-${VERSION}: glibc loader missing at ${LOADER}" >&2; exit 1; }
[ -f /usr/include/gmp.h ] || { echo "ghc-${VERSION}: gmp.h missing" >&2; exit 1; }
[ -x "${BOOT}" ] && [ -x "${BOOT_PKG}" ] || { echo "ghc-${VERSION}: boot compiler missing at ${BOOT}" >&2; exit 1; }
BOOTVER="$("${BOOT}" --numeric-version 2>/dev/null || echo unknown)"
[ "${BOOTVER}" = "${BOOT_VERSION}" ] || { echo "ghc-${VERSION}: boot compiler reports '${BOOTVER}', expected ${BOOT_VERSION}" >&2; exit 1; }
for f in "${SRC_TARBALL}" "${HBS_TARBALL}"; do [ -f "$f" ] || { echo "ghc-${VERSION}: $f absent" >&2; exit 1; }; done
echo "${SRC_SHA}  ${SRC_TARBALL}" | sha256sum -c - || { echo "ghc-${VERSION}: source sha mismatch" >&2; exit 1; }
echo "${HBS_SHA}  ${HBS_TARBALL}" | sha256sum -c - || { echo "ghc-${VERSION}: hadrian bootstrap sources sha mismatch" >&2; exit 1; }

# --- P1 CC wrapper against the versioned sysroot ---
# The sysroot's libc.so is a linker script with staging paths; regenerate it. The copy that ships
# with the compiler lives under the install prefix so the wrapper GHC records in `settings` works
# after installation.
mkfixlib() {
  mkdir -p "$1"
  sed -E "s@[^ ()]*/(libc\.so\.6|libc_nonshared\.a|ld-linux-x86-64\.so\.2)@${SR}/lib/\1@g" "${SR}/lib/libc.so" > "$1/libc.so"
  if grep -q '/build/output' "$1/libc.so"; then echo "ghc-${VERSION}: libc.so fixup failed" >&2; exit 1; fi
}
CCFLAGS="-isystem ${SR}/include -isystem /usr/include"
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

# --- P2 bootstrap Hadrian ---
mkdir src && tar -xJf "${SRC_TARBALL}" -C src --strip-components=1 --no-same-owner
cd src
# The bootstrap sources tarball carries a plan-bootstrap.json whose `builtin` entries pin the
# versions of the packages bundled with the boot compiler it was generated for (9.2.5); bootstrap.py
# checks those against the boot's ghc-pkg exactly. Rewrite them to what this boot ships and repack.
mkdir -p ../hbs && tar -xzf "../${HBS_TARBALL}" -C ../hbs --no-same-owner
python3 - ../hbs/plan-bootstrap.json "${BOOT_PKG}" <<'PY'
import json, subprocess, sys
plan, ghcpkg = sys.argv[1], sys.argv[2]
d = json.load(open(plan)); n = 0
for b in d.get('builtin', []):
    v = subprocess.run([ghcpkg, '--simple-output', 'field', b['package'], 'version'], capture_output=True, text=True).stdout.split()
    if v and v[-1] != b['version']:
        b['version'] = v[-1]; n += 1
json.dump(d, open(plan, 'w'), indent=1)
print(n, 'builtin versions rewritten')
PY
tar -czf ../hbs-boot.tar.gz -C ../hbs .
# configure only checks that a cabal exists; sphinx is only probed for docs, which are off.
STUB="${BUILDROOT}/stub-bin"; mkdir -p "${STUB}"
printf '#!/bin/sh\nexit 0\n' > "${STUB}/cabal"; chmod +x "${STUB}/cabal"
export PATH="${STUB}:${PWD}/_build/bin:${PATH}"
python3 hadrian/bootstrap/bootstrap.py -w "${BOOT}" --bootstrap-sources ../hbs-boot.tar.gz --no-archive > ../hadrian-bootstrap.log 2>&1 \
  || { tail -30 ../hadrian-bootstrap.log >&2; echo "ghc-${VERSION}: hadrian bootstrap failed" >&2; exit 1; }
HADRIAN="${PWD}/_build/bin/hadrian"
[ -x "${HADRIAN}" ] || { echo "ghc-${VERSION}: no hadrian binary at ${HADRIAN} after bootstrap" >&2; exit 1; }

# --- P3 configure + build ---
./configure --prefix="${PREFIX}" GHC="${BOOT}" CC="${CC}" > ../configure.log 2>&1 \
  || { tail -30 ../configure.log >&2; echo "ghc-${VERSION}: configure failed" >&2; exit 1; }
# quick = -O0 compiler, -O1 libraries: enough for a boot compiler. binary-dist-dir with docs off
# leaves haddock out (the boot ships no xhtml); the bindist's own configure/make install then lays
# the tree out, configured against the same C wrapper so `settings` records it.
"${HADRIAN}" -j"${JOBS}" --flavour=quick --docs=none binary-dist-dir > ../make.log 2>&1 || { grep -n -m5 -iE 'error|Segmentation' ../make.log >&2; tail -20 ../make.log >&2; echo "ghc-${VERSION}: hadrian build failed" >&2; exit 1; }

# --- P4 install ---
BD="$(ls -d _build/bindist/ghc-* | head -1)"
[ -n "${BD}" ] && [ -x "${BD}/configure" ] || { echo "ghc-${VERSION}: no bindist under _build/bindist" >&2; exit 1; }
( cd "${BD}" && ./configure --prefix="${PREFIX}" CC="${CC}" > "${BUILDROOT}/bindist-configure.log" 2>&1 && make install DESTDIR="${OUTPUT_DIR}" > "${BUILDROOT}/install.log" 2>&1 ) \
  || { tail -20 "${BUILDROOT}/bindist-configure.log" "${BUILDROOT}/install.log" >&2; echo "ghc-${VERSION}: bindist install failed" >&2; exit 1; }
SETTINGS="$(find "${DST}" -type f -name settings | head -1)"
[ -n "${SETTINGS}" ] || { echo "ghc-${VERSION}: no settings file under ${DST}" >&2; exit 1; }
LIBD="$(dirname "${SETTINGS}")"
iself() { [ -f "$1" ] && [ "$(head -c 4 "$1" | tr -d '\0')" = $'\x7fELF' ]; }
GHCBIN=""; for c in "${LIBD}/bin/ghc" "${LIBD}/../bin/ghc" "${LIBD}/../bin/ghc-${VERSION}"; do iself "$c" && GHCBIN="$c" && break; done
PKGBIN=""; for c in "${LIBD}/bin/ghc-pkg" "${LIBD}/../bin/ghc-pkg" "${LIBD}/../bin/ghc-pkg-${VERSION}"; do iself "$c" && PKGBIN="$c" && break; done
[ -n "${GHCBIN}" ] && [ -n "${PKGBIN}" ] || { echo "ghc-${VERSION}: compiler binaries not found near ${LIBD}" >&2; exit 1; }
DB="$(find "${LIBD}" -maxdepth 1 -type d -name 'package.conf.d' | head -1)"
[ -n "${DB}" ] || { echo "ghc-${VERSION}: package db not found under ${LIBD}" >&2; exit 1; }
# The shipped C compiler wrapper; `settings` names it, so later compilers configured against this
# one inherit it.
mkfixlib "${DST}/lib/glibc-fixlib"
mkwrapper "${DST}/bin/ghc-cc" "${PREFIX}/lib/glibc-fixlib"
cp "${SETTINGS}" "${BUILDROOT}/settings.build"
sed -i "s|${CCDIR}/gcc|${PREFIX}/bin/ghc-cc|g" "${SETTINGS}"
grep -q "${PREFIX}/bin/ghc-cc" "${SETTINGS}" || { echo "ghc-${VERSION}: settings does not name the shipped C compiler" >&2; exit 1; }
# text files only: ELF binaries legitimately embed the build directory
TEXTS=$(for f in "${DST}"/bin/* "${SETTINGS}" "${DB}"/*.conf; do [ -f "$f" ] && ! iself "$f" && printf '%s\n' "$f"; done; true)
if [ -n "${TEXTS}" ] && echo "${TEXTS}" | xargs grep -l "${BUILDROOT}" 2>/dev/null | grep -q .; then
  echo "${TEXTS}" | xargs grep -l "${BUILDROOT}" >&2; echo "ghc-${VERSION}: build paths survive in the install" >&2; exit 1; fi

# --- P5 gate on the installed layout ---
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
ghc ${VERSION} (hadrian, flavour quick)
boot: ghc ${BOOT_VERSION} (${BOOT})
source: ${SRC_TARBALL} sha256 ${SRC_SHA}
hadrian bootstrap sources: ${HBS_TARBALL} sha256 ${HBS_SHA}
c compiler: gcc ${GCC_VERSION} via ${PREFIX}/bin/ghc-cc
sysroot: ${SR}
EOF
echo "ghc-${VERSION}: installed to ${PREFIX}"
