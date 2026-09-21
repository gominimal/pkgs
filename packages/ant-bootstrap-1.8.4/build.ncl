let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# ant-bootstrap-1.8.4: one rung of the JVM ladder (jikes-1.22 -> classpath-0.93 -> jamvm-1.5.1 ->
# ant-bootstrap-1.8.4 -> ecj-bootstrap-3.2.2 -> classpath-0.99 -> classpath-devel -> jamvm-2.0.0
# -> ecj4-bootstrap-4.2.1 -> icedtea-7 -> icedtea-8 -> openjdk-9 -> ... -> openjdk-25).
# Apache Ant 1.8.4 built by jikes and run on jamvm-1.5.1 (bootstrap.sh); its jars feed the ecj
# compiles. Installs at /usr/lib/ant-bootstrap-1.8.4; nothing lands on /usr/bin.
# Sources mirrored to gs://minimal-staging-archives/. No `needs`: nothing here touches the network.
# amd64 only (see the match at the bottom).
let jikes = import "../jikes-1.22/build.ncl" in
let jamvm = import "../jamvm-1.5.1/build.ncl" in
let classpath = import "../classpath-0.93/build.ncl" in
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
let bzip2 = import "../bzip2/build.ncl" in # the source is a .tar.bz2
let version = "1.8.4" in
let amd64_spec =
  {
    name = "ant-bootstrap-1.8.4",
    build_deps = [
      { file = "build.sh" } | Local,

      {
        url = "gs://minimal-staging-archives/apache-ant-1.8.4-src.tar.bz2",
        sha256 = "5de65f7ba3f67e436ffffcdc0a73f591d1006e9fb41af8632c1f1f84d4a3e0b1",
        extract = false, # build.sh untars with --no-same-owner
      } | Source,
      jikes,
      jamvm,
      classpath,
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
      bzip2,
    ],
    cmd = "./build.sh",
    outputs = {
      # consumed by the next rung by absolute path
      prefix = { glob = "usr/lib/ant-bootstrap-1.8.4/**", allow_executable = true } | OutputData,
      buildinfo = { glob = "usr/share/ant-bootstrap-1.8.4/BUILDINFO" } | OutputData,
    },
    attrs =
      {
        upstream_version = version,
        license_spdx = "Apache-2.0",
        build_cost_multiple = 1,
        source_provenance = {
          category = 'Website,
          homepage = "https://ant.apache.org/",
          downloads_page = "https://archive.apache.org/dist/ant/source/",
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
      name = "ant-bootstrap-1.8.4",
      build_deps = [],
    } | BuildSpec,
} target
