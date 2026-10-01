#!/bin/bash
# ghc-7.6.3: the rung where the source-only lineage (microhs -> 4.08.2 -> 5.04.3 -> 6.6.1 -> 6.10.4 -> 7.0.4) meets the
# upper ladder (7.6.3 -> 7.8.4 -> ... -> ghc). Built from the pinned source tarball with ghc-7.0.4 as the boot compiler,
# registerised (x86_64 native code generator), and installed with its own `make install` at /usr/lib/ghc-7.6.3.
# Its build system wants GNU make 3.82 (4.x evaluates its rules in another order), built here from the pinned tarball.
# phases: P0 preconditions, P1 sysroot CC wrapper + make, P2 configure + make, P3 install, P4 gate.
set -eu
trap 'echo "ghc-${VERSION}: failed at line $LINENO: $BASH_COMMAND" >&2' ERR

if [ -n "$OUTPUT_DIR" ] && [ -d "$OUTPUT_DIR" ]; then
  for _e in "$OUTPUT_DIR"/* "$OUTPUT_DIR"/.[!.]* "$OUTPUT_DIR"/..?*; do [ -e "$_e" ] || [ -L "$_e" ] && rm -r "$_e"; done
fi
mkdir -p "$OUTPUT_DIR"

VERSION=7.6.3
BOOT_VERSION=7.0.4
SRC_TARBALL="ghc-${VERSION}-src.tar.bz2"
SRC_SHA=bd43823d31f6b5d0b2ca7b74151a8f98336ab0800be85f45bb591c9c26aac998
MAKE_TARBALL=make-3.82.tar.bz2
MAKE_SHA=e2c1a73f179c40c71e2fe8abf8a8a0688b8499538512984da4a76958d0402966
BUILDROOT="$(pwd)"
PREFIX="/usr/lib/ghc-${VERSION}"
DST="${OUTPUT_DIR}${PREFIX}"
BOOTDIR="/usr/lib/ghc-${BOOT_VERSION}/bin"
GCC_VERSION=15.2.0
SR=/usr/lib/glibc-bedrock-2.42
LOADER="${SR}/lib/ld-linux-x86-64.so.2"
JOBS="$(nproc 2>/dev/null || echo 4)"
export HOME="${BUILDROOT}/home"; mkdir -p "$HOME"   # ghc-pkg reads the user package db location
export TMPDIR="${BUILDROOT}/tmp"; mkdir -p "$TMPDIR"   # GHC writes its temporary files here
export TAR_OPTIONS=--no-same-owner   # the build system untars the bundled libffi itself; the sandbox cannot chown

# --- P0 preconditions ---
[ "$(uname -m)" = x86_64 ] || { echo "ghc-${VERSION}: amd64 ladder rung on $(uname -m)" >&2; exit 1; }
for t in readelf gcc ld ar ranlib nm objdump strip as objcopy make perl sed grep tar bzip2 find xargs sha256sum; do
  command -v "$t" >/dev/null 2>&1 || { echo "ghc-${VERSION}: '$t' not on PATH" >&2; exit 1; }
done
BGCC="$(command -v gcc)"
GCCVER="$("${BGCC}" -dumpversion 2>/dev/null || echo unknown)"
[ "${GCCVER}" = "${GCC_VERSION}" ] || { echo "ghc-${VERSION}: gcc -dumpversion='${GCCVER}', expected '${GCC_VERSION}'" >&2; exit 1; }
[ -e "${SR}/lib/libc.so" ] || { echo "ghc-${VERSION}: glibc sysroot missing at ${SR}" >&2; exit 1; }
[ -e "${LOADER}" ] || { echo "ghc-${VERSION}: glibc loader missing at ${LOADER}" >&2; exit 1; }
[ -f /usr/include/gmp.h ] && [ -f /usr/include/curses.h ] || { echo "ghc-${VERSION}: gmp.h or curses.h missing" >&2; exit 1; }
[ -x "${BOOTDIR}/ghc" ] && [ -x "${BOOTDIR}/ghc-pkg" ] || { echo "ghc-${VERSION}: boot compiler missing at ${BOOTDIR}" >&2; exit 1; }
BOOTVER="$("${BOOTDIR}/ghc" --numeric-version 2>/dev/null || echo unknown)"
[ "${BOOTVER}" = "${BOOT_VERSION}" ] || { echo "ghc-${VERSION}: boot compiler reports '${BOOTVER}', expected ${BOOT_VERSION}" >&2; exit 1; }
"${BOOTDIR}/ghc-pkg" list > /dev/null || { echo "ghc-${VERSION}: boot ghc-pkg cannot list its packages" >&2; exit 1; }
for f in "${SRC_TARBALL}" "${MAKE_TARBALL}"; do [ -f "$f" ] || { echo "ghc-${VERSION}: source $f absent" >&2; exit 1; }; done
echo "${SRC_SHA}  ${SRC_TARBALL}" | sha256sum -c - || { echo "ghc-${VERSION}: source sha mismatch" >&2; exit 1; }
echo "${MAKE_SHA}  ${MAKE_TARBALL}" | sha256sum -c - || { echo "ghc-${VERSION}: make sha mismatch" >&2; exit 1; }

# --- P1 CC wrapper against the versioned sysroot, and make 3.82 ---
# The sysroot's libc.so is a linker script with staging paths; regenerate it. The copy that ships
# with the compiler lives under the install prefix so the wrapper GHC records in `settings` works
# after installation.
mkfixlib() {
  mkdir -p "$1"
  sed -E "s@[^ ()]*/(libc\.so\.6|libc_nonshared\.a|ld-linux-x86-64\.so\.2)@${SR}/lib/\1@g" "${SR}/lib/libc.so" > "$1/libc.so"
  if grep -q '/build/output' "$1/libc.so"; then echo "ghc-${VERSION}: libc.so fixup failed" >&2; exit 1; fi
}
# 2013-era C on a modern gcc: gnu99, no PIE, tentative definitions as commons, warnings stay warnings.
CCFLAGS="-isystem ${SR}/include -isystem /usr/include -std=gnu99 -fno-pie -no-pie -fcommon -fno-strict-aliasing -Wno-error -Wno-implicit-function-declaration -Wno-implicit-int -Wno-incompatible-pointer-types -Wno-int-conversion"
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
# The compiler's cpp (-pgmP) during the build: gcc -E splices backslash-newline even with -traditional, destroying
# Haskell string gaps. Protect a backslash whose next line opens with one (a \002 marker, stripped afterwards) on
# non-directive lines; the temporary copy sits beside the input so relative #includes resolve.
cat > "${CCDIR}/cpp-gap" <<EOF
#!/bin/bash
args=("\$@"); out=; in_i=-1
for ((i = 0; i < \${#args[@]}; i++)); do
  [ "\${args[\$i]}" = "-o" ] && out=\${args[\$((i + 1))]}
  [ "\${args[\$i]}" = "-x" ] && [ "\${args[\$((i + 1))]:-}" = "c" ] && in_i=\$((i + 2))
done
[ \$in_i -ge 0 ] || exec ${CC} -E -undef -traditional "\$@"
in=\${args[\$in_i]}; tmp=\$(mktemp "\$(dirname "\$in")/.cppgap.XXXXXX")
perl -e '@l = <>; \$d = 0; for \$i (0 .. \$#l) { \$_ = \$l[\$i]; \$d = 1 if /^\\s*#/; if (\$d) { \$d = /\\\\[ \\t]*\\r?\\n\$/ ? 1 : 0 } elsif (\$i < \$#l && \$l[\$i + 1] =~ /^\\s*\\\\/) { s/\\\\([ \\t]*\\r?\\n)\$/\\\\\\002\$1/ } print }' "\$in" > "\$tmp"
args[\$in_i]=\$tmp
${CC} -E -undef -traditional "\${args[@]}"; rc=\$?
[ -n "\$out" ] && [ -f "\$out" ] && T="\$tmp" I="\$in" perl -pi -e 's/\\002//g; s/\\Q\$ENV{T}\\E/\$ENV{I}/g' "\$out"
rm -f "\$tmp"; exit \$rc
EOF
chmod 0755 "${CCDIR}/cpp-gap"
# make 3.82: -fcommon (make.h defines stack_limit in every object); the bundled glob calls glibc-internal
# __alloca/__stat, which glibc no longer exports. glob.c stays as shipped.
mkdir -p "${BUILDROOT}/make-src"; tar -xjf "${MAKE_TARBALL}" -C "${BUILDROOT}/make-src" --strip-components=1
( cd "${BUILDROOT}/make-src" && CC="${CC} -fcommon" CPPFLAGS="-D__alloca=__builtin_alloca -D__stat=stat" ./configure --prefix="${BUILDROOT}/make382" > configure.log 2>&1 && make > make.log 2>&1 && make install > install.log 2>&1 ) \
  || { tail -10 "${BUILDROOT}/make-src/make.log" >&2; echo "ghc-${VERSION}: make 3.82 did not build" >&2; exit 1; }
MK="${BUILDROOT}/make382/bin/make"
"${MK}" --version | grep -q 'GNU Make 3.82' || { echo "ghc-${VERSION}: wrong make" >&2; exit 1; }

# --- P2 configure + make ---
mkdir src && tar -xjf "${SRC_TARBALL}" -C src --strip-components=1 --no-same-owner
cd src
# ghc-pkg writes package.cache in directory-listing order; sort the .conf list so the cache is
# byte-stable across filesystems.
grep -q 'filter (".conf" `isSuffixOf`) fs' utils/ghc-pkg/Main.hs || { echo "ghc-${VERSION}: ghc-pkg conf listing changed shape" >&2; exit 1; }
sed -i 's/filter (".conf" `isSuffixOf`) fs/sort (filter (".conf" `isSuffixOf`) fs)/' utils/ghc-pkg/Main.hs
# GHC names its temp C files ghc<pid>_N.c and gcc records that name as the object's FILE symbol; every
# executable GHC links gets one. Use the fixed prefix 7.10.2 adopted (upstream 7a82b776).
grep -q 'findTempName (d </> "ghc" ++ show x ++ "_")' compiler/main/SysTools.lhs || { echo "ghc-${VERSION}: temp-name code changed shape" >&2; exit 1; }
perl -0pi -e 's/\n( *)x <- getProcessID\n *findTempName \(d <\/> "ghc" \+\+ show x \+\+ "_"\)/\n$1findTempName (d <\/> "ghc_")/' compiler/main/SysTools.lhs
grep -q 'findTempName (d </> "ghc_")' compiler/main/SysTools.lhs || { echo "ghc-${VERSION}: temp-name patch did not apply" >&2; exit 1; }
# GMP >= 6.2 initialises an mpz lazily (no limb allocation); integer-gmp recovers the result ByteArray# from the limb
# pointer unconditionally, so a zero-valued Integer would point into libgmp's data: mpz_init2(x, 64) allocates a limb.
GW=libraries/integer-gmp/cbits/gmp-wrappers.cmm
sed -i 's/__gmpz_init(\([^)]*\))/__gmpz_init2(\1, 64)/g' "$GW"
grep -q '__gmpz_init2(' "$GW" && ! grep -q '__gmpz_init(' "$GW" || { echo "ghc-${VERSION}: gmp-wrappers fix did not apply" >&2; exit 1; }
# Vanilla libraries only, no docs, no dynamic linking, no split objects; the threaded RTS way for the
# programs the next rung's build runs. The boot's cpp mangles string gaps, hence -pgmP for every stage.
cat > mk/build.mk <<EOF
HADDOCK_DOCS        = NO
BUILD_DOCBOOK_HTML  = NO
BUILD_DOCBOOK_PS    = NO
BUILD_DOCBOOK_PDF   = NO
GhcLibWays          = v
SplitObjs           = NO
GhcWithInterpreter  = NO
GhcRTSWays          = thr
DYNAMIC_BY_DEFAULT  = NO
DYNAMIC_GHC_PROGRAMS = NO
V                   = 0
SRC_HC_OPTS         = -O -H64m -pgmP ${CCDIR}/cpp-gap
GhcStage1HcOpts     = -O
GhcStage2HcOpts     = -O
GhcLibHcOpts        = -O
EOF
CC="${CC}" ./configure --prefix="${PREFIX}" --with-ghc="${BOOTDIR}/ghc" --with-ghc-pkg="${BOOTDIR}/ghc-pkg" --with-gcc="${CC}" > ../configure.log 2>&1 \
  || { tail -30 ../configure.log >&2; echo "ghc-${VERSION}: configure failed" >&2; exit 1; }
"${MK}" -j"${JOBS}" > ../make.log 2>&1 || { grep -n -B3 -m3 -E ' error:|Segmentation|internal error|\*\*\*' ../make.log | grep -v warning >&2; tail -20 ../make.log >&2; echo "ghc-${VERSION}: make failed" >&2; exit 1; }
[ -x inplace/bin/ghc-stage2 ] || { echo "ghc-${VERSION}: inplace/bin/ghc-stage2 missing" >&2; exit 1; }

# --- P3 install ---
"${MK}" install DESTDIR="${OUTPUT_DIR}" > ../install.log 2>&1 || { tail -20 ../install.log >&2; echo "ghc-${VERSION}: install failed" >&2; exit 1; }
SETTINGS="$(find "${DST}" -type f -name settings | head -1)"
[ -n "${SETTINGS}" ] || { echo "ghc-${VERSION}: no settings file under ${DST}" >&2; exit 1; }
LIBD="$(dirname "${SETTINGS}")"
iself() { [ -f "$1" ] && [ "$(head -c 4 "$1" | tr -d '\0')" = $'\x7fELF' ]; }
GHCBIN=""; for c in "${LIBD}/bin/ghc" "${LIBD}/ghc"; do iself "$c" && GHCBIN="$c" && break; done
PKGBIN=""; for c in "${LIBD}/bin/ghc-pkg" "${LIBD}/ghc-pkg"; do iself "$c" && PKGBIN="$c" && break; done
[ -n "${GHCBIN}" ] && [ -n "${PKGBIN}" ] || { echo "ghc-${VERSION}: compiler binaries not found under ${LIBD}" >&2; exit 1; }
DB="$(find "${LIBD}" -maxdepth 1 -type d -name 'package.conf.d' | head -1)"
[ -n "${DB}" ] || { echo "ghc-${VERSION}: package db not found under ${LIBD}" >&2; exit 1; }
# unlit and hp2ps are C programs compiled through GHC, which hands gcc a temp file named ghc<pid>_N.c; that
# name lands in the symbol table as the FILE symbol. Strip them so the binaries do not depend on the pid.
find "${DST}" -type f \( -name unlit -o -name hp2ps \) -exec strip {} + 2>/dev/null || true
# a FILE symbol named ghc<pid>_N.c means a process id leaked into the output
n=$(find "${DST}" -type f -exec readelf -sW {} + 2>/dev/null | awk '$4=="FILE" && $8 ~ /^ghc[0-9]+_[0-9]+\.[cs]$/' | wc -l)
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
GATEDB="${LIBD}/gate.conf.d"; cp -r "${DB}" "${GATEDB}"
sed -i "s|${PREFIX}|${DST}|g" "${GATEDB}"/*.conf
"${PKGBIN}" --global-package-db "${GATEDB}" recache
cp "${BUILDROOT}/settings.build" "${SETTINGS}"
printf 'import Data.List\nmain = putStrLn ("GHC-GATE:" ++ show (product [1..5 :: Integer] - (2^(70::Int) - 2^(70::Int))) ++ ":" ++ show (length (nub [1..50::Int])))\n' > ../gate.hs
"${GHCBIN}" -B"${LIBD}" -no-global-package-db -package-db "${GATEDB}" -O -o ../gate ../gate.hs -outputdir ../gate.d > ../gate.log 2>&1 && OUT="$(../gate)" || { cat ../gate.log >&2; echo "ghc-${VERSION}: installed compiler failed the gate" >&2; exit 1; }
[ "$OUT" = "GHC-GATE:120:50" ] || { echo "ghc-${VERSION}: gate printed '$OUT'" >&2; exit 1; }
# zero-valued Integers through the GMP path (the lazy-init bug's symptom was a crash here)
printf 'main :: IO ()\nmain = do\n  let zs = [ (2 ^ (100 :: Int) + toInteger i) - (2 ^ (100 :: Int) + toInteger i) | i <- [1 .. 300000 :: Int] ]\n  print (sum zs, length (show (product [1 .. 3000 :: Integer])))\n' > ../gmpzero.hs
"${GHCBIN}" -B"${LIBD}" -no-global-package-db -package-db "${GATEDB}" -O -o ../gmpzero ../gmpzero.hs -outputdir ../gmpzero.d > ../gmpzero.log 2>&1 && OUT="$(../gmpzero)" || { cat ../gmpzero.log >&2; echo "ghc-${VERSION}: gmpzero failed" >&2; exit 1; }
[ "$OUT" = "(0,9131)" ] || { echo "ghc-${VERSION}: gmpzero printed '$OUT'" >&2; exit 1; }
INFO="$("${GHCBIN}" -B"${LIBD}" --info)"   # captured: grep -q closing the pipe early would fail the pipeline
echo "${INFO}" | grep -q '"Unregisterised","NO"' || { echo "ghc-${VERSION}: not a registerised compiler" >&2; exit 1; }
[ "$("${GHCBIN}" -B"${LIBD}" --numeric-version)" = "${VERSION}" ] || { echo "ghc-${VERSION}: wrong compiler version installed" >&2; exit 1; }
sed -i "s|${CCDIR}/gcc|${PREFIX}/bin/ghc-cc|g" "${SETTINGS}"
find "${GATEDB}" -delete

mkdir -p "${OUTPUT_DIR}/usr/share/ghc-${VERSION}"
cat > "${OUTPUT_DIR}/usr/share/ghc-${VERSION}/BUILDINFO" <<EOF
ghc ${VERSION} (registerised x86_64, booted by ghc-${BOOT_VERSION})
source: ${SRC_TARBALL} sha256 ${SRC_SHA}
make: ${MAKE_TARBALL} sha256 ${MAKE_SHA}
c compiler: gcc ${GCC_VERSION} via ${PREFIX}/bin/ghc-cc
sysroot: ${SR}
EOF
