let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# jamvm-1.5.1: one rung of the JVM ladder (jikes-1.22 -> classpath-0.93 -> jamvm-1.5.1 ->
# ant-bootstrap-1.8.4 -> ecj-bootstrap-3.2.2 -> classpath-0.99 -> classpath-devel -> jamvm-2.0.0
# -> ecj4-bootstrap-4.2.1 -> icedtea-7 -> icedtea-8 -> openjdk-9 -> ... -> openjdk-25).
# JamVM 1.5.1, a C JVM, against classpath-0.93. Installs at /usr/lib/jamvm-1.5.1; nothing lands on
# /usr/bin.
# Sources mirrored to gs://minimal-staging-archives/. No `needs`: nothing here touches the network.
# amd64 only (see the match at the bottom).
let classpath = import "../classpath-0.93/build.ncl" in # the class library
let jikes = import "../jikes-1.22/build.ncl" in # the gate compiles with it
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
let zlib = import "../zlib/build.ncl" in
let gzip = import "../gzip/build.ncl" in
let zip = import "../zip/build.ncl" in # classes.zip
let version = "1.5.1" in
let amd64_spec =
  {
    name = "jamvm-1.5.1",
    build_deps = [
      { file = "build.sh" } | Local,

      {
        url = "gs://minimal-staging-archives/jamvm-1.5.1.tar.gz",
        sha256 = "663895bd69caf3a1fda6af5eea8263d90a5fd35ca8f4c32e2210ac410788901a",
        extract = false, # build.sh untars with --no-same-owner
      } | Source,
      classpath,
      jikes,
      gcc-bedrock,
      binutils-bedrock,
      glibc-bedrock,
      zlib,
      zip,
      bash,
      make,
      sed,
      grep,
      coreutils,
      findutils,
      tar,
      gzip,
      python,
    ],
    cmd = "./build.sh",
    outputs = {
      # consumed by the next rung by absolute path
      prefix = { glob = "usr/lib/jamvm-1.5.1/**", allow_executable = true } | OutputData,
      buildinfo = { glob = "usr/share/jamvm-1.5.1/BUILDINFO" } | OutputData,
    },
    attrs =
      {
        upstream_version = version,
        license_spdx = "GPL-2.0-or-later",
        build_cost_multiple = 1,
        source_provenance = {
          category = 'Sourceforge,
          name = "jamvm",
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
      name = "jamvm-1.5.1",
      build_deps = [],
    } | BuildSpec,
} target
