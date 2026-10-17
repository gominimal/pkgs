let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# jamvm-2.0.0: one rung of the JVM ladder (jikes-1.22 -> classpath-0.93 -> jamvm-1.5.1 ->
# ant-bootstrap-1.8.4 -> ecj-bootstrap-3.2.2 -> classpath-0.99 -> classpath-devel -> jamvm-2.0.0
# -> ecj4-bootstrap-4.2.1 -> icedtea-7 -> icedtea-8 -> openjdk-9 -> ... -> openjdk-25).
# JamVM 2.0.0 against classpath-devel, its own class-library glue compiled by ecj-bootstrap-3.2.2;
# two upstream-derived patches. Installs at /usr/lib/jamvm-2.0.0; nothing lands on /usr/bin.
# Sources mirrored to gs://minimal-staging-archives/. No `needs`: nothing here touches the network.
# amd64 only (see the match at the bottom).
let ecj-bootstrap-3-2-2 = import "../ecj-bootstrap-3.2.2/build.ncl" in # JAVAC
let jamvm-1-5-1 = import "../jamvm-1.5.1/build.ncl" in # runs the boot javac
let classpath-0-93 = import "../classpath-0.93/build.ncl" in # jamvm-1.5.1 boots from it
let classpath-devel = import "../classpath-devel/build.ncl" in
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
let zlib = import "../zlib/build.ncl" in
let libffi = import "../libffi/build.ncl" in # --enable-ffi
let patch = import "../patch/build.ncl" in
let gzip = import "../gzip/build.ncl" in
let zip = import "../zip/build.ncl" in # classes.zip
# pkgmgr: bootstrap_rung = "jvm"
let version = "2.0.0" in
let amd64_spec = # both arches: the x86_64 inputs or aarch64's, picked by is_arm
  {
    name = "jamvm-2.0.0",
    build_deps =
      [
        (if is_arm then { file = "build-aarch64.sh" } else { file = "build.sh" }) | Local,
      ]
      @ (if is_arm then [{ file = "jamvm-2.0.0-aarch64-support.patch" } | Local] else [])
      @ [
        { file = "jamvm-2.0.0-disable-branch-patching.patch" } | Local, # the JIT-less interpreter's branch patching is not thread-safe on modern CPUs
        { file = "jamvm-2.0.0-guard-fp-opcodes.patch" } | Local, # floating-point opcodes guarded when the FPU flags are not what 2014 assumed
        {
          url = "gs://minimal-staging-archives/jamvm-2.0.0.tar.gz",
          sha256 = "76428e96df0ae9dd964c7a7c74c1e9a837e2f312c39e9a357fa8178f7eff80da",
          extract = false, # build.sh untars with --no-same-owner
        } | Source,
        ecj-bootstrap-3-2-2,
        jamvm-1-5-1,
        classpath-0-93,
        classpath-devel,
      ]
      @ (if is_arm then [toolchain, autoconf, automake, libtool, m4] else [gcc-bedrock, binutils, glibc-bedrock])
      @ [
        zlib,
        libffi,
        zip,
        patch,
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
    # the VM is configured for classpath-devel; links libz and libffi
    runtime_deps =
      [
        classpath-devel,
      ]
      @ (if is_arm then [glibc, toolchain] else [glibc-bedrock])
      @ [
        zlib,
        libffi,
      ],
    cmd = if is_arm then "./build-aarch64.sh" else "./build.sh",
    outputs = {
      # consumed by the next rung by absolute path
      prefix = { glob = "usr/lib/jamvm-2.0.0/**", allow_executable = true } | OutputData,
      buildinfo = { glob = "usr/share/jamvm-2.0.0/BUILDINFO" } | OutputData,
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
amd64_spec
