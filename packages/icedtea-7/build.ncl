let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# icedtea-7: one rung of the JVM ladder (jikes-1.22 -> classpath-0.93 -> jamvm-1.5.1 ->
# ant-bootstrap-1.8.4 -> ecj-bootstrap-3.2.2 -> classpath-0.99 -> classpath-devel -> jamvm-2.0.0
# -> ecj4-bootstrap-4.2.1 -> icedtea-7 -> icedtea-8 -> openjdk-9 -> ... -> openjdk-25).
# OpenJDK 7u171 via the IcedTea 2.6.13 harness in --enable-bootstrap mode: ecj4-bootstrap-4.2.1 on
# jamvm-2.0.0 with classpath-devel as the "boot JDK" builds an interim JDK, which then builds the
# real one. Installs at /usr/lib/icedtea-7; nothing lands on /usr/bin.
# Sources mirrored to gs://minimal-staging-archives/. No `needs`: nothing here touches the network.
# amd64 only (see the match at the bottom).
let jamvm = import "../jamvm-2.0.0/build.ncl" in # the boot VM
let classpath = import "../classpath-devel/build.ncl" in # the boot class library and its tools (javah, rmic)
let ecj4 = import "../ecj4-bootstrap-4.2.1/build.ncl" in # the boot javac
let ant = import "../ant-bootstrap-1.8.4/build.ncl" in
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
let xz = import "../xz/build.ncl" in # the harness tarball is .xz
let bzip2 = import "../bzip2/build.ncl" in # the drops are .bz2
let gzip = import "../gzip/build.ncl" in
let patch = import "../patch/build.ncl" in
let zip = import "../zip/build.ncl" in
let unzip = import "../unzip/build.ncl" in
let cpio = import "../cpio/build.ncl" in # the image is assembled with cpio -pdum
let file = import "../file/build.ncl" in
let which = import "../which/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in # configure probes lcms2/cups/fontconfig through pkg-config
let libxslt = import "../libxslt/build.ncl" in # xsltproc generates the JVMTI sources
let zlib = import "../zlib/build.ncl" in
let freetype = import "../freetype/build.ncl" in
let cups = import "../cups/build.ncl" in
let alsa-lib = import "../alsa-lib/build.ncl" in
let lcms2 = import "../lcms2/build.ncl" in
let fontconfig = import "../fontconfig/build.ncl" in
let libx11 = import "../libx11/build.ncl" in
let libxext = import "../libxext/build.ncl" in
let libxrender = import "../libxrender/build.ncl" in
let libxtst = import "../libxtst/build.ncl" in
let libxi = import "../libxi/build.ncl" in
let libxinerama = import "../libxinerama/build.ncl" in
let libxcomposite = import "../libxcomposite/build.ncl" in # configure checks for it
let libxt = import "../libxt/build.ncl" in # AWT links -lXt
let xorgproto = import "../xorgproto/build.ncl" in
let version = "2.6.13" in
let amd64_spec =
  {
    name = "icedtea-7",
    build_deps = [
      { file = "build.sh" } | Local,
      { file = "jdk-currency-time-bomb.patch" } | Local, # GenerateCurrencyData fails once the data file is older than 10 years
      { file = "icedtea-7-hotspot-pointer-comparison.patch" } | Local, # ordered pointer/integer comparisons gcc 11+ reject
      {
        # the IcedTea harness: configure, Makefile, boot patches
        url = "gs://minimal-staging-archives/icedtea-2.6.13.tar.xz",
        sha256 = "104e84205d1176e217e24f770784c53d1cd666aeb23ab0bae8ac858e5b0e63f0",
        extract = false, # build.sh untars with --no-same-owner
      } | Source,
      {
        # the openjdk drop, upstream basename openjdk.tar.bz2
        url = "gs://minimal-staging-archives/icedtea7-2.6.13-openjdk.tar.bz2",
        sha256 = "14a9f90e2fe5c0bb73dc8ffcc9ea5dc76d3ce7a74a0c901cfd0b0ae3fc8c6450",
        extract = false, # build.sh untars with --no-same-owner
      } | Source,
      {
        # the corba drop, upstream basename corba.tar.bz2
        url = "gs://minimal-staging-archives/icedtea7-2.6.13-corba.tar.bz2",
        sha256 = "df1154915cad317b93555b563fc12acad1b92e5f2870642736f186b7a4d80f14",
        extract = false, # build.sh untars with --no-same-owner
      } | Source,
      {
        # the jaxp drop, upstream basename jaxp.tar.bz2
        url = "gs://minimal-staging-archives/icedtea7-2.6.13-jaxp.tar.bz2",
        sha256 = "143a5b957fbb00889ff9d38a4bf391218786b6a33664235279edbb6e79a3decc",
        extract = false, # build.sh untars with --no-same-owner
      } | Source,
      {
        # the jaxws drop, upstream basename jaxws.tar.bz2
        url = "gs://minimal-staging-archives/icedtea7-2.6.13-jaxws.tar.bz2",
        sha256 = "d3e3d55d6e2231c4420d30d124f72c56695d45e8a398e3cc7ba21ff2a93c1284",
        extract = false, # build.sh untars with --no-same-owner
      } | Source,
      {
        # the jdk drop, upstream basename jdk.tar.bz2
        url = "gs://minimal-staging-archives/icedtea7-2.6.13-jdk.tar.bz2",
        sha256 = "adbda93d1e9be89447e009733a6c9050c6e6cebda3c674a76ebbeb8986623534",
        extract = false, # build.sh untars with --no-same-owner
      } | Source,
      {
        # the langtools drop, upstream basename langtools.tar.bz2
        url = "gs://minimal-staging-archives/icedtea7-2.6.13-langtools.tar.bz2",
        sha256 = "12036b985f8811cdadf6d5bf840f90bab25f4da1cc3e86bab9c3f6efcc10055b",
        extract = false, # build.sh untars with --no-same-owner
      } | Source,
      {
        # the hotspot drop, upstream basename hotspot.tar.bz2
        url = "gs://minimal-staging-archives/icedtea7-2.6.13-hotspot.tar.bz2",
        sha256 = "9ae3d6d43ff771cf02b8c7805ac0f0a457f5fa7026b1334ea1085262d3d86d9d",
        extract = false, # build.sh untars with --no-same-owner
      } | Source,
      jamvm,
      classpath,
      ecj4,
      ant,
      gcc-bedrock,
      binutils-bedrock,
      glibc-bedrock,
      bash,
      make,
      sed,
      grep,
      gawk,
      coreutils,
      findutils,
      diffutils,
      tar,
      xz,
      bzip2,
      gzip,
      patch,
      zip,
      unzip,
      cpio,
      file,
      which,
      pkgconf,
      libxslt,
      zlib,
      freetype,
      cups,
      alsa-lib,
      lcms2,
      fontconfig,
      libx11,
      libxext,
      libxrender,
      libxtst,
      libxi,
      libxinerama,
      libxcomposite,
      libxt,
      xorgproto,
      python,
    ],
    cmd = "./build.sh",
    outputs = {
      # consumed by the next rung by absolute path
      prefix = { glob = "usr/lib/icedtea-7/**", allow_executable = true } | OutputData,
      buildinfo = { glob = "usr/share/icedtea-7/BUILDINFO" } | OutputData,
    },
    attrs =
      {
        upstream_version = version,
        license_spdx = "GPL-2.0-only WITH Classpath-exception-2.0",
        build_cost_multiple = 12,
        source_provenance = {
          category = 'Website,
          homepage = "https://icedtea.classpath.org/",
          downloads_page = "https://icedtea.classpath.org/download/source/",
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
      name = "icedtea-7",
      build_deps = [],
    } | BuildSpec,
} target
