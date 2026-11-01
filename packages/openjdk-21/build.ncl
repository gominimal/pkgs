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
let libxcursor = import "../libxcursor/build.ncl" in
# openjdk-21: the boot JDK for jdk-21, OpenJDK 21.0.2 from gen-5 of gominimal/bootstrap: the JVM ladder
# jikes -> classpath -> jamvm -> ant/ecj -> icedtea-7/8 -> openjdk-9 ... 21, every rung built from
# source on the hex0-rooted toolchain and reproduced byte for byte on two independent machines
# before publishing (generations/gen-5/manifest.json). Installs at /usr/lib/openjdk-21; nothing lands on
# /usr/bin.
let is_arm = target.arch == 'Arm64 in
let version = "21.0.2" in
{
  name = "openjdk-21",
  prebuilt = true,
  build_deps = [
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "gs://minimal-bootstrap/gen-5/sha256/a3a6363f83e7721526ec869f8ca7d13db3f201716f450acce575b1dfa82a8394/openjdk-21-21.0.2-x86_64.tar.zst",
          sha256 = "a3a6363f83e7721526ec869f8ca7d13db3f201716f450acce575b1dfa82a8394",
          extract = true,
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "gs://minimal-bootstrap/gen-5/sha256/99bb530e34312eecd82fbb22ad6f2da710767ff62bf02006eeadeb0366cacfa0/openjdk-21-21.0.2-aarch64.tar.zst",
          sha256 = "99bb530e34312eecd82fbb22ad6f2da710767ff62bf02006eeadeb0366cacfa0",
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
      libxcursor,
    ],
  outputs = {
    prefix = { glob = "usr/lib/openjdk-21/**", allow_executable = true } | OutputData,
    buildinfo = { glob = "usr/share/openjdk-21/BUILDINFO" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-2.0-only WITH Classpath-exception-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "openjdk",
        repo = "jdk21u",
      },
    } | Attrs,
} | BuildSpec
