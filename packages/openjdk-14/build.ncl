let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# openjdk-14: one rung of the JVM ladder (jikes-1.22 -> classpath-0.93 -> jamvm-1.5.1 ->
# ant-bootstrap-1.8.4 -> ecj-bootstrap-3.2.2 -> classpath-0.99 -> classpath-devel -> jamvm-2.0.0
# -> ecj4-bootstrap-4.2.1 -> icedtea-7 -> icedtea-8 -> openjdk-9 -> ... -> openjdk-25).
# OpenJDK 14.0.2 from the GitHub tag archive, built with ../openjdk-13 as the boot JDK. Installs
# at /usr/lib/openjdk-14; nothing lands on /usr/bin.
# Sources mirrored to gs://minimal-staging-archives/. No `needs`: nothing here touches the network.
# amd64 only (see the match at the bottom).
let boot = import "../openjdk-13/build.ncl" in # the boot JDK
let gcc-bedrock = import "../gcc-15.2.0-glibc/build.ncl" in # asserted by build.sh
let binutils-bedrock = import "../binutils-2.46-glibc/build.ncl" in
let glibc-bedrock = import "../glibc-bedrock-2.42/build.ncl" in # sysroot
let bash = import "../bash/build.ncl" in
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in
let grep = import "../grep/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let findutils = import "../findutils/build.ncl" in
let tar = import "../tar/build.ncl" in
let python = import "../python/build.ncl" in # normalises the zip archives after install
let gawk = import "../gawk/build.ncl" in
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
let libjpeg = import "../libjpeg-turbo/build.ncl" in
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
let version = "14.0.2" in
let amd64_spec =
  {
    name = "openjdk-14",
    build_deps = [
      { file = "build.sh" } | Local,
      { file = "openjdk-10-setsignalhandler.patch" } | Local, # a signal-handler prototype gcc 11+ rejects
      { file = "openjdk-10-jtask-reproducibility.patch" } | Local, # deterministic output
      { file = "openjdk-13-classlist-reproducibility.patch" } | Local, # deterministic output
      {
        # https://github.com/openjdk/jdk14u/archive/refs/tags/jdk-14.0.2-ga.tar.gz
        url = "gs://minimal-staging-archives/jdk-14.0.2-ga.tar.gz",
        sha256 = "c3c9a0ae34a2b6980f25b478bbe76bcae8771db5408b00e6fb6416cfb17c2869",
        extract = false, # build.sh untars with --no-same-owner
      } | Source,
      boot,
      gcc-bedrock,
      binutils-bedrock,
      glibc-bedrock,
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
      libjpeg,
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
    cmd = "./build.sh",
    outputs = {
      # consumed by the next rung by absolute path
      prefix = { glob = "usr/lib/openjdk-14/**", allow_executable = true } | OutputData,
      buildinfo = { glob = "usr/share/openjdk-14/BUILDINFO" } | OutputData,
    },
    attrs =
      {
        upstream_version = version,
        license_spdx = "GPL-2.0-only WITH Classpath-exception-2.0",
        build_cost_multiple = 12,
        source_provenance = {
          category = 'GithubRepo,
          owner = "openjdk",
          repo = "jdk14u",
        },
      } | Attrs,
  } | BuildSpec
in
# amd64 only: this rung belongs to the amd64 bootstrap ladder; the spec collapses to an empty
# collection on arm64.
match {
  { arch = 'Amd64, .. } => amd64_spec,
  { arch = 'Arm64, .. } =>
    {
      name = "openjdk-14",
      build_deps = [],
    } | BuildSpec,
} target
