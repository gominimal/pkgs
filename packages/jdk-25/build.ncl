let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
# jdk-25: the current Java LTS line. OpenJDK built from the openjdk/jdk25u tag that Eclipse Temurin's
# release of the same version is built from, booted by ../openjdk-25 (the top of the JVM ladder) and
# compiled by the production toolchain. Same /usr/lib/jvm layout and outputs as the Temurin package
# it replaces. Leaves out the CDS archives and src.zip, which do not reproduce.
let openjdk-25 = import "../openjdk-25/build.ncl" in # the boot JDK
let base = import "../base/build.ncl" in
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

let version = "25.0.4.1" in
let build_num = "1" in
{
  name = "jdk-25",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # https://github.com/openjdk/jdk25u/archive/refs/tags/jdk-25.0.4.1-ga.tar.gz
      url = "gs://minimal-staging-archives/jdk-%{version}-ga.tar.gz",
      sha256 = "6552330e53548fdde364f23017d7de5356def59b37d1bc058a195822dbd9b75b",
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
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "java -version 2>&1 | grep -q 'version \"25'"],
        ],
      } | Test,

    javac_compile =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "echo 'public class Hi { public static void main(String[] a) { System.out.println(\"ok\"); } }' > Hi.java"],
          ["/bin/javac", "Hi.java"],
          ["/bin/bash", "-c", "java Hi | grep -q '^ok$'"],
        ],
      } | Test,
  },
} | BuildSpec
