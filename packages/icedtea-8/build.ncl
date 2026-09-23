let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# icedtea-8: one rung of the JVM ladder (jikes-1.22 -> classpath-0.93 -> jamvm-1.5.1 ->
# ant-bootstrap-1.8.4 -> ecj-bootstrap-3.2.2 -> classpath-0.99 -> classpath-devel -> jamvm-2.0.0
# -> ecj4-bootstrap-4.2.1 -> icedtea-7 -> icedtea-8 -> openjdk-9 -> ... -> openjdk-25).
# OpenJDK 8u292 via the IcedTea 3.19.0 harness in --enable-bootstrap mode, with ../icedtea-7 as
# the boot JDK. Installs at /usr/lib/icedtea-8; nothing lands on /usr/bin.
# Sources mirrored to gs://minimal-staging-archives/. No `needs`: nothing here touches the network.
# amd64 only (see the match at the bottom).
let jdk7 = import "../icedtea-7/build.ncl" in # the boot JDK
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
let gawk = import "../gawk/build.ncl" in # configure scripts and config.status
let diffutils = import "../diffutils/build.ncl" in
let xz = import "../xz/build.ncl" in # the harness and the drops are .xz
let gzip = import "../gzip/build.ncl" in
let patch = import "../patch/build.ncl" in
let zip = import "../zip/build.ncl" in
let unzip = import "../unzip/build.ncl" in
let cpio = import "../cpio/build.ncl" in
let file = import "../file/build.ncl" in
let which = import "../which/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let libxslt = import "../libxslt/build.ncl" in # xsltproc generates the JVMTI sources
let wget = import "../wget/build.ncl" in # configure insists it is on PATH, even with --disable-downloading
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
let libxrandr = import "../libxrandr/build.ncl" in
let libxcomposite = import "../libxcomposite/build.ncl" in
let libxt = import "../libxt/build.ncl" in
let xorgproto = import "../xorgproto/build.ncl" in
let version = "3.19.0" in
let amd64_spec =
  {
    name = "icedtea-8",
    build_deps = [
      { file = "build.sh" } | Local,
      { file = "jdk-currency-time-bomb2.patch" } | Local, # GenerateCurrencyData fails once the data file is older than 10 years
      {
        # the IcedTea harness
        url = "gs://minimal-staging-archives/icedtea-3.19.0.tar.xz",
        sha256 = "eed61e51ba35635b2292a6e67404d5e3f4bf7cc5d69bc1b81f5b69b1d8d1b5b2",
        extract = false, # build.sh untars with --no-same-owner
      } | Source,
      {
        # the openjdk drop, upstream basename openjdk.tar.xz
        url = "gs://minimal-staging-archives/icedtea8-3.19.0-openjdk.tar.xz",
        sha256 = "c9d0f566a2cf9d4150a16b7c68b07ccdeeb317b7d055c56f671a0d3d5afd6bd0",
        extract = false, # build.sh untars with --no-same-owner
      } | Source,
      {
        # the aarch32 drop, upstream basename aarch32.tar.xz
        url = "gs://minimal-staging-archives/icedtea8-3.19.0-aarch32.tar.xz",
        sha256 = "f852d17ae09047f2432604422e9e58ec6473eceabe8b217320928e3ee2e58d4c",
        extract = false, # build.sh untars with --no-same-owner
      } | Source,
      {
        # the corba drop, upstream basename corba.tar.xz
        url = "gs://minimal-staging-archives/icedtea8-3.19.0-corba.tar.xz",
        sha256 = "19b87e02b27a7312fa0835660159bee55a9e8867fd0013dc36acc057dc331076",
        extract = false, # build.sh untars with --no-same-owner
      } | Source,
      {
        # the jaxp drop, upstream basename jaxp.tar.xz
        url = "gs://minimal-staging-archives/icedtea8-3.19.0-jaxp.tar.xz",
        sha256 = "b9d78eec0ae71332b61e44f71bcf991d3af60663028fdb10bdb1c497cb186f10",
        extract = false, # build.sh untars with --no-same-owner
      } | Source,
      {
        # the jaxws drop, upstream basename jaxws.tar.xz
        url = "gs://minimal-staging-archives/icedtea8-3.19.0-jaxws.tar.xz",
        sha256 = "197053d93fc478adf0645577e85feca004b1496a29dc0d98acc256b1c9be80dd",
        extract = false, # build.sh untars with --no-same-owner
      } | Source,
      {
        # the jdk drop, upstream basename jdk.tar.xz
        url = "gs://minimal-staging-archives/icedtea8-3.19.0-jdk.tar.xz",
        sha256 = "3bc3dcaa1f9d109ed99139e1108a691964c68ad90375214a841fd1522aa3829c",
        extract = false, # build.sh untars with --no-same-owner
      } | Source,
      {
        # the langtools drop, upstream basename langtools.tar.xz
        url = "gs://minimal-staging-archives/icedtea8-3.19.0-langtools.tar.xz",
        sha256 = "0b94950c68153862c315e1aae62de58a95bc9487ea197723bcb435d6c53d3f22",
        extract = false, # build.sh untars with --no-same-owner
      } | Source,
      {
        # the hotspot drop, upstream basename hotspot.tar.xz
        url = "gs://minimal-staging-archives/icedtea8-3.19.0-hotspot.tar.xz",
        sha256 = "a2417711339f3c1bb3b32612022e331fe090037b11ef98d989c1fab1acebcab9",
        extract = false, # build.sh untars with --no-same-owner
      } | Source,
      {
        # the nashorn drop, upstream basename nashorn.tar.xz
        url = "gs://minimal-staging-archives/icedtea8-3.19.0-nashorn.tar.xz",
        sha256 = "2451e97fe9b4c3d14859170c9621ce1323075e97f6148890ba3644512f3bd695",
        extract = false, # build.sh untars with --no-same-owner
      } | Source,
      {
        # the shenandoah drop, upstream basename shenandoah.tar.xz
        url = "gs://minimal-staging-archives/icedtea8-3.19.0-shenandoah.tar.xz",
        sha256 = "d81606795abe5721d54aef6413677845a24c5b2202414a095bd04f1fba945fca",
        extract = false, # build.sh untars with --no-same-owner
      } | Source,
      jdk7,
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
      gzip,
      patch,
      zip,
      unzip,
      cpio,
      file,
      which,
      pkgconf,
      libxslt,
      wget,
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
      libxrandr,
      libxcomposite,
      libxt,
      xorgproto,
      python,
    ],
    cmd = "./build.sh",
    outputs = {
      # consumed by the next rung by absolute path
      prefix = { glob = "usr/lib/icedtea-8/**", allow_executable = true } | OutputData,
      buildinfo = { glob = "usr/share/icedtea-8/BUILDINFO" } | OutputData,
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
      name = "icedtea-8",
      build_deps = [],
    } | BuildSpec,
} target
