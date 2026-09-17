#!/bin/bash
# ghc-7.6.3: the root of the GHC ladder. No Haskell compiler runs here: the bundle holds the
# unregisterised C (.hc) that ghc-7.6.3's own stage1 emits for its libraries, compiler and ghc-pkg,
# and the source tree's --enable-hc-boot mode compiles that C with gcc into a working ghc-7.6.3.
# phases: P0 preconditions, P1 sysroot CC wrapper, P2 target tree + configure, P3 unpack the bundle
# into the tree and fill the gaps hc-boot mode leaves, P4 make, P5 install (relocate the in-tree
# package db), P6 gate.
set -eu
trap 'echo "ghc-${VERSION}: failed at line $LINENO: $BASH_COMMAND" >&2' ERR

if [ -n "$OUTPUT_DIR" ] && [ -d "$OUTPUT_DIR" ]; then
  for _e in "$OUTPUT_DIR"/* "$OUTPUT_DIR"/.[!.]* "$OUTPUT_DIR"/..?*; do [ -e "$_e" ] || [ -L "$_e" ] && rm -r "$_e"; done
fi
mkdir -p "$OUTPUT_DIR"

VERSION=7.6.3
SRC_TARBALL="ghc-${VERSION}-src.tar.bz2"
SRC_SHA=bd43823d31f6b5d0b2ca7b74151a8f98336ab0800be85f45bb591c9c26aac998
BUNDLE="ghc-${VERSION}-hcboot-bundle-v4.tar.gz"
BUNDLE_SHA=71791f12773b03b2b0e4b9eaba753b5e92f738549b968e661d4bacb2853c8f39
BUILDROOT="$(pwd)"
PREFIX="/usr/lib/ghc-${VERSION}"
DST="${OUTPUT_DIR}${PREFIX}"
TOPDIR="${PREFIX}/lib/ghc-${VERSION}"
GCC_VERSION=15.2.0
SR=/usr/lib/glibc-bedrock-2.42
LOADER="${SR}/lib/ld-linux-x86-64.so.2"
TRIPLE=x86_64-unknown-linux-gnu
JOBS="$(nproc 2>/dev/null || echo 4)"
export HOME="${BUILDROOT}/home"; mkdir -p "$HOME"

# --- P0 preconditions ---
[ "$(uname -m)" = x86_64 ] || { echo "ghc-${VERSION}: the .hc bundle is x86_64 code" >&2; exit 1; }
for t in gcc ld ar ranlib nm objdump strip as objcopy make perl sed grep tar bzip2 gzip find xargs sha256sum cmp; do
  command -v "$t" >/dev/null 2>&1 || { echo "ghc-${VERSION}: '$t' not on PATH" >&2; exit 1; }
done
BGCC="$(command -v gcc)"
GCCVER="$("${BGCC}" -dumpversion 2>/dev/null || echo unknown)"
[ "${GCCVER}" = "${GCC_VERSION}" ] || { echo "ghc-${VERSION}: gcc -dumpversion='${GCCVER}', expected '${GCC_VERSION}'" >&2; exit 1; }
[ -e "${SR}/lib/libc.so" ] || { echo "ghc-${VERSION}: glibc sysroot missing at ${SR}" >&2; exit 1; }
[ -e "${LOADER}" ] || { echo "ghc-${VERSION}: glibc loader missing at ${LOADER}" >&2; exit 1; }
[ -f /usr/include/gmp.h ] || { echo "ghc-${VERSION}: gmp.h missing" >&2; exit 1; }
[ -f "${SRC_TARBALL}" ] || { echo "ghc-${VERSION}: source ${SRC_TARBALL} absent" >&2; exit 1; }
[ -f "${BUNDLE}" ] || { echo "ghc-${VERSION}: bundle ${BUNDLE} absent" >&2; exit 1; }
echo "${SRC_SHA}  ${SRC_TARBALL}" | sha256sum -c - || { echo "ghc-${VERSION}: source sha mismatch" >&2; exit 1; }
echo "${BUNDLE_SHA}  ${BUNDLE}" | sha256sum -c - || { echo "ghc-${VERSION}: bundle sha mismatch" >&2; exit 1; }

# --- P1 CC wrapper against the versioned sysroot ---
# The sysroot's libc.so is a linker script with staging paths; regenerate it. The copy that ships
# with the compiler lives under the install prefix so the wrapper GHC records in `settings` works
# after installation.
mkfixlib() {
  mkdir -p "$1"
  sed -E "s@[^ ()]*/(libc\.so\.6|libc_nonshared\.a|ld-linux-x86-64\.so\.2)@${SR}/lib/\1@g" "${SR}/lib/libc.so" > "$1/libc.so"
  if grep -q '/build/output' "$1/libc.so"; then echo "ghc-${VERSION}: libc.so fixup failed" >&2; exit 1; fi
}
# 2013-era C on a modern gcc: gnu99, no PIE, tentative definitions as commons, warnings stay warnings.
CCFLAGS="-isystem ${SR}/include -isystem /usr/include -std=gnu99 -fno-pie -no-pie -fcommon -Wno-error -Wno-implicit-function-declaration -Wno-implicit-int -Wno-incompatible-pointer-types -Wno-int-conversion"
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
# configure hunts for ${TRIPLE}-prefixed tools once --build/--host/--target are given. They live in
# their own PATH entry so the wrapper's `command -v gcc` keeps resolving to the real compiler.
XTOOLS="${BUILDROOT}/xtools"; mkdir -p "${XTOOLS}"
for t in ld ar ranlib nm objdump strip as objcopy; do ln -sf "$(command -v $t)" "${XTOOLS}/${TRIPLE}-${t}"; done
ln -sf "${CCDIR}/gcc" "${XTOOLS}/${TRIPLE}-gcc"
export PATH="${XTOOLS}:${PATH}"
CC="${CCDIR}/gcc"; LD="$(command -v ld)"; AR="$(command -v ar)"

# --- P2 target tree ---
mkdir T && tar -xjf "${SRC_TARBALL}" -C T --strip-components=1 --no-same-owner
cd T
# GhcUnregisterised must be set before any generated header exists: with it unset,
# TABLES_NEXT_TO_CODE=1 leaks into DerivedConstants.h and the unregisterised RTS cannot run.
# configure normally copies the boot compiler's C toolchain into the *_STAGE0 variables; with no
# boot compiler they would be empty.
cat > mk/build.mk <<EOF
CC_STAGE0 = ${CC}
CC = ${CC}
WhatGccIsCalled = ${CC}
LD_STAGE0 = ${LD}
LD = ${LD}
AR_STAGE0 = ${AR}
AR = ${AR}
GhcUnregisterised = YES
GhcWithNativeCodeGen = NO
GhcWithInterpreter = NO
GhcWithSMP = NO
GhcEnableTablesNextToCode = NO
SplitObjs = NO
HADDOCK_DOCS = NO
BUILD_DOCBOOK_HTML = NO
LATEX_DOCS = NO
GhcLibWays = v
GhcRTSWays =
DYNAMIC_BY_DEFAULT = NO
DYNAMIC_GHC_PROGRAMS = NO
EOF
# configure builds utils/ghc-pwd with the boot compiler and aborts without one; ghc-pwd only prints
# the working directory, so /bin/pwd stands in (re-placed after configure's own rm/mkdir of the
# dist-boot dir). The matching-ghc-pkg check has nothing to match either.
sed -i 's|as_fn_error $? "Building ghc-pwd failed"|: hc-boot-skip-ghc-pwd|' configure
sed -i 's|as_fn_error $? "Cannot find matching ghc-pkg"|: hc-boot-skip-ghc-pkg|' configure
sed -i 's|^\([[:space:]]*\)mkdir  *utils/ghc-pwd/dist-boot[[:space:]]*$|&; cp /bin/pwd utils/ghc-pwd/dist-boot/ghc-pwd|' configure
grep -q 'cp /bin/pwd utils/ghc-pwd' configure || { echo "ghc-${VERSION}: ghc-pwd hook did not apply" >&2; exit 1; }
# rules/build-prog.mk's hc-boot link branch carries one stray double quote.
perl -pi -e 's/(\$\$\(call cmd,\$1_\$2_CC\))"( -o)/$1$2/g; s/"(\$\$\(call cmd,\$1_\$2_CC\))""( -o)/"$1"$2/g' rules/build-prog.mk
# Without a boot compiler configure cannot infer the platform from `ghc --info`.
CC="${CC}" ./configure --enable-hc-boot --with-gcc="${CC}" --build=${TRIPLE} --host=${TRIPLE} --target=${TRIPLE} --prefix="${PREFIX}" > ../configure.log 2>&1 \
  || { tail -30 ../configure.log >&2; echo "ghc-${VERSION}: configure failed" >&2; exit 1; }
grep -q 'Bootstrapping from HC files' ../configure.log || { echo "ghc-${VERSION}: configure did not enter hc-boot mode" >&2; exit 1; }
( cd libraries/integer-gmp && ./configure > /dev/null 2>&1 )
make CC_STAGE0="${CC}" CC="${CC}" bootstrapping-files > ../bootstrapping-files.log 2>&1 \
  || { tail -30 ../bootstrapping-files.log >&2; echo "ghc-${VERSION}: bootstrapping-files failed" >&2; exit 1; }
grep -q 'TABLES_NEXT_TO_CODE 1' includes/ghcautoconf.h && { echo "ghc-${VERSION}: TABLES_NEXT_TO_CODE leaked into the unregisterised build" >&2; exit 1; }

# --- P3 the bundle ---
# Layout: <dir>/dist*/build/*.hc + *.hi for every library and the compiler, package-data.mk and
# the inplace package db, the compiler's generated sources, and hcstubs/ = the C sides of `capi`
# foreign imports (GHC 7.x writes them only as temporary files).
tar -xzf "../${BUNDLE}"
[ "$(cat bundle.version)" = 4 ] || { echo "ghc-${VERSION}: bundle version $(cat bundle.version), expected 4" >&2; exit 1; }
# ghc-cabal recorded the emitting tree's absolute paths; repoint them here.
EMIT_ROOT="$(sed -n 's|^import-dirs: *\(.*\)/libraries/base/dist-install/build$|\1|p' inplace/lib/package.conf.d/base-*.conf | head -1)"
[ -n "${EMIT_ROOT}" ] || { echo "ghc-${VERSION}: cannot read the emitting tree's root from the bundle's base.conf" >&2; exit 1; }
if [ "${EMIT_ROOT}" != "${BUILDROOT}/T" ]; then
  grep -rl "${EMIT_ROOT}/" --include=package-data.mk --include='package.conf*' --include='*.conf' --include='*.mk' . | xargs -r sed -i "s|${EMIT_ROOT}/|${BUILDROOT}/T/|g"
  rm -f inplace/lib/package.conf.d/package.cache   # binary copy of the old paths; regenerated once ghc-pkg exists
  [ "$(grep -rl "${EMIT_ROOT}/" . | wc -l)" = 0 ] || { echo "ghc-${VERSION}: emitting-tree paths survive in the bundle" >&2; exit 1; }
fi
# The emitting tree builds the compiler as stage2 and the boot libraries twice (dist-boot by its
# boot compiler, dist-install as .hc); an hc-boot tree wants the compiler as stage1 and the boot
# libraries from dist-boot. Mirror the .hc/.hi/generated sources into the expected dist dirs.
if [ -d compiler/stage2/build ]; then mkdir -p compiler/stage1/build
  ( cd compiler/stage2/build && find . \( -name '*.hc' -o -name '*.hi' -o -name '*.hs' -o -name '*.hs-incl' \) -exec cp --parents -n {} ../../stage1/build/ \; )
fi
for db in $(find . -type d -name dist-boot); do lib=${db%/dist-boot}; [ -d "$lib/dist-install/build" ] || continue; mkdir -p "$db/build"
  ( cd "$lib/dist-install/build" && find . \( -name '*.hc' -o -name '*.hi' -o -name '*.hs' -o -name '*_hsc.[ch]' \) -exec cp --parents -n {} ../../dist-boot/build/ \; ); done
# -keep-hc-files drops autogen modules' .hc next to their source; the only .hc rules look in build/.
for f in $(find . -path '*/build/autogen/*.hc'); do t="$(dirname "$(dirname "$f")")/$(basename "$f")"; [ -e "$t" ] || cp "$f" "$t"; done
# .depend files come from `ghc -M`; the .hc -> .o rules need no module order, so stubs that only
# declare the *_EXISTS variables satisfy rules/build-dependencies.mk. Every (dir, distdir) pair
# the ghc.mk files name gets both spellings.
stubdeps() { mkdir -p "$1/build"; dir=${1%/*}; dist=${1##*/}
  for f in .depend-v.haskell .depend.haskell; do [ -f "$1/build/$f" ] || echo "${dir}_${dist}_depfile_haskell_EXISTS = YES" > "$1/build/$f"; done
  for f in .depend-v.c_asm .depend.c_asm; do [ -f "$1/build/$f" ] || echo "${dir}_${dist}_depfile_c_asm_EXISTS = YES" > "$1/build/$f"; done; }
for pd in $(find . -name package-data.mk -path '*dist*'); do d=$(dirname "$pd"); stubdeps "${d#./}"; done
for d in $(find . -type d \( -name 'dist' -o -name 'dist-*' -o -name 'stage[123]' \) ! -path '*/build/*' ! -path './bootstrapping/*'); do stubdeps "${d#./}"; done
grep -rhoE 'call (build-prog|build-package|manual-package-config),[^,)]+,[^,)]+' --include=ghc.mk . | awk -F, '{print $2"/"$3}' | sort -u | while read -r d; do stubdeps "$d"; done
find . \( -name '*.hc' -o -name '*.hi' -o -name '.depend-v.haskell' -o -name 'Config.hs' -o -name 'package-data.mk' \) | xargs -r touch
# Link stanzas for the compiler under either stage spelling the tree picks: `main` is normally a
# stub GHC's driver writes at link time, so hcboot_main.o supplies it; --start-group lets the static
# archives resolve in any order; -ltinfo is terminfo's extra library, which the gcc link rule does
# not collect.
cat >> mk/build.mk <<'EOF'
OMIT_PHASE_0 = YES
OMIT_PHASE_1 = YES
GHC = false
NO_GENERATED_MAKEFILE_RULES = YES
GhcStage2HcOpts = -O0
ghc_stage2_OTHER_OBJS += ghc/stage1/build/hcboot_main.o
ghc_stage2_v_EXTRA_CC_OPTS += -Wl,--start-group $(compiler_stage2_v_LIB) $(ALL_STAGE1_LIBS) $(ALL_RTS_LIBS) $(libffi_STATIC_LIB) $(wildcard hcstubs/libhcstubs.a) -Wl,--end-group -lgmp -lm -lutil -lrt -ldl -lpthread -ltinfo
ghc_stage1_OTHER_OBJS += ghc/stage1/build/hcboot_main.o
ghc_stage1_v_EXTRA_CC_OPTS += -Wl,--start-group $(compiler_stage1_v_LIB) $(ALL_STAGE1_LIBS) $(ALL_RTS_LIBS) $(libffi_STATIC_LIB) $(wildcard hcstubs/libhcstubs.a) -Wl,--end-group -lgmp -lm -lutil -lrt -ldl -lpthread -ltinfo
utils/ghc-pkg_dist-install_OTHER_OBJS += utils/ghc-pkg/dist-install/build/hcboot_main.o
utils/ghc-pkg_dist-install_v_EXTRA_CC_OPTS += -Wl,--start-group $(ALL_STAGE1_LIBS) $(ALL_RTS_LIBS) $(libffi_STATIC_LIB) $(wildcard hcstubs/libhcstubs.a) -Wl,--end-group -lgmp -lm -lutil -lrt -ltinfo -ldl -lpthread
EOF
for d in libraries/*/; do [ -x "$d/configure" ] && ( cd "$d" && ./configure > /dev/null 2>&1 ) || true; done
make bootstrapping-files > ../bootstrapping-files-2.log 2>&1 || true
# Command-line variables beat every makefile assignment: the RTS (manual-package-config) never
# gets rts_dist_CC etc. defined, AR_OPTS came out empty, and build.mk cannot override
# WhatGccIsCalled.
TOOLS="CC=${CC} CC_STAGE0=${CC} CC_STAGE1=${CC} CC_STAGE2=${CC} WhatGccIsCalled=${CC} AS=${CC} AS_STAGE1=${CC} AR=${AR} AR_STAGE1=${AR} AR_STAGE2=${AR} LD=${LD} LD_STAGE1=${LD}"
TOOLS="${TOOLS} rts_dist_CC=${CC} rts_dist_AS=${CC} rts_dist_AR=${AR} rts_dist_LD=${LD} rts_dist_HC=/bin/false"
TOOLS="${TOOLS} AR_OPTS=q AR_OPTS_STAGE0=q AR_OPTS_STAGE1=q AR_OPTS_STAGE2=q ArSupportsAtFile=NO ArSupportsAtFile_STAGE1=NO ArSupportsAtFile_STAGE2=NO"
# ghc-pkg's Version.hs is generated into the source dir by a rule that hs-sources.mk resolves too
# late; write it directly.
printf 'module Version where\nversion, targetOS, targetARCH :: String\nversion    = "%s"\ntargetOS   = "linux"\ntargetARCH = "x86_64"\n' "${VERSION}" > utils/ghc-pkg/Version.hs
# package-data.mk depends on inplace/bin/ghc-cabal, a Haskell program; a no-op stand-in older
# than every package-data.mk keeps make from rebuilding it.
mkdir -p inplace/bin utils/ghc-cabal/dist/build/tmp
printf '#!/bin/sh\nexit 0\n' > utils/ghc-cabal/dist/build/tmp/ghc-cabal; chmod +x utils/ghc-cabal/dist/build/tmp/ghc-cabal
cp utils/ghc-cabal/dist/build/tmp/ghc-cabal inplace/bin/ghc-cabal
touch -d '2013-01-01' utils/ghc-cabal/dist/build/tmp/ghc-cabal inplace/bin/ghc-cabal
find . -name package-data.mk -exec touch {} +
find . -name '.depend*.haskell' | xargs -r touch
cat > hcboot_main.c <<'CEOF'
#include "Rts.h"
extern StgClosure ZCMain_main_closure;
int main(int argc, char *argv[])
{
    RtsConfig __conf = defaultRtsConfig;
    __conf.rts_opts_enabled = RtsOptsSafeOnly;
    return hs_main(argc, argv, &ZCMain_main_closure, __conf);
}
CEOF
RTSDEFS="-DNO_REGS -DUSE_MINIINTERPRETER -D__GLASGOW_HASKELL__=706"
mkdir -p ghc/stage1/build utils/ghc-pkg/dist-install/build
"${CC}" -c hcboot_main.c -o ghc/stage1/build/hcboot_main.o -Iincludes -Iincludes/dist-derivedconstants/header -Iincludes/dist-ghcconstants/header -Irts/dist/build ${RTSDEFS}
cp ghc/stage1/build/hcboot_main.o utils/ghc-pkg/dist-install/build/hcboot_main.o
INCS=$(for d in includes includes/dist-derivedconstants/header includes/dist-ghcconstants/header rts/dist/build libraries/*/include libraries/*/dist-install/build libraries/*/dist-install/build/autogen; do [ -d "$d" ] && printf ' -I%s' "$d" || true; done)
for c in hcstubs/*.c; do "${CC}" -c "$c" -o "${c%.c}.o" ${INCS} ${RTSDEFS} -w; done
ar q hcstubs/libhcstubs.a hcstubs/*.o
# GMP >= 6.2 initialises an mpz lazily (no limb allocation); integer-gmp 0.5 recovers the result
# ByteArray# from the limb pointer unconditionally, so a zero-valued Integer would point into
# libgmp's data. Route the mpz_init calls through mpz_init2(x, 64), which allocates one limb.
GW=libraries/integer-gmp/cbits/gmp-wrappers.hc
sed -i '0,/^#include "Stg.h"/s//#include "Stg.h"\nextern void __gmpz_init2(void *, unsigned long);\nstatic void gmpfix_init(void *x) { __gmpz_init2(x, 64); }/' "$GW"
sed -i 's/((void (\*)(void \*))__gmpz_init)/((void (*)(void *))gmpfix_init)/g' "$GW"
[ "$(grep -c 'gmpfix_init)' "$GW")" -gt 0 ] || { echo "ghc-${VERSION}: mpz_init retarget did not apply" >&2; exit 1; }

# --- P4 make ---
make -j"${JOBS}" ${TOOLS} all_ghc_stage2 > ../make.log 2>&1 || { grep -n -B3 -m3 -E ' error: |undefined reference|No rule to make' ../make.log >&2; tail -20 ../make.log >&2; echo "ghc-${VERSION}: make failed" >&2; exit 1; }
make ${TOOLS} inplace/bin/ghc-pkg inplace/lib/unlit > ../make-tools.log 2>&1 || { tail -20 ../make-tools.log >&2; echo "ghc-${VERSION}: ghc-pkg/unlit did not build" >&2; exit 1; }
# The capi wrapper objects belong in libHSbase so every later link finds them.
BASEA=$(ls libraries/base/dist-install/build/libHSbase-*.a | head -1)
ar q "$BASEA" hcstubs/*.o
[ -x inplace/lib/ghc-stage2 ] || { echo "ghc-${VERSION}: inplace/lib/ghc-stage2 missing" >&2; exit 1; }
inplace/bin/ghc-pkg recache
[ -x inplace/lib/unlit ] || { echo "ghc-${VERSION}: unlit missing" >&2; exit 1; }
printf 'main = putStrLn ("GHC-GATE:" ++ show (product [1..5 :: Integer] - (2^(70::Int) - 2^(70::Int))))\n' > ../gate0.hs
inplace/bin/ghc-stage2 -O -o ../gate0 ../gate0.hs -outputdir ../gate0.d > ../gate0.log 2>&1 && OUT="$(../gate0)" || { cat ../gate0.log >&2; echo "ghc-${VERSION}: in-tree compiler failed the gate" >&2; exit 1; }
[ "$OUT" = "GHC-GATE:120" ] || { echo "ghc-${VERSION}: in-tree gate printed '$OUT'" >&2; exit 1; }

# --- P5 install: relocate the in-tree package db ---
# ghc-cabal, which `make install` uses to copy packages, is the no-op stand-in here. Each package's
# import/library/include dirs move under ${TOPDIR}/<package id>/ and the .conf files are rewritten.
LIBD="${DST}/lib/ghc-${VERSION}"; mkdir -p "${DST}/bin" "${LIBD}/package.conf.d"
for f in inplace/lib/*; do [ -f "$f" ] && cp "$f" "${LIBD}/"; done
mv "${LIBD}/ghc-stage2" "${LIBD}/ghc"
# ghc-pkg is installed inplace as the binary itself, not behind a wrapper
iself() { [ -f "$1" ] && [ "$(head -c 4 "$1" | tr -d '\0')" = $'\x7fELF' ]; }
for c in inplace/lib/ghc-pkg inplace/bin/ghc-pkg utils/ghc-pkg/dist-install/build/tmp/ghc-pkg; do iself "$c" && cp "$c" "${LIBD}/ghc-pkg" && break; done
[ -x "${LIBD}/ghc-pkg" ] || { echo "ghc-${VERSION}: no ghc-pkg binary found" >&2; exit 1; }
mkdir -p "${BUILDROOT}/confs"
for orig in inplace/lib/package.conf.d/*.conf; do
  # field values may continue on indented lines; fold each field onto one line first
  conf="${BUILDROOT}/confs/$(basename "$orig")"; sed -e ':a' -e 'N' -e '$!ba' -e 's/\n[[:space:]][[:space:]]*/ /g' "$orig" > "$conf"
  pkgid=$(sed -n 's/^id: *//p' "$conf" | head -1); name=$(sed -n 's/^name: *//p' "$conf" | head -1)
  [ "$name" = bin-package-db ] && continue   # only useful to the tree that built it
  dest="${LIBD}/${pkgid}"; mkdir -p "$dest"
  for field in import-dirs library-dirs; do
    for d in $(sed -n "s/^${field}: *//p" "$conf"); do [ -d "$d" ] && ( cd "$d" && find . \( -name '*.hi' -o -name '*.a' -o -name '*.h' -o -name '*.hs-boot' \) -exec cp --parents -n {} "$dest/" \; ); done
  done
  for d in $(sed -n 's/^include-dirs: *//p' "$conf"); do [ -d "$d" ] && mkdir -p "$dest/include" && ( cd "$d" && find . -name '*.h' -exec cp --parents -n {} "$dest/include/" \; ); done
  sed -E "s#^(import-dirs|library-dirs):.*#\1: ${TOPDIR}/${pkgid}#; s#^include-dirs:.*#include-dirs: ${TOPDIR}/${pkgid}/include#; s#^(haddock-interfaces|haddock-html):.*#\1:#" "$conf" > "${LIBD}/package.conf.d/$(basename "$conf")"
done
# The generated headers live in includes/dist-*/header/ but are included by bare name; the RTS
# package's include dir gets flat copies, plus the RTS build headers. This compiler goes through C
# for every module, so those headers are needed to compile any program.
RTSCONF=$(ls "${LIBD}"/package.conf.d/*.conf | xargs grep -l '^name: rts$' | head -1)
RTSID=$(sed -n 's/^id: *//p' "$RTSCONF" | head -1)
mkdir -p "${LIBD}/${RTSID}/include"
cp -n includes/dist-derivedconstants/header/*.h includes/dist-ghcconstants/header/*.h "${LIBD}/${RTSID}/include/" 2>/dev/null || true
( cd rts/dist/build && find . -maxdepth 1 -name '*.h' -exec cp -n {} "${LIBD}/${RTSID}/include/" \; )
[ -f "${LIBD}/${RTSID}/include/DerivedConstants.h" ] || { echo "ghc-${VERSION}: DerivedConstants.h not shipped" >&2; exit 1; }
[ -n "$(ls "${LIBD}/${RTSID}"/*.a 2>/dev/null)" ] || { echo "ghc-${VERSION}: RTS archives were not relocated" >&2; exit 1; }
cat > "${DST}/bin/ghc" <<EOF
#!/bin/sh
exec "${TOPDIR}/ghc" -B"${TOPDIR}" \${1+"\$@"}
EOF
cat > "${DST}/bin/ghc-pkg" <<EOF
#!/bin/sh
exec "${TOPDIR}/ghc-pkg" --global-package-db "${TOPDIR}/package.conf.d" \${1+"\$@"}
EOF
chmod 0755 "${DST}/bin/ghc" "${DST}/bin/ghc-pkg"
cp "${DST}/bin/ghc" "${DST}/bin/ghc-${VERSION}"; cp "${DST}/bin/ghc-pkg" "${DST}/bin/ghc-pkg-${VERSION}"
# The shipped C compiler wrapper; `settings` names it, so later compilers configured against this
# one inherit it.
mkfixlib "${DST}/lib/glibc-fixlib"
mkwrapper "${DST}/bin/ghc-cc" "${PREFIX}/lib/glibc-fixlib"
sed -i "s|${CCDIR}/gcc|${PREFIX}/bin/ghc-cc|g; s|${BUILDROOT}/T/inplace/lib|${TOPDIR}|g" "${LIBD}/settings"
grep -q "${PREFIX}/bin/ghc-cc" "${LIBD}/settings" || { echo "ghc-${VERSION}: settings does not name the shipped C compiler" >&2; exit 1; }
if grep -l "${BUILDROOT}" "${LIBD}"/package.conf.d/*.conf "${LIBD}/settings" "${DST}"/bin/* -q 2>/dev/null; then
  grep -l "${BUILDROOT}" "${LIBD}"/package.conf.d/*.conf "${LIBD}/settings" "${DST}"/bin/* >&2; echo "ghc-${VERSION}: build paths survive in the install" >&2; exit 1; fi

# --- P6 gate on the installed layout ---
# The install lives under ${DST}, not ${PREFIX}, until the package is placed; point the db at
# ${DST} for the gate and back afterwards. The settings still name the build-time wrapper here.
GATEDB="${LIBD}/gate.conf.d"; cp -r "${LIBD}/package.conf.d" "${GATEDB}"
sed -i "s|${PREFIX}|${DST}|g" "${GATEDB}"/*.conf
cp "${LIBD}/settings" "${BUILDROOT}/settings.shipped"
sed -i "s|${PREFIX}/bin/ghc-cc|${CCDIR}/gcc|" "${LIBD}/settings"
"${LIBD}/ghc-pkg" --global-package-db "${GATEDB}" recache
printf 'import Data.List\nmain = putStrLn ("GHC-GATE:" ++ show (product [1..5 :: Integer] - (2^(70::Int) - 2^(70::Int))) ++ ":" ++ show (length (nub [1..50::Int])))\n' > ../gate.hs
"${LIBD}/ghc" -B"${LIBD}" -no-global-package-db -package-db "${GATEDB}" -O -o ../gate ../gate.hs -outputdir ../gate.d > ../gate.log 2>&1 && OUT="$(../gate)" || { cat ../gate.log >&2; echo "ghc-${VERSION}: installed compiler failed the gate" >&2; exit 1; }
[ "$OUT" = "GHC-GATE:120:50" ] || { echo "ghc-${VERSION}: gate printed '$OUT'" >&2; exit 1; }
cp "${BUILDROOT}/settings.shipped" "${LIBD}/settings"
"${LIBD}/ghc-pkg" --global-package-db "${LIBD}/package.conf.d" recache
"${LIBD}/ghc" -B"${LIBD}" --info | grep -q '"Unregisterised","YES"' || { echo "ghc-${VERSION}: not the unregisterised compiler" >&2; exit 1; }
find "${GATEDB}" -delete

mkdir -p "${OUTPUT_DIR}/usr/share/ghc-${VERSION}"
cat > "${OUTPUT_DIR}/usr/share/ghc-${VERSION}/BUILDINFO" <<EOF
ghc ${VERSION} (unregisterised, hc-boot)
source: ${SRC_TARBALL} sha256 ${SRC_SHA}
hc bundle: ${BUNDLE} sha256 ${BUNDLE_SHA}
c compiler: gcc ${GCC_VERSION} via ${PREFIX}/bin/ghc-cc
sysroot: ${SR}
EOF
echo "ghc-${VERSION}: installed to ${PREFIX}"
