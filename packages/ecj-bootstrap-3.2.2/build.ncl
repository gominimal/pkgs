let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# ecj-bootstrap-3.2.2: one rung of the JVM ladder (jikes-1.22 -> classpath-0.93 -> jamvm-1.5.1 ->
# ant-bootstrap-1.8.4 -> ecj-bootstrap-3.2.2 -> classpath-0.99 -> classpath-devel -> jamvm-2.0.0
# -> ecj4-bootstrap-4.2.1 -> icedtea-7 -> icedtea-8 -> openjdk-9 -> ... -> openjdk-25).
# Eclipse ecj 3.2.2 compiled by jikes: the first Java-written Java compiler in the chain, shipped
# with a javac-compatible wrapper that runs it on jamvm-1.5.1. Installs at
# /usr/lib/ecj-bootstrap-3.2.2; nothing lands on /usr/bin.
# Sources mirrored to gs://minimal-staging-archives/. No `needs`: nothing here touches the network.
# amd64 only (see the match at the bottom).
let jikes = import "../jikes-1.22/build.ncl" in
let jamvm = import "../jamvm-1.5.1/build.ncl" in # runs the wrapper
let classpath = import "../classpath-0.93/build.ncl" in
let ant = import "../ant-bootstrap-1.8.4/build.ncl" in # on the compile classpath
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
let unzip = import "../unzip/build.ncl" in
let zip = import "../zip/build.ncl" in
let version = "3.2.2" in
let amd64_spec =
  {
    name = "ecj-bootstrap-3.2.2",
    build_deps = [
      { file = "build.sh" } | Local,

      {
        url = "gs://minimal-staging-archives/ecjsrc-3.2.2.zip",
        sha256 = "070cd425f5324349073c8ea9a3a0d43166429264584da9e9537888d6a7401216",
        extract = false, # build.sh untars with --no-same-owner
      } | Source,
      jikes,
      jamvm,
      classpath,
      ant,
      gcc-bedrock,
      binutils-bedrock,
      glibc-bedrock,
      unzip,
      zip,
      bash,
      make,
      sed,
      grep,
      coreutils,
      findutils,
      tar,
      python,
      gawk,
      diffutils,
    ],
    cmd = "./build.sh",
    outputs = {
      # consumed by the next rung by absolute path
      prefix = { glob = "usr/lib/ecj-bootstrap-3.2.2/**", allow_executable = true } | OutputData,
      buildinfo = { glob = "usr/share/ecj-bootstrap-3.2.2/BUILDINFO" } | OutputData,
    },
    attrs =
      {
        upstream_version = version,
        license_spdx = "EPL-1.0",
        build_cost_multiple = 1,
        source_provenance = {
          category = 'Website,
          homepage = "https://www.eclipse.org/jdt/",
          downloads_page = "https://archive.eclipse.org/eclipse/downloads/",
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
      name = "ecj-bootstrap-3.2.2",
      build_deps = [],
    } | BuildSpec,
} target
