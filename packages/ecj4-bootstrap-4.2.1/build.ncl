let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# ecj4-bootstrap-4.2.1: one rung of the JVM ladder (jikes-1.22 -> classpath-0.93 -> jamvm-1.5.1 -> ant-bootstrap-1.8.4 -> ecj-bootstrap-3.2.2 -> classpath-0.99 -> classpath-devel -> jamvm-2.0.0 -> ecj4-bootstrap-4.2.1 -> icedtea-7 -> icedtea-8 -> openjdk-9 .. 25).
# Eclipse ecj 4.2.1 (Java 7 language) compiled by ecj 3.2.2 on jamvm-2.0.0 against classpath-devel; ships a javac wrapper (jamvm-2.0.0, -source 1.7). Installs at /usr/lib/ecj4-bootstrap-4.2.1; nothing lands on /usr/bin.
# Sources mirrored to gs://minimal-staging-archives/. No `needs`: nothing here touches the network.
# amd64 only (see the match at the bottom).
let ecj3 = import "../ecj-bootstrap-3.2.2/build.ncl" in # the compiler that builds it
let jamvm2 = import "../jamvm-2.0.0/build.ncl" in
let classpath = import "../classpath-devel/build.ncl" in
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
let unzip = import "../unzip/build.ncl" in
let zip = import "../zip/build.ncl" in
let version = "4.2.1" in
let amd64_spec =
  {
    name = "ecj4-bootstrap-4.2.1",
    build_deps = [
      { file = "build.sh" } | Local,

      {
        # a zip archive of the sources
        url = "gs://minimal-staging-archives/ecjsrc-4.2.1.jar",
        sha256 = "d261b2158f598640f1923805d2e9bf47eb21d8333f4e1b37f59f847ad00d48f4",
        extract = false, # build.sh untars with --no-same-owner
      } | Source,
      ecj3,
      jamvm2,
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
    ],
    cmd = "./build.sh",
    outputs = {
      # consumed by the next rung by absolute path
      prefix = { glob = "usr/lib/ecj4-bootstrap-4.2.1/**", allow_executable = true } | OutputData,
      buildinfo = { glob = "usr/share/ecj4-bootstrap-4.2.1/BUILDINFO" } | OutputData,
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
# amd64 only: this rung belongs to the amd64 bootstrap ladder; the spec collapses to an empty collection on arm64.
match {
  { arch = 'Amd64, .. } => amd64_spec,
  { arch = 'Arm64, .. } =>
    {
      name = "ecj4-bootstrap-4.2.1",
      build_deps = [],
    } | BuildSpec,
} target
