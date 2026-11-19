#!/bin/bash
# OpenJDK from an openjdk/jdk<N>u `-ga` tag archive, for jdk-21, jdk-25 and jdk-27 (shared through
# ./from-source.ncl). Booted by a rung of the JVM ladder, compiled by the production toolchain,
# installed at /usr/lib/jvm with every tool linked from /usr/bin. Shaped like Temurin's build of the
# same tag (configure flags from Temurin's published build metadata; see each recipe's header), with
# the registry's third-party libraries instead of bundled copies.
#
# Per-version inputs, from build_args: MINIMAL_ARG_VERSION (21.0.13.1), MINIMAL_ARG_BUILD_NUM (2),
# MINIMAL_ARG_FEATURE (21), MINIMAL_ARG_BOOT (openjdk-21), MINIMAL_ARG_VERSION_OPT (LTS or empty).
set -eu

VERSION="${MINIMAL_ARG_VERSION:?}"
BUILD_NUM="${MINIMAL_ARG_BUILD_NUM:?}"
FEATURE="${MINIMAL_ARG_FEATURE:?}"
OPT="${MINIMAL_ARG_VERSION_OPT:-}"
NAME="jdk-${FEATURE}"
trap 'echo "${NAME}: failed at line $LINENO: $BASH_COMMAND" >&2' ERR
die() { echo "${NAME}: $*" >&2; exit 1; }

case "${VERSION}" in "${FEATURE}".*) ;; *) die "version ${VERSION} is not on the ${FEATURE} line" ;; esac
case "${OPT}" in "" | LTS) ;; *) die "version opt must be LTS or empty, not ${OPT}" ;; esac

BUILDROOT="$(pwd)"
DST="${OUTPUT_DIR}/usr/lib/jvm"
BOOT="/usr/lib/${MINIMAL_ARG_BOOT:?}"
JOBS="$(nproc 2>/dev/null || echo 4)"
export HOME="${BUILDROOT}/home"; mkdir -p "$HOME"
export TMPDIR="${BUILDROOT}/tmp"; mkdir -p "$TMPDIR"
export TAR_OPTIONS=--no-same-owner   # the sandbox cannot chown

for x in "${BOOT}/bin/javac" "${BOOT}/bin/java" /usr/include/gif_lib.h /usr/include/freetype2/freetype/freetype.h \
  /usr/include/X11/Intrinsic.h /etc/ssl/certs/ca-certificates.crt; do
  [ -e "$x" ] || die "missing build input $x"
done

# gnu17: gcc 15 defaults to C23, where `typedef int bool;` in jdk.hotspot.agent's libproc.h (still
# there at the 21, 25 and 27 tags) is an error. hotspot takes gcc from PATH, the rest from CC.
CCDIR="${BUILDROOT}/cc"; mkdir -p "${CCDIR}"
printf '#!/bin/sh\nexec "%s" -std=gnu17 "$@"\n' "$(command -v gcc)" > "${CCDIR}/gcc"
chmod 0755 "${CCDIR}/gcc"
export CC="${CCDIR}/gcc" CXX="$(command -v g++)"

mkdir src && tar -xzf "jdk-${VERSION}-ga.tar.gz" -C src --strip-components=1
cd src
# test binaries and jars in the tree; none feed the image
find . -type f \( -name '*.bin' -o -name '*.exe' -o -name '*.jar' \) -delete
echo "${VERSION}" > .src-rev

# cacerts from the registry's Mozilla store (curl's extract, the upstream Temurin's store comes from
# too), not OpenJDK's own list. GenerateCacerts makes one entry per file, aliased "<file> [jdk]", so
# the file names are made ASCII (Java under LC_ALL=C cannot open NetLock's non-ASCII one) and
# alias-shaped like OpenJDK's make/data/cacerts: lowercase letters and digits only.
CERTS="${BUILDROOT}/cacerts-src"; mkdir -p "${CERTS}"
export LC_COLLATE=C   # the glob below, and so any collision numbering, in byte order
n=0
for crt in /etc/ssl/certs/*.crt; do
  [ -f "$crt" ] && [ ! -L "$crt" ] || continue
  [ "$(basename "$crt")" = ca-certificates.crt ] && continue
  alias="$(basename "$crt" .crt | LC_ALL=C tr -cd 'A-Za-z0-9' | LC_ALL=C tr 'A-Z' 'a-z')"
  [ -n "$alias" ] || die "certificate $crt has no ASCII letters for an alias"
  # two labels that differ only in punctuation or case: number the later one (the glob is sorted)
  base="$alias"; k=2
  while [ -e "${CERTS}/${alias}" ]; do alias="${base}${k}"; k=$((k + 1)); done
  [ "$(grep -c '^-----BEGIN CERTIFICATE-----$' "$crt")" = 1 ] || die "$crt is not exactly one certificate"
  cp "$crt" "${CERTS}/${alias}"
  n=$((n + 1))
done
want="$(grep -c '^-----BEGIN CERTIFICATE-----$' /etc/ssl/certs/ca-certificates.crt)"
[ "$n" = "$want" ] || die "cacerts source has $n certificates, ca-certificates.crt has $want"
[ "$n" -ge 100 ] || die "only $n certificates in the cacerts source"
echo "${NAME}: cacerts source: $n certificates from ca-certificates"

export JAVA_HOME="${BOOT}" PATH="${BOOT}/bin:${CCDIR}:${PATH}"
# Version and vendor in Temurin's shape, under our own name:
#   openjdk version "21.0.13.1" 2026-11-17 LTS
#   OpenJDK Runtime Environment Minimal-21.0.13.1+2 (build 21.0.13.1+2-LTS)
# --with-source-date=version: every timestamp is the tag's release date (2026-11-17), as Temurin's.
# extra-cflags come last in the JDK's CFLAGS: gnu17 keeps gcc 15 off C23 (K&R `()` prototypes in
# libnet's gio shims), and gcc 14's incompatible-pointer-types error is a warning again (jtreg's
# libTestJNI.c).
LINKABLE=""
[ "${FEATURE}" -lt 24 ] || LINKABLE="--enable-linkable-runtime"   # JEP 493: no jmods/, as Temurin 24+
bash ./configure --with-boot-jdk="${BOOT}" --with-build-user=minimal --disable-warnings-as-errors \
  --with-native-debug-symbols=none \
  "--with-extra-cflags=-std=gnu17 -Wno-error=int-conversion -Wno-error=incompatible-pointer-types" \
  --without-gtest --with-stdc++lib=static --enable-cds-archive ${LINKABLE} \
  --with-version-pre= "--with-version-opt=${OPT}" --with-version-build="${BUILD_NUM}" \
  --with-vendor-name=Minimal "--with-vendor-version-string=Minimal-${VERSION}+${BUILD_NUM}" \
  --with-vendor-url=https://minimal.dev/ \
  --with-vendor-bug-url=https://github.com/gominimal/pkgs/issues \
  --with-vendor-vm-bug-url=https://github.com/gominimal/pkgs/issues \
  --with-source-date=version --with-hotspot-build-time=1970-01-01T00:00:01 \
  --with-cacerts-src="${CERTS}" \
  --with-giflib=system --with-lcms=system --with-libjpeg=system --with-libpng=system --with-zlib=system \
  --with-freetype-include=/usr/include/freetype2 --with-freetype-lib=/usr/lib > ../configure.log 2>&1 \
  || { grep -n -iE 'error|could not|cannot|not found' ../configure.log | tail -8 >&2 || true; die "configure failed"; }
# `images` rather than `all`: `all` adds the static launcher, which nothing here ships
make JOBS="${JOBS}" images > ../make.log 2>&1 \
  || { grep -nE 'error:|Error [0-9]|\*\*\* \[' ../make.log | grep -v Werror | tail -8 >&2 || true; tail -10 ../make.log >&2; die "make failed"; }
IMG="$(ls -d build/*/images/jdk | head -1)"
[ -x "${IMG}/bin/java" ] || die "no jdk image"
mkdir -p "${DST}" && cp -a "${IMG}/." "${DST}/"
cd "${BUILDROOT}"

# The new javac compiles and the new VM runs a program of its own language level, reporting the
# tag's version with the build number and the LTS marker.
WANT_RT="${VERSION}+${BUILD_NUM}${OPT:+-${OPT}}"
mkdir -p gate; printf '%s\n' 'import java.util.*;' 'public class G { public static void main(String[] a){ var xs = List.of(1,2,3,4,5,6); var s = 0; for (var x : xs) s += x; System.out.println("OJ:"+s+":"+Runtime.version()+":"+"ab".repeat(2)); } }' > gate/G.java
( cd gate && "${DST}/bin/javac" G.java )
OUT="$("${DST}/bin/java" -cp gate G 2>&1 | tail -1)"
[ "$OUT" = "OJ:21:${WANT_RT}:abab" ] || die "gate printed '$OUT', wanted OJ:21:${WANT_RT}:abab"
JV="$("${DST}/bin/java" -version 2>&1)"
grep -qF "Runtime Environment Minimal-${VERSION}+${BUILD_NUM} (build ${WANT_RT})" <<< "$JV" \
  || die "java -version is not in the expected shape: $JV"
if grep -qiE 'adoptium|temurin' <<< "$JV"; then die "java -version names another vendor: $JV"; fi

# Temurin's shape, checked rather than assumed.
R="$(cat "${DST}/release")"
grep -qx 'IMPLEMENTOR="Minimal"' <<< "$R" || die "release: IMPLEMENTOR is not Minimal"
grep -qx "IMPLEMENTOR_VERSION=\"Minimal-${VERSION}+${BUILD_NUM}\"" <<< "$R" || die "release: IMPLEMENTOR_VERSION"
grep -qx "JAVA_RUNTIME_VERSION=\"${WANT_RT}\"" <<< "$R" || die "release: JAVA_RUNTIME_VERSION is not ${WANT_RT}"
grep -qE '^JAVA_VERSION_DATE="20[0-9]{2}-[0-9]{2}-[0-9]{2}"$' <<< "$R" || die "release: no JAVA_VERSION_DATE"
[ -f "${DST}/lib/src.zip" ] || die "no lib/src.zip"
if [ -n "${LINKABLE}" ]; then
  [ ! -e "${DST}/jmods" ] || die "jmods/ shipped although the runtime is linkable"
else
  [ -d "${DST}/jmods" ] || die "no jmods/"
fi
# libstdc++ linked statically, as Temurin's: libjvm must not NEED it
command -v readelf >/dev/null || die "no readelf"
if readelf -d "${DST}/lib/server/libjvm.so" | grep -E 'NEEDED.*libstdc\+\+'; then
  die "libjvm.so NEEDs libstdc++ (--with-stdc++lib=static did not take)"
fi

# zip entry timestamps and order are build-time noise (jars, ct.sym, src.zip). NOT .jmod files:
# java.base.jmod records the hash of every other module's .jmod, so rewriting one makes
# `jlink --module-path .../jmods` fail with "Hash of <module> differs" (CodeRabbit on #1556).
# The jmods are already deterministic: --with-source-date=version makes the build pass a fixed
# --date to `jmod`. jdk-21's jlink_roundtrip test proves they stay linkable.
python3 - "${DST}" <<'PYEOF'
import io, os, shutil, sys, zipfile
def norm_bytes(b):
    """Rewrite a zip: fixed entry timestamps, sorted entries (manifest first), nested jars normalised too."""
    with zipfile.ZipFile(io.BytesIO(b)) as z:
        infos = z.infolist(); data = {i.filename: z.read(i) for i in infos}
    order = sorted(infos, key=lambda i: (0 if i.filename == 'META-INF/MANIFEST.MF' else 1 if i.filename.startswith('META-INF/') else 2, i.filename))
    out = io.BytesIO()
    with zipfile.ZipFile(out, 'w') as o:
        for i in order:
            d = data[i.filename]
            if (i.filename.endswith(('.jar', '.zip')) or i.filename.endswith('ct.sym')) and zipfile.is_zipfile(io.BytesIO(d)): d = norm_bytes(d)
            zi = zipfile.ZipInfo(i.filename, date_time=(1980, 1, 1, 0, 0, 0))
            zi.compress_type = i.compress_type; zi.external_attr = i.external_attr; zi.create_system = 3
            o.writestr(zi, d)
    return out.getvalue()
root = sys.argv[1]; n = 0
for dp, _, fn in os.walk(root):
    for f in fn:
        p = os.path.join(dp, f)
        if os.path.islink(p) or not (f.endswith(('.jar', '.zip', '.war')) or f == 'ct.sym'): continue
        with open(p, 'rb') as fh: raw = fh.read()
        head = b''
        if not zipfile.is_zipfile(io.BytesIO(raw)): continue
        tmp = p + '.tmp'
        with open(tmp, 'wb') as out: out.write(head); out.write(norm_bytes(raw))
        shutil.copymode(p, tmp); os.replace(tmp, p); n += 1
print("normalised", n, "archives")
PYEOF

# The default class list is written in class-load order, which varies run to run; only its
# membership matters. Sort it, then re-dump every CDS archive the build made from the sorted list,
# twice, with Images.gmk's exact flags, and ship it only if the two dumps are byte-identical.
[ -f "${DST}/lib/classlist" ] || die "no lib/classlist"
LC_ALL=C sort "${DST}/lib/classlist" > "${DST}/lib/classlist.sorted"
mv "${DST}/lib/classlist.sorted" "${DST}/lib/classlist"
cds_flags() {   # $1: archive base name (classes, classes_nocoops, classes_coh, classes_nocoh, ...)
  f="-Xmx128M -Xms128M -XX:+UseG1GC"
  case "$1" in *_nocoops*) f="$f -XX:-UseCompressedOops" ;; esac
  if [ "${FEATURE}" -eq 25 ]; then   # compact headers off by default; _coh turns them on
    case "$1" in *_coh) f="$f -XX:+UnlockExperimentalVMOptions -XX:+UseCompactObjectHeaders" ;;
      *) f="$f -XX:+UnlockExperimentalVMOptions -XX:-UseCompactObjectHeaders" ;; esac
  elif [ "${FEATURE}" -ge 26 ]; then   # compact headers on by default; _nocoh turns them off
    case "$1" in *_nocoh) f="$f -XX:+UnlockExperimentalVMOptions -XX:-UseCompactObjectHeaders" ;;
      *) f="$f -XX:+UnlockExperimentalVMOptions -XX:+UseCompactObjectHeaders" ;; esac
  fi
  echo "$f"
}
ls "${DST}"/lib/server/classes*.jsa >/dev/null 2>&1 || die "the build made no CDS archive"
[ -f "${DST}/lib/server/classes.jsa" ] && [ -f "${DST}/lib/server/classes_nocoops.jsa" ] \
  || die "missing classes.jsa or classes_nocoops.jsa"
for jsa in "${DST}"/lib/server/classes*.jsa; do
  base="$(basename "$jsa" .jsa)"
  flags="$(cds_flags "$base")"
  for t in a b; do
    rm -f "${TMPDIR}/${base}.$t.jsa"
    # shellcheck disable=SC2086
    "${DST}/bin/java" -Xshare:dump -XX:SharedArchiveFile="${TMPDIR}/${base}.$t.jsa" -server $flags \
      > "${TMPDIR}/${base}.$t.log" 2>&1 || { tail -5 "${TMPDIR}/${base}.$t.log" >&2; die "CDS dump of ${base} failed"; }
  done
  cmp -s "${TMPDIR}/${base}.a.jsa" "${TMPDIR}/${base}.b.jsa" \
    || die "${base}.jsa: two dumps of the same image differ; CDS is not deterministic here (use --disable-cds-archive)"
  # The image installs the archives read-only (0444), so `cp` over one fails with
  # "Permission denied" (#1556 at 2eef2870, both arches). Replace the file instead, and give
  # it Temurin's mode: Temurin ships every classes*.jsa 0644.
  rm -f "$jsa"
  cp "${TMPDIR}/${base}.a.jsa" "$jsa"
  chmod 0644 "$jsa"
  echo "${NAME}: ${base}.jsa re-dumped, deterministic ($(wc -c < "$jsa") bytes)"
done
# The archive maps and is used.
"${DST}/bin/java" -Xshare:on -version > /dev/null 2>&1 || die "java -Xshare:on cannot map the shipped CDS archive"

# CVE-2026-111943: drop the eMudhra/AAA anchors from cacerts and block the compromised
# intermediates (see ./cve-2026-111943.sh); fails the build if either does not hold afterwards.
# The cacerts source is now the registry's Mozilla store, which already lacks the distrusted
# anchors; the step then reports "not present" for them and still appends and checks blocked.certs.
(cd "${BUILDROOT}" && sh ./cve-2026-111943.sh "${DST}")

# The SHIPPED trust store holds every root of the source: GenerateCacerts or the step above
# must not drop one silently. ($n is the source count checked against ca-certificates.crt
# above; the distrusted anchors are absent from the Mozilla store, so nothing is removed.)
# For scale: Temurin 25.0.5.1's cacerts holds 117 roots, curl's 2026-11-05 extract 118. The
# one difference is Izenpe.com, which Mozilla still trusts for TLS and Adoptium leaves out.
shipped="$("${DST}/bin/keytool" -list -cacerts -storepass changeit 2>/dev/null | grep -c 'trustedCertEntry')" \
  || die "keytool cannot list the shipped cacerts"
[ "$shipped" = "$n" ] || die "shipped cacerts has $shipped entries, its source had $n"
echo "${NAME}: shipped cacerts: $shipped roots"

mkdir -p "${OUTPUT_DIR}/usr/bin"
for path in "${DST}"/bin/*; do
  bin=$(basename "$path")
  ln -sv "../lib/jvm/bin/$bin" "${OUTPUT_DIR}/usr/bin/$bin"
done
