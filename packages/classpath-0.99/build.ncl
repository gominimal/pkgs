let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# classpath-0.99: one rung of the JVM ladder (jikes-1.22 -> classpath-0.93 -> jamvm-1.5.1 ->
# ant-bootstrap-1.8.4 -> ecj-bootstrap-3.2.2 -> classpath-0.99 -> classpath-devel -> jamvm-2.0.0
# -> ecj4-bootstrap-4.2.1 -> icedtea-7 -> icedtea-8 -> openjdk-9 -> ... -> openjdk-25).
# GNU Classpath 0.99 compiled by ecj-bootstrap-3.2.2 (on jamvm-1.5.1); ships its tools with
# jamvm-run wrappers. Installs at /usr/lib/classpath-0.99; nothing lands on /usr/bin.
# Sources mirrored to gs://minimal-staging-archives/. No `needs`: nothing here touches the network.
# amd64 only (see the match at the bottom).
let ecj-bootstrap-3-2-2 = import "../ecj-bootstrap-3.2.2/build.ncl" in # the javac wrapper + jar
let jamvm-1-5-1 = import "../jamvm-1.5.1/build.ncl" in
let classpath-0-93 = import "../classpath-0.93/build.ncl" in # the wrapper's bootclasspath
let gcc-bedrock = import "../gcc-15.2.0-glibc/build.ncl" in # asserted by build.sh
# production binutils: the sealed binutils-2.46-glibc shares sonames (libsframe.so.3) with it in
# /usr/lib, and a mixed pair crashes as
let binutils = import "../binutils/build.ncl" in
let glibc-bedrock = import "../glibc-bedrock-2.42/build.ncl" in # sysroot
let toolchain = import "../toolchain/build.ncl" in # aarch64: gcc, binutils and glibc, built from the hex0 seed
let glibc = import "../glibc/build.ncl" in
let autoconf = import "../autoconf/build.ncl" in # aarch64: config.sub refresh, autoreconf
let automake = import "../automake/build.ncl" in
let libtool = import "../libtool/build.ncl" in
let m4 = import "../m4/build.ncl" in
let is_arm = target.arch == 'Arm64 in
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
let fastjar = import "../fastjar/build.ncl" in # jar tool
let zip = import "../zip/build.ncl" in
let zlib = import "../zlib/build.ncl" in
let gzip = import "../gzip/build.ncl" in
# pkgmgr: bootstrap_rung = "jvm"
let version = "0.99" in
let amd64_spec = # both arches: the x86_64 inputs or aarch64's, picked by is_arm
  {
    name = "classpath-0.99",
    build_deps =
      [
        (if is_arm then { file = "build-aarch64.sh" } else { file = "build.sh" }) | Local,
        {
          url = "gs://minimal-staging-archives/classpath-0.99.tar.gz",
          sha256 = "f929297f8ae9b613a1a167e231566861893260651d913ad9b6c11933895fecc8",
          extract = false, # build.sh untars with --no-same-owner
        } | Source,
        ecj-bootstrap-3-2-2,
        jamvm-1-5-1,
        classpath-0-93,
      ]
      @ (if is_arm then [toolchain, autoconf, automake, libtool, m4] else [gcc-bedrock, binutils, glibc-bedrock])
      @ [
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
        python,
        gawk,
        diffutils,
      ],
    # the tool wrappers (javah, rmic, …) exec jamvm-1.5.1
    runtime_deps =
      [
        jamvm-1-5-1,
      ]
      @ (if is_arm then [glibc, toolchain] else [glibc-bedrock])
      @ [],
    cmd = if is_arm then "./build-aarch64.sh" else "./build.sh",
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
amd64_spec
