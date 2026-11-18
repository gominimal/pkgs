let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
# jdk-25: the current Java LTS line. OpenJDK built from the openjdk/jdk25u tag that Eclipse Temurin's
# release of the same version is built from, booted by ../openjdk-25 (a rung of the JVM ladder) and
# compiled by the production toolchain. Same /usr/lib/jvm layout and outputs as the Temurin package
# it replaces. Leaves out the CDS archives and src.zip, which do not reproduce.
let openjdk-25 = import "../openjdk-25/build.ncl" in # the boot JDK
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
# not the `jdk` meta-package: the inputs of build.sh's CVE-2026-111943 step
let jdk = import "../jdk/cve-2026-111943.ncl" in
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

let version = "25.0.5.1" in
let build_num = "2" in
{
  name = "jdk-25",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # https://github.com/openjdk/jdk25u/archive/refs/tags/jdk-25.0.5.1-ga.tar.gz (CVE-2026-114938, Java4Shell)
      url = "gs://minimal-staging-archives/jdk-%{version}-ga.tar.gz",
      sha256 = "b4a28f325bc5f38f87c13489a5825613bba78a0e55ebe4202a993e982c62922e",
      extract = false, # build.sh untars with --no-same-owner
    } | Source,
    openjdk-25,
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
    jdk.script,
    jdk.program,
    jdk.fixtures,
    jdk.blocked_sha256,
  ],
  # java loads libz; AWT, sound, font and image code load the X libraries, alsa, freetype, lcms2, libpng, giflib and libjpeg
  runtime_deps = [
    glibc,
    zlib,
    freetype,
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
        repo = "jdk25u",
      },
    } | Attrs,

  tests = {
    java_version =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, grep],
        cmds = [
          ["/bin/bash", "-c", "java -version 2>&1 | grep -q 'version \"25'"],
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
    # intermediates (one ECDSA-malleated encoding checked; the build checks all 48).
    cve_2026_111943 =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, coreutils, grep],
        cmds = [
          ["/bin/bash", "-c", "set -eu; ks=$(keytool -list -cacerts -storepass changeit -v 2>&1); n=$(grep -c '^Alias name:' <<< \"$ks\"); echo \"cacerts entries: $n\"; [ \"$n\" -ge 80 ]; if grep -E 'SHA256: (86:A1:EC:BA:08:9C:4A:8D|D7:A7:A0:FB:5D:7E:27:31)' <<< \"$ks\"; then echo 'distrusted root still in cacerts'; exit 1; fi; bc=/usr/lib/jvm/lib/security/blocked.certs; head -n 1 $bc | grep -qx 'Algorithm=SHA-256'; grep -qx 37E866582D43C35D7C17D47794B974F291B3047B868DC123382477F7A08AEFA8 $bc"],
        ],
      } | Test,
  },
} | BuildSpec
