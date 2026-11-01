let { Attrs, BuildSpec, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let glibc-bedrock-2-42-sysroot = import "../glibc-bedrock-2.42-sysroot/build.ncl" in # the sysroot only (see that package)
let glibc = import "../glibc/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let zlib = import "../zlib/build.ncl" in
let freetype = import "../freetype/build.ncl" in
let libpng = import "../libpng/build.ncl" in
let giflib = import "../giflib/build.ncl" in
let libjpeg-turbo = import "../libjpeg-turbo/build.ncl" in
let lcms2 = import "../lcms2/build.ncl" in
let alsa-lib = import "../alsa-lib/build.ncl" in
let libx11 = import "../libx11/build.ncl" in
let libxext = import "../libxext/build.ncl" in
let libxi = import "../libxi/build.ncl" in
let libxrender = import "../libxrender/build.ncl" in
let libxtst = import "../libxtst/build.ncl" in
# openjdk-26: the boot JDK for jdk-27, OpenJDK 26.0.2.1 from gen-5 of gominimal/bootstrap: the JVM ladder
# jikes -> classpath -> jamvm -> ant/ecj -> icedtea-7/8 -> openjdk-9 ... 26, every rung built from
# source on the hex0-rooted toolchain and reproduced byte for byte on two independent machines
# before publishing (generations/gen-5/manifest.json). Installs at /usr/lib/openjdk-26; nothing lands on
# /usr/bin.
let is_arm = target.arch == 'Arm64 in
let version = "26.0.2.1" in
{
  name = "openjdk-26",
  prebuilt = true,
  build_deps = [
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "gs://minimal-bootstrap/gen-5/sha256/1d30b582ba33fb56d4e3dbba37b39d7d39ed0aa72121d4a083c10653c2c2f7be/openjdk-26-26.0.2.1-x86_64.tar.zst",
          sha256 = "1d30b582ba33fb56d4e3dbba37b39d7d39ed0aa72121d4a083c10653c2c2f7be",
          extract = true,
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "gs://minimal-bootstrap/gen-5/sha256/7c817908066a6076d7969e1a9f37ccb749be84213a64a6165dc2626196d051fb/openjdk-26-26.0.2.1-aarch64.tar.zst",
          sha256 = "7c817908066a6076d7969e1a9f37ccb749be84213a64a6165dc2626196d051fb",
          extract = true,
        } | Source,
    } target,
  ],
  # java loads libz; AWT, sound, font and image code load the X libraries, alsa, freetype, lcms2, libpng, giflib and libjpeg
  runtime_deps =
    []
    @ (if is_arm then [glibc, toolchain] else [glibc-bedrock-2-42-sysroot])
    @ [
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
  outputs = {
    prefix = { glob = "usr/lib/openjdk-26/**", allow_executable = true } | OutputData,
    buildinfo = { glob = "usr/share/openjdk-26/BUILDINFO" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-2.0-only WITH Classpath-exception-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "openjdk",
        repo = "jdk26u",
      },
    } | Attrs,
} | BuildSpec
