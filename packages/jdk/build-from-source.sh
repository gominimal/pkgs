#!/bin/bash
# OpenJDK from an openjdk/jdk<N>u `-ga` tag archive, for jdk-21, jdk-25 and jdk-27 (shared through
# ./from-source.ncl). Booted by a rung of the JVM ladder, compiled by the production toolchain,
# installed at /usr/lib/jvm with every tool linked from /usr/bin. Shaped like Temurin's build of the
# same tag (configure flags from Temurin's published build metadata; the configure call below), with
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

# CVE-2026-111943's blocked.certs half goes in before the image is linked, not after: the build's
# lib/security/blocked.certs is a java.base file, so java.base.jmod carries it (what
# `jlink --module-path jmods` copies on 21) and, on 25+, jlink records its SHA-512 and refuses to
# link from an image whose copy differs ("has been modified"). OpenJDK's BlockedCertsConverter
# takes certificates and we hold only the 48 fingerprints, so its Gendata rule appends them:
# the converter's header, then the union, sorted and unique, as the converter writes it.
# ./cve-2026-111943.sh still runs after the build; it finds every fingerprint present and its
# rewrite of blocked.certs leaves the bytes as they are (checked at the end on 25+).
CVE_FPS="${BUILDROOT}/cve-blocked-sha256.sorted"
grep -E '^[0-9A-F]{64}$' "${BUILDROOT}/cve-2026-111943-blocked-sha256.txt" | LC_ALL=C sort -u > "${CVE_FPS}"
[ "$(wc -l < "${CVE_FPS}" | tr -d ' ')" = 48 ] || die "cve-2026-111943-blocked-sha256.txt: expected 48 fingerprints"
python3 - make/modules/java.base/gendata/GendataBlockedCerts.gmk "${CVE_FPS}" <<'PYEOF'
import sys
path, fps = sys.argv[1], sys.argv[2]
old = "\t($(CAT) $(GENDATA_BLOCKED_CERTS_SRC) | $(TOOL_BLOCKED_CERTS) > $@) || exit 1\n"
# Nothing beside $@: every file in that directory goes into java.base.jmod.
new = ("\t($(CAT) $(GENDATA_BLOCKED_CERTS_SRC) | $(TOOL_BLOCKED_CERTS) | { IFS= read -r h"
       " && [ \"$$h\" = Algorithm=SHA-256 ] && echo \"$$h\" && { cat; cat " + fps + "; } | LC_ALL=C sort -u; }"
       " > $@) || exit 1\n")
with open(path) as f: s = f.read()
if s.count(old) != 1: sys.exit(path + ": the blocked.certs rule is not in the expected shape")
with open(path, "w") as f: f.write(s.replace(old, new))
PYEOF

# cacerts from the registry's Mozilla store (curl's extract, the upstream Temurin's store comes from
# too), not OpenJDK's own list. GenerateCacerts makes one entry per file, aliased "<file> [jdk]", so
# the file names are made ASCII (Java under LC_ALL=C cannot open NetLock's non-ASCII one) and
# alias-shaped like OpenJDK's make/data/cacerts: lowercase letters and digits only.
CERTS="${BUILDROOT}/cacerts-src"; mkdir -p "${CERTS}"
export LC_COLLATE=C   # the glob below, and so any collision numbering, in byte order

# Left out of the JDK's store only (the system ca-certificates keeps it): Izenpe.com. Mozilla
# trusts it for TLS only up to a distrust-after date, which Java's cacerts cannot express, so
# like Temurin (whose store is otherwise this exact set) we leave it out. Found by its label's
# file name, then proven by SHA-256. A bundle without the file has nothing to leave out: Mozilla
# will drop this root, and that ca-certificates update must not fail the JDK builds. A file of
# that name holding another certificate fails the build.
OMIT_CRT=/etc/ssl/certs/Izenpe.com.crt
OMIT_SHA256=2530CC8E98321502BAD96F9B1FBA1B099E2D299E0F4548BB914F363BC0D4531F
omitted=0
if [ -e "$OMIT_CRT" ] || [ -L "$OMIT_CRT" ]; then
  [ -f "$OMIT_CRT" ] && [ ! -L "$OMIT_CRT" ] || die "$OMIT_CRT is not a regular file"
  omit_fp="$("${BOOT}/bin/keytool" -printcert -file "$OMIT_CRT" | sed -n 's/^[[:space:]]*SHA256: //p' | tr -d ':')"
  [ "$omit_fp" = "$OMIT_SHA256" ] || die "$OMIT_CRT has SHA-256 '$omit_fp', not Izenpe.com's $OMIT_SHA256"
  omitted=1
else
  echo "${NAME}: no $OMIT_CRT in ca-certificates; nothing to leave out"
fi

n=0
for crt in /etc/ssl/certs/*.crt; do
  [ -f "$crt" ] && [ ! -L "$crt" ] || continue
  [ "$(basename "$crt")" = ca-certificates.crt ] && continue
  [ "$crt" = "$OMIT_CRT" ] && continue
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
# Every root of the bundle but the one left out above, when it was there: 117 today, Temurin
# 25.0.5.1's exact set. Any other difference fails the build.
want=$((want - omitted))
[ "$n" = "$want" ] || die "cacerts source has $n certificates, expected $want (ca-certificates.crt minus $omitted left out)"
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
dyn="$(readelf -d "${DST}/lib/server/libjvm.so")" || die "readelf cannot read libjvm.so"
grep -q NEEDED <<< "$dyn" || die "readelf lists no NEEDED entries for libjvm.so"
if grep -E 'NEEDED.*libstdc\+\+' <<< "$dyn"; then
  die "libjvm.so NEEDs libstdc++ (--with-stdc++lib=static did not take)"
fi

# The files a linkable runtime (JEP 493, 25+) makes `jlink` check. jlink --generate-linkable-runtime
# records, per module, every file it puts outside lib/modules (bin, conf, lib, legal, include, man)
# with its SHA-512, in jdk.jlink's jdk/tools/jlink/internal/runtimelink/fs_<module>_files. Linking
# from this image later re-hashes each file of every module it links and fails on a mismatch
# ("<file> has been modified"), except the module's upgrade_files_<module>.conf entries
# (java.base: lib/security/cacerts and lib/tzdb.dat). So after the build no step may change a
# recorded file but those: `list` names them for the normaliser, and `check` at the end runs
# jlink's own comparison over every module. (jdk.jlink's JRTArchive.addNonClassResources and
# LinkableRuntimeImage, at the 25 and 27 tags.)
cat > "${TMPDIR}/LinkableRuntimeFiles.java" <<'JEOF'
import java.net.URI;
import java.nio.file.*;
import java.security.MessageDigest;
import java.util.*;

public class LinkableRuntimeFiles {
    public static void main(String[] a) throws Exception {
        boolean check = a.length == 1 && a[0].equals("check");
        if (!check && !(a.length == 1 && a[0].equals("list"))) throw new IllegalArgumentException("usage: list|check");
        Path home = Path.of(System.getProperty("java.home"));
        Path dir = FileSystems.getFileSystem(URI.create("jrt:/")).getPath("/modules/jdk.jlink/jdk/tools/jlink/internal/runtimelink");
        List<Path> lists = new ArrayList<>();
        if (Files.isDirectory(dir)) try (var s = Files.list(dir)) {
            s.filter(p -> p.getFileName().toString().matches("fs_.+_files")).sorted().forEach(lists::add);
        }
        int checked = 0, exempt = 0;
        List<String> bad = new ArrayList<>();
        for (Path l : lists) {
            String f = l.getFileName().toString();
            String module = f.substring(3, f.length() - "_files".length());
            Set<String> upgradeable = new HashSet<>();
            Path conf = dir.resolve("upgrade_files_" + module + ".conf");
            if (Files.exists(conf)) for (String line : Files.readAllLines(conf)) if (!line.trim().startsWith("#")) upgradeable.add(line);
            String content = Files.readString(l);
            if (content.isEmpty()) continue;
            for (String line : content.split("\n")) {
                if (line.isEmpty()) continue;
                String[] t = line.split("\\|", 4);
                if (t.length != 4) throw new IllegalStateException(f + ": unexpected line " + line);
                if (t[1].equals("1")) continue;   // a symlink: jlink records its target, not a hash
                if (!check) { System.out.println(t[3]); continue; }
                if (upgradeable.contains(t[3])) { exempt++; continue; }
                Path p = home.resolve(t[3]);
                if (!Files.isRegularFile(p)) { bad.add(module + ": " + t[3] + " is missing"); continue; }
                byte[] want = HexFormat.of().parseHex(t[2]);
                byte[] got = MessageDigest.getInstance("SHA-512").digest(Files.readAllBytes(p));
                if (!MessageDigest.isEqual(want, got)) bad.add(module + ": " + t[3] + " has been modified");
                checked++;
            }
        }
        if (!check) return;
        if (lists.isEmpty()) throw new IllegalStateException("no fs_<module>_files in jdk.jlink: not a linkable runtime");
        for (String b : bad) System.err.println("LinkableRuntimeFiles: " + b);
        if (!bad.isEmpty() || checked == 0) System.exit(1);
        System.out.println("LinkableRuntimeFiles: " + checked + " recorded files of " + lists.size()
            + " modules as jlink recorded them (" + exempt + " upgradeable, not checked)");
    }
}
JEOF
RECORDED="${TMPDIR}/linkable-recorded-files"
"${DST}/bin/java" -XX:-UsePerfData "${TMPDIR}/LinkableRuntimeFiles.java" list > "${RECORDED}" \
  || die "cannot read the linkable runtime's recorded files"
if [ -n "${LINKABLE}" ]; then
  grep -qx 'lib/security/blocked.certs' "${RECORDED}" || die "jlink recorded no lib/security/blocked.certs: the check below would prove nothing"
  echo "${NAME}: jlink recorded $(wc -l < "${RECORDED}" | tr -d ' ') files; none of them is changed below but cacerts"
else
  [ ! -s "${RECORDED}" ] || die "a runtime built without --enable-linkable-runtime records linkable files"
fi

# zip entry timestamps and order are build-time noise (jars, ct.sym, src.zip). Not .jmod files:
# java.base.jmod records the hash of every other module's .jmod, so rewriting one makes
# `jlink --module-path .../jmods` fail with "Hash of <module> differs". The jmods are already
# deterministic: --with-source-date=version makes the build pass a fixed --date to `jmod`.
# Not the files a linkable runtime records either (above: lib/jrt-fs.jar in java.base,
# lib/ct.sym in jdk.compiler on 25+), so on 25+ this leaves only src.zip, which no module owns.
# Those two are made with the same fixed date (SetupJarArchive and CreateSymbols take
# --with-source-date). jlink_roundtrip / jlink_from_runtime prove each line stays linkable.
python3 - "${DST}" "${RECORDED}" <<'PYEOF'
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
root = sys.argv[1]; n = 0; kept = []
with open(sys.argv[2]) as fh: recorded = set(fh.read().split('\n')) - {''}
for dp, _, fn in os.walk(root):
    for f in fn:
        p = os.path.join(dp, f)
        if os.path.islink(p) or not (f.endswith(('.jar', '.zip', '.war')) or f == 'ct.sym'): continue
        if os.path.relpath(p, root) in recorded: kept.append(os.path.relpath(p, root)); continue
        with open(p, 'rb') as fh: raw = fh.read()
        if not zipfile.is_zipfile(io.BytesIO(raw)): continue
        tmp = p + '.tmp'
        with open(tmp, 'wb') as out: out.write(norm_bytes(raw))
        shutil.copymode(p, tmp); os.replace(tmp, p); n += 1
print("normalised", n, "archives; left as jlink recorded them:", ' '.join(sorted(kept)) or 'none')
PYEOF

# lib/classlist ships as the build wrote it: GenerateLinkOptData.gmk already orders it
# (build.tools.classlist.SortClasslist: comments, sorted classes, then the @ lines, at the 21, 25
# and 27 tags), and it is a java.base file jlink records on 25+. Re-dump every CDS archive the
# build made from it, twice, with Images.gmk's exact flags, and ship it only if the two dumps are
# byte-identical. The archives are written after the image is linked, so jlink records none.
[ -f "${DST}/lib/classlist" ] || die "no lib/classlist"
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
  # "Permission denied". Replace the file instead, and give it Temurin's mode: Temurin ships
  # every classes*.jsa 0644.
  rm -f "$jsa"
  cp "${TMPDIR}/${base}.a.jsa" "$jsa"
  chmod 0644 "$jsa"
  echo "${NAME}: ${base}.jsa re-dumped, deterministic ($(wc -c < "$jsa") bytes)"
done
# The archive maps and is used.
"${DST}/bin/java" -Xshare:on -version > /dev/null 2>&1 || die "java -Xshare:on cannot map the shipped CDS archive"

# CVE-2026-111943: drop the eMudhra/AAA anchors from cacerts and block the compromised
# intermediates (see ./cve-2026-111943.sh); fails the build if either does not hold afterwards.
# The cacerts source is the registry's Mozilla store, which already lacks the distrusted
# anchors, and the build's blocked.certs already lists the intermediates (the Gendata rule
# above); the step reports "not present" for the anchors, finds the fingerprints in place,
# and checks both with the JDK. cacerts is upgradeable for jlink; blocked.certs must not move.
(cd "${BUILDROOT}" && sh ./cve-2026-111943.sh "${DST}")

# The SHIPPED trust store holds every root of the source: GenerateCacerts or the step above
# must not drop one silently. ($n is the source count checked against ca-certificates.crt
# above; the distrusted anchors are absent from the Mozilla store, so nothing is removed.)
# With Izenpe.com left out this is Temurin 25.0.5.1's set exactly: 117 roots, the same by SHA-256.
shipped="$("${DST}/bin/keytool" -list -cacerts -storepass changeit 2>/dev/null | grep -c 'trustedCertEntry')" \
  || die "keytool cannot list the shipped cacerts"
[ "$shipped" = "$n" ] || die "shipped cacerts has $shipped entries, its source had $n"
echo "${NAME}: shipped cacerts: $shipped roots"

# Last edit to the image is above. A linkable runtime still links: every file jlink recorded
# has the SHA-512 it recorded (cacerts and tzdb.dat exempt, as jlink exempts them).
if [ -n "${LINKABLE}" ]; then
  "${DST}/bin/java" -XX:-UsePerfData "${TMPDIR}/LinkableRuntimeFiles.java" check \
    || die "the image no longer links: a file jlink recorded was changed after the build"
fi

mkdir -p "${OUTPUT_DIR}/usr/bin"
for path in "${DST}"/bin/*; do
  bin=$(basename "$path")
  ln -sv "../lib/jvm/bin/$bin" "${OUTPUT_DIR}/usr/bin/$bin"
done
