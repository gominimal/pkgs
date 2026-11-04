let { Attrs, BuildSpec, OutputData, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
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
# openjdk-21: the boot JDK for jdk-21, OpenJDK 21.0.2 from gen-15 of gominimal/bootstrap: the JVM ladder
# jikes -> classpath -> jamvm -> ant/ecj -> icedtea-7/8 -> openjdk-9 ... 21, every rung built from
# source on the hex0-rooted toolchain and reproduced byte for byte on two independent machines
# before publishing (generations/gen-15/manifest.json). Installs at /usr/lib/openjdk-21; nothing lands on
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
          url = "gs://minimal-bootstrap/gen-15/sha256/61288767de3937ae5baf21877b3b3bb2425488d5599a5e1cbbf3baac37e4105c/openjdk-21-21.0.2-x86_64.tar.zst",
          sha256 = "61288767de3937ae5baf21877b3b3bb2425488d5599a5e1cbbf3baac37e4105c",
          extract = true,
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "gs://minimal-bootstrap/gen-15/sha256/8c397907dd69cd4c7991e9843d812353955bf72568f2f96abdd903e65559fe25/openjdk-21-21.0.2-aarch64.tar.zst",
          sha256 = "8c397907dd69cd4c7991e9843d812353955bf72568f2f96abdd903e65559fe25",
          extract = true,
        } | Source,
    } target,
  ],
  # java loads libz; AWT, sound, font and image code load the X libraries, alsa, freetype, lcms2, libpng, giflib and libjpeg
  runtime_deps =
    []
    # amd64 binaries load through glibc's /usr/lib/ld-linux-x86-64.so.2 with no RUNPATH beyond their own
    # $ORIGIN entries; arm64's use the toolchain glibc
    @ (if is_arm then [glibc, toolchain] else [glibc])
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
  # the binary runs from its own runtime closure, outside any build sandbox
  tests = {
    java_version =
      {
        class = 'Standalone,
        cmds = [["/usr/lib/openjdk-21/bin/java", "-version"]],
      } | Test,
  },
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
