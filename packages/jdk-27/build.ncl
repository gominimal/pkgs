let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
# jdk-27: the current Java feature release (non-LTS), for projects that opt into the newest language
# and JVM features. OpenJDK built from the
# openjdk/jdk27u `-ga` tag that Eclipse Temurin's release of the same version is built from,
# booted by a rung of the JVM ladder and compiled by the production toolchain. The build is
# ../jdk/build-from-source.sh (shared): Temurin's layout and version shape under our own vendor
# name, CDS archives, src.zip, static libstdc++, cacerts from ../ca-certificates, and the registry's
# freetype/lcms2/libpng/libjpeg/giflib/zlib instead of bundled copies (gominimal/pkgs#1556).
#
# Trust store: OpenJDK reads its roots from a keystore (by default lib/security/cacerts, or the
# file javax.net.ssl.trustStore names), and on Linux it has no keystore type that reads
# /etc/ssl/certs or a PEM bundle, so it cannot use the system store. The build makes cacerts from
# ../ca-certificates, whose own build fails on any root in its distrust.txt, and the
# CVE-2026-111943 step applies the JDK's denylist (blocked.certs). A ca-certificates update reaches
# cacerts by rebuilding the JDK: ca-certificates is a build dep, so it is in the hash.
let openjdk-26 = import "../openjdk-26/build.ncl" in # the boot JDK
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
# not the `jdk` meta-package: the shared build script and the CVE-2026-111943 step's inputs
let jdk = import "../jdk/from-source.ncl" in
let ca-certificates = import "../ca-certificates/build.ncl" in # the cacerts source
let binutils = import "../binutils/build.ncl" in # readelf, for the libstdc++ test
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let bash = import "../bash/build.ncl" in
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in
let grep = import "../grep/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let findutils = import "../findutils/build.ncl" in
let tar = import "../tar/build.ncl" in
let python = import "../python/build.ncl" in # normalises the zip archives after install
let gawk = import "../gawk/build.ncl" in # configure scripts and config.status
let diffutils = import "../diffutils/build.ncl" in
let gzip = import "../gzip/build.ncl" in
let patch = import "../patch/build.ncl" in
let zip = import "../zip/build.ncl" in
let unzip = import "../unzip/build.ncl" in
let cpio = import "../cpio/build.ncl" in
let file = import "../file/build.ncl" in
let which = import "../which/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let autoconf = import "../autoconf/build.ncl" in # configure regenerates itself
let m4 = import "../m4/build.ncl" in
let zlib = import "../zlib/build.ncl" in
let freetype = import "../freetype/build.ncl" in
let cups = import "../cups/build.ncl" in
let alsa-lib = import "../alsa-lib/build.ncl" in
let lcms2 = import "../lcms2/build.ncl" in
let fontconfig = import "../fontconfig/build.ncl" in
let libpng = import "../libpng/build.ncl" in
let libjpeg-turbo = import "../libjpeg-turbo/build.ncl" in
let giflib = import "../giflib/build.ncl" in
let libx11 = import "../libx11/build.ncl" in
let libxext = import "../libxext/build.ncl" in
let libxrender = import "../libxrender/build.ncl" in
let libxtst = import "../libxtst/build.ncl" in
let libxi = import "../libxi/build.ncl" in
let libxinerama = import "../libxinerama/build.ncl" in
let libxrandr = import "../libxrandr/build.ncl" in
let libxcomposite = import "../libxcomposite/build.ncl" in
let libxt = import "../libxt/build.ncl" in
let xorgproto = import "../xorgproto/build.ncl" in

let version = "27.0.1.1" in
let build_num = "4" in
{
  name = "jdk-27",
  build_deps = [
    { file = "build.sh" } | Local,
    jdk.script,
    {
      # https://github.com/openjdk/jdk27u/archive/refs/tags/jdk-27.0.1.1-ga.tar.gz (CVE-2026-114938, Java4Shell)
      url = "gs://minimal-staging-archives/jdk-%{version}-ga.tar.gz",
      sha256 = "024dd1810fd02991a02e9ca1f5f74f69b3e9c5f1d35e926bddea033704397bb0",
      extract = false, # build.sh untars with --no-same-owner
    } | Source,
    openjdk-26,
    toolchain,
    bash,
    make,
    sed,
    grep,
    coreutils,
    findutils,
    tar,
    python,
    gawk,
    diffutils,
    gzip,
    patch,
    zip,
    unzip,
    cpio,
    file,
    which,
    pkgconf,
    autoconf,
    m4,
    zlib,
    freetype,
    cups,
    alsa-lib,
    lcms2,
    fontconfig,
    libpng,
    libjpeg-turbo,
    giflib,
    libx11,
    libxext,
    libxrender,
    libxtst,
    libxi,
    libxinerama,
    libxrandr,
    libxcomposite,
    libxt,
    xorgproto,
    jdk.cve.script,
    jdk.cve.program,
    jdk.cve.fixtures,
    jdk.cve.blocked_sha256,
    ca-certificates,
  ],
  # java loads libz; AWT, sound, font and image code load the X libraries, alsa, freetype, fontconfig, lcms2, libpng, giflib and libjpeg
  runtime_deps = [
    glibc,
    zlib,
    freetype,
    fontconfig, # libfontmanager dlopens libfontconfig at run time
    libpng,
    giflib,
    libjpeg-turbo,
    lcms2,
    alsa-lib,
    libx11,
    libxext,
    libxi,
    libxrender,
    libxtst,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
    include build_num,
    feature = "27",
    boot = "openjdk-26",
    version_opt = "",
  },

  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,

    jvm_bins = { glob = "usr/lib/jvm/bin/*" } | OutputBin,
    jvm_libs = { glob = "usr/lib/jvm/lib/**/*.so*" } | OutputLib,
    jvm_libdata = { glob = "usr/lib/jvm/lib/**", allow_executable = true } | OutputData,

    jvm_data = { glob = "usr/lib/jvm/{jmods,conf,legal}/**" } | OutputData,
    jvm_release = { glob = "usr/lib/jvm/release" } | OutputData,
    jvm_includes = { glob = "usr/lib/jvm/include/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      build_cost_multiple = 12,
      license_spdx = "GPL-2.0-only WITH Classpath-exception-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "openjdk",
        repo = "jdk27u",
      },
    } | Attrs,

  tests = {
    # `java -version` in Temurin's shape with our vendor name, and the CDS archive in use.
    java_version =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, grep],
        cmds = [
          ["/bin/bash", "-c", "set -eu; v=$(java -version 2>&1); echo \"$v\"; grep -qF 'Runtime Environment Minimal-%{version}+%{build_num} (build %{version}+%{build_num})' <<< \"$v\"; grep -q 'sharing)' <<< \"$v\"; if grep -qiE 'adoptium|temurin' <<< \"$v\"; then exit 1; fi"],
        ],
      } | Test,

    # The shipped CDS archive maps (-Xshare:on fails if not), and a user can dump their own.
    cds =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap],
        cmds = [
          ["/usr/bin/java", "-Xshare:on", "-version"],
          ["/bin/bash", "-c", "set -eu; java -XX:SharedArchiveFile=$PWD/app.jsa -Xshare:dump > dump.log 2>&1 || { tail -5 dump.log; exit 1; }; java -XX:SharedArchiveFile=$PWD/app.jsa -Xshare:on -version"],
        ],
      } | Test,

    # src.zip ships, as Temurin's, for IDEs and debuggers.
    src_zip =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, grep],
        cmds = [
          ["/bin/bash", "-c", "jar tf /usr/lib/jvm/lib/src.zip | grep -qx java.base/java/lang/Object.java"],
        ],
      } | Test,

    # jlink links from the installed image (JEP 493, --enable-linkable-runtime; no jmods/). It
    # re-hashes every file of each module it links against the SHA-512 the build recorded and
    # refuses one that changed ("has been modified"): java.base's lib/classlist, jrt-fs.jar and
    # security/blocked.certs, jdk.compiler's lib/ct.sym. The linked runtime runs and carries the
    # CVE-2026-111943 blocked.certs. (cacerts is exempt from the check: upgrade_files_java.base.conf.)
    jlink_from_runtime =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, grep],
        cmds = [
          ["/bin/bash", "-c", "set -eu; jlink --add-modules java.base --output $PWD/rt; $PWD/rt/bin/java -version 2>&1 | grep -qF '%{version}+%{build_num}'; grep -qx 37E866582D43C35D7C17D47794B974F291B3047B868DC123382477F7A08AEFA8 $PWD/rt/lib/security/blocked.certs"],
          ["/bin/bash", "-c", "set -eu; jlink --add-modules java.base,jdk.compiler --output $PWD/rtc; echo 'public class Hi { public static void main(String[] a) { System.out.println(\"ok\"); } }' > Hi.java; $PWD/rtc/bin/java Hi.java | grep -qx ok"],
        ],
      } | Test,

    # libstdc++ is linked statically, as Temurin's: libjvm does not NEED it.
    libjvm_static_libstdcpp =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, grep, binutils],
        cmds = [
          ["/bin/bash", "-c", "set -eu; d=$(readelf -d /usr/lib/jvm/lib/server/libjvm.so); grep -q NEEDED <<< \"$d\"; if grep -E 'NEEDED.*libstdc\\+\\+' <<< \"$d\"; then exit 1; fi"],
        ],
      } | Test,

    javac_compile =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, grep],
        cmds = [
          ["/bin/bash", "-c", "echo 'public class Hi { public static void main(String[] a) { System.out.println(\"ok\"); } }' > Hi.java"],
          ["/bin/javac", "Hi.java"],
          ["/bin/bash", "-c", "java Hi | grep -q '^ok$'"],
        ],
      } | Test,

    # CVE-2026-111943: the shipped trust store no longer holds emSign ECC Root CA - G3 or
    # AAA Certificate Services, still holds the rest, and blocked.certs lists the compromised
    # intermediates (one ECDSA-malleated encoding checked; the build checks all 48). Izenpe.com
    # must be absent too: left out like Temurin, as Mozilla trusts it only to a distrust-after date.
    cve_2026_111943 =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, coreutils, grep],
        cmds = [
          ["/bin/bash", "-c", "set -eu; ks=$(keytool -list -cacerts -storepass changeit -v 2>&1); n=$(grep -c '^Alias name:' <<< \"$ks\"); echo \"cacerts entries: $n\"; [ \"$n\" -ge 80 ]; if grep -E 'SHA256: (86:A1:EC:BA:08:9C:4A:8D|D7:A7:A0:FB:5D:7E:27:31|25:30:CC:8E:98:32:15:02)' <<< \"$ks\"; then echo 'distrusted or omitted root still in cacerts'; exit 1; fi; bc=/usr/lib/jvm/lib/security/blocked.certs; head -n 1 $bc | grep -qx 'Algorithm=SHA-256'; grep -qx 37E866582D43C35D7C17D47794B974F291B3047B868DC123382477F7A08AEFA8 $bc"],
        ],
      } | Test,
  },
} | BuildSpec
