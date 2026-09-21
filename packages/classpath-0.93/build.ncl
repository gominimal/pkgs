let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# classpath-0.93: one rung of the JVM ladder (jikes-1.22 -> classpath-0.93 -> jamvm-1.5.1 ->
# ant-bootstrap-1.8.4 -> ecj-bootstrap-3.2.2 -> classpath-0.99 -> classpath-devel -> jamvm-2.0.0
# -> ecj4-bootstrap-4.2.1 -> icedtea-7 -> icedtea-8 -> openjdk-9 -> ... -> openjdk-25).
# GNU Classpath 0.93 (the class library), compiled by jikes; the C parts by the sysroot gcc.
# Installs at /usr/lib/classpath-0.93; nothing lands on /usr/bin.
# Sources mirrored to gs://minimal-staging-archives/. No `needs`: nothing here touches the network.
# amd64 only (see the match at the bottom).
let jikes = import "../jikes-1.22/build.ncl" in # JAVAC
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
let zip = import "../zip/build.ncl" in # glibj.zip is a zip archive
let zlib = import "../zlib/build.ncl" in # java.util.zip
let gzip = import "../gzip/build.ncl" in
let version = "0.93" in
let amd64_spec =
  {
    name = "classpath-0.93",
    build_deps = [
      { file = "build.sh" } | Local,

      {
        url = "gs://minimal-staging-archives/classpath-0.93.tar.gz",
        sha256 = "df2d093612abd23fe67e9409d89bb2a8e79b1664fe2b2da40e1c8ed693e32945",
        extract = false, # build.sh untars with --no-same-owner
      } | Source,
      jikes,
      gcc-bedrock,
      binutils-bedrock,
      glibc-bedrock,
      zip,
      zlib,
      bash,
      make,
      sed,
      grep,
      coreutils,
      findutils,
      tar,
      gzip,
    ],
    cmd = "./build.sh",
    outputs = {
      # consumed by the next rung by absolute path
      prefix = { glob = "usr/lib/classpath-0.93/**", allow_executable = true } | OutputData,
      buildinfo = { glob = "usr/share/classpath-0.93/BUILDINFO" } | OutputData,
    },
    attrs =
      {
        upstream_version = version,
        license_spdx = "GPL-2.0-or-later WITH Classpath-exception-2.0",
        build_cost_multiple = 2,
        source_provenance = {
          category = 'GnuProject,
          name = "classpath",
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
      name = "classpath-0.93",
      build_deps = [],
    } | BuildSpec,
} target
