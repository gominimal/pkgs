let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# openjdk-10: one rung of the JVM ladder (jikes-1.22 -> classpath-0.93 -> jamvm-1.5.1 -> ant-bootstrap-1.8.4 -> ecj-bootstrap-3.2.2 -> classpath-0.99 -> classpath-devel -> jamvm-2.0.0 -> ecj4-bootstrap-4.2.1 -> icedtea-7 -> icedtea-8 -> openjdk-9 .. 25).
# OpenJDK 10+46 from the GitHub tag archive, built with ../openjdk-9 as the boot JDK (with -XX:UseAVX=2: its AVX-512 intrinsics miscompile on AVX-512 hosts). Installs at /usr/lib/openjdk-10; nothing lands on /usr/bin.
# Sources mirrored to gs://minimal-staging-archives/. No `needs`: nothing here touches the network.
# amd64 only (see the match at the bottom).
let boot = import "../openjdk-9/build.ncl" in # the boot JDK
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
let python = import "../python/build.ncl" in # the MakeBase.gmk fix is applied with it
let version = "10+46" in
let amd64_spec =
  {
    name = "openjdk-10",
    build_deps = [
      { file = "build.sh" } | Local,
      { file = "openjdk-10-char-reproducibility.patch" } | Local, # deterministic output
      { file = "openjdk-10-classlist-reproducibility.patch" } | Local, # deterministic output
      { file = "openjdk-10-corba-reproducibility.patch" } | Local, # deterministic output
      { file = "openjdk-10-idlj-reproducibility.patch" } | Local, # deterministic output
      { file = "openjdk-10-module-reproducibility.patch" } | Local, # deterministic output
      { file = "openjdk-10-module3-reproducibility.patch" } | Local, # deterministic output
      { file = "openjdk-10-module4-reproducibility.patch" } | Local, # deterministic output
      { file = "openjdk-10-jar-reproducibility.patch" } | Local, # deterministic output
      { file = "openjdk-10-jtask-reproducibility.patch" } | Local, # deterministic output
      { file = "openjdk-10-pointer-comparison.patch" } | Local, # ordered pointer/integer comparisons gcc 11+ reject
      { file = "openjdk-10-setsignalhandler.patch" } | Local, # a signal-handler prototype gcc 11+ rejects
      { file = "openjdk-currency-time-bomb2.patch" } | Local, # GenerateCurrencyData fails once the data file is older than 10 years
      {
        # https://github.com/openjdk/jdk/archive/refs/tags/jdk-10+46.tar.gz
        url = "gs://minimal-staging-archives/jdk-10+46.tar.gz",
        sha256 = "18aa4b2f73d1b30370991bb4929f49ba19f4c2f87d9710c0fe9de423c818f1ee",
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
      python,
    ],
    cmd = "./build.sh",
    outputs = {
      # consumed by the next rung by absolute path
      prefix = { glob = "usr/lib/openjdk-10/**", allow_executable = true } | OutputData,
      buildinfo = { glob = "usr/share/openjdk-10/BUILDINFO" } | OutputData,
    },
    attrs =
      {
        upstream_version = version,
        license_spdx = "GPL-2.0-only WITH Classpath-exception-2.0",
        build_cost_multiple = 12,
        source_provenance = {
          category = 'Github,
          owner = "openjdk",
          repo = "jdk",
        },
      } | Attrs,
  } | BuildSpec
in
# amd64 only: this rung belongs to the amd64 bootstrap ladder; the spec collapses to an empty collection on arm64.
match {
  { arch = 'Amd64, .. } => amd64_spec,
  { arch = 'Arm64, .. } =>
    {
      name = "openjdk-10",
      build_deps = [],
    } | BuildSpec,
} target
