let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# classpath-0.99: one rung of the JVM ladder (jikes-1.22 -> classpath-0.93 -> jamvm-1.5.1 -> ant-
# bootstrap-1.8.4 -> ecj-bootstrap-3.2.2 -> classpath-0.99 -> classpath-devel -> jamvm-2.0.0 ->
# ecj4-bootstrap-4.2.1 -> icedtea-7 -> icedtea-8 -> openjdk-9 -> ... -> openjdk-25).
# GNU Classpath 0.99 compiled by ecj-bootstrap-3.2.2 (on jamvm-1.5.1); ships its tools with jamvm-
# run wrappers. Installs at /usr/lib/classpath-0.99; nothing lands on /usr/bin.
# Sources mirrored to gs://minimal-staging-archives/. No `needs`: nothing here touches the network.
# amd64 only (see the match at the bottom).
let ecj = import "../ecj-bootstrap-3.2.2/build.ncl" in # the javac wrapper + jar
let jamvm = import "../jamvm-1.5.1/build.ncl" in
let classpath93 = import "../classpath-0.93/build.ncl" in # the wrapper's bootclasspath
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
let fastjar = import "../fastjar/build.ncl" in # jar tool
let zip = import "../zip/build.ncl" in
let zlib = import "../zlib/build.ncl" in
let gzip = import "../gzip/build.ncl" in
let version = "0.99" in
let amd64_spec =
  {
    name = "classpath-0.99",
    build_deps = [
      { file = "build.sh" } | Local,

      {
        url = "gs://minimal-staging-archives/classpath-0.99.tar.gz",
        sha256 = "f929297f8ae9b613a1a167e231566861893260651d913ad9b6c11933895fecc8",
        extract = false, # build.sh untars with --no-same-owner
      } | Source,
      ecj,
      jamvm,
      classpath93,
      gcc-bedrock,
      binutils-bedrock,
      glibc-bedrock,
      fastjar,
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
      prefix = { glob = "usr/lib/classpath-0.99/**", allow_executable = true } | OutputData,
      buildinfo = { glob = "usr/share/classpath-0.99/BUILDINFO" } | OutputData,
    },
    attrs =
      {
        upstream_version = version,
        license_spdx = "GPL-2.0-or-later WITH Classpath-exception-2.0",
        build_cost_multiple = 3,
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
      name = "classpath-0.99",
      build_deps = [],
    } | BuildSpec,
} target
