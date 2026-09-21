let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# openjdk-22: one rung of the JVM ladder (jikes-1.22 -> classpath-0.93 -> jamvm-1.5.1 ->
# ant-bootstrap-1.8.4 -> ecj-bootstrap-3.2.2 -> classpath-0.99 -> classpath-devel -> jamvm-2.0.0
# -> ecj4-bootstrap-4.2.1 -> icedtea-7 -> icedtea-8 -> openjdk-9 -> ... -> openjdk-25).
# OpenJDK 22.0.2 from the GitHub tag archive, built with ../openjdk-21 as the boot JDK. Installs
# at /usr/lib/openjdk-22; nothing lands on /usr/bin.
# Sources mirrored to gs://minimal-staging-archives/. No `needs`: nothing here touches the network.
# amd64 only (see the match at the bottom).
let boot = import "../openjdk-21/build.ncl" in # the boot JDK
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
let libxcursor = import "../libxcursor/build.ncl" in # linked since the xcursor patch
let version = "22.0.2" in
let amd64_spec =
  {
    name = "openjdk-22",
    build_deps = [
      { file = "build.sh" } | Local,
      { file = "openjdk-15-xcursor-no-dynamic.patch" } | Local, # link libXcursor instead of dlopen()ing it by bare name
      {
        # https://github.com/openjdk/jdk22u/archive/refs/tags/jdk-22.0.2-ga.tar.gz
        url = "gs://minimal-staging-archives/jdk-22.0.2-ga.tar.gz",
        sha256 = "c423015bda77bea13e0a13f4dc705972c2185c3c6e6e30b183f733f2b95aa1a4",
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
      libxcursor,
    ],
    cmd = "./build.sh",
    outputs = {
      # consumed by the next rung by absolute path
      prefix = { glob = "usr/lib/openjdk-22/**", allow_executable = true } | OutputData,
      buildinfo = { glob = "usr/share/openjdk-22/BUILDINFO" } | OutputData,
    },
    attrs =
      {
        upstream_version = version,
        license_spdx = "GPL-2.0-only WITH Classpath-exception-2.0",
        build_cost_multiple = 12,
        source_provenance = {
          category = 'GithubRepo,
          owner = "openjdk",
          repo = "jdk22u",
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
      name = "openjdk-22",
      build_deps = [],
    } | BuildSpec,
} target
