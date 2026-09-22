let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# jamvm-2.0.0: one rung of the JVM ladder (jikes-1.22 -> classpath-0.93 -> jamvm-1.5.1 ->
# ant-bootstrap-1.8.4 -> ecj-bootstrap-3.2.2 -> classpath-0.99 -> classpath-devel -> jamvm-2.0.0
# -> ecj4-bootstrap-4.2.1 -> icedtea-7 -> icedtea-8 -> openjdk-9 -> ... -> openjdk-25).
# JamVM 2.0.0 against classpath-devel, its own class-library glue compiled by ecj-bootstrap-3.2.2;
# two upstream-derived patches. Installs at /usr/lib/jamvm-2.0.0; nothing lands on /usr/bin.
# Sources mirrored to gs://minimal-staging-archives/. No `needs`: nothing here touches the network.
# amd64 only (see the match at the bottom).
let ecj = import "../ecj-bootstrap-3.2.2/build.ncl" in # JAVAC
let classpath = import "../classpath-devel/build.ncl" in
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
let libffi = import "../libffi/build.ncl" in # --enable-ffi
let patch = import "../patch/build.ncl" in
let gzip = import "../gzip/build.ncl" in
let zip = import "../zip/build.ncl" in # classes.zip
let version = "2.0.0" in
let amd64_spec =
  {
    name = "jamvm-2.0.0",
    build_deps = [
      { file = "build.sh" } | Local,
      { file = "jamvm-2.0.0-disable-branch-patching.patch" } | Local, # the JIT-less interpreter's branch patching is not thread-safe on modern CPUs
      { file = "jamvm-2.0.0-guard-fp-opcodes.patch" } | Local, # floating-point opcodes guarded when the FPU flags are not what 2014 assumed
      {
        url = "gs://minimal-staging-archives/jamvm-2.0.0.tar.gz",
        sha256 = "76428e96df0ae9dd964c7a7c74c1e9a837e2f312c39e9a357fa8178f7eff80da",
        extract = false, # build.sh untars with --no-same-owner
      } | Source,
      ecj,
      classpath,
      gcc-bedrock,
      binutils-bedrock,
      glibc-bedrock,
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
    ],
    cmd = "./build.sh",
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
# amd64 only: this rung belongs to the amd64 bootstrap ladder; the spec collapses to an empty
# collection on arm64.
match {
  { arch = 'Amd64, .. } => amd64_spec,
  { arch = 'Arm64, .. } =>
    {
      name = "jamvm-2.0.0",
      build_deps = [],
    } | BuildSpec,
} target
