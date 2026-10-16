let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# jikes-1.22: the ROOT of the JVM ladder (jikes-1.22 -> classpath-0.93 -> jamvm-1.5.1 ->
# ant-bootstrap-1.8.4 -> ecj-bootstrap-3.2.2 -> classpath-0.99 -> classpath-devel -> jamvm-2.0.0
# -> ecj4-bootstrap-4.2.1 -> icedtea-7 -> icedtea-8 -> openjdk-9 -> ... -> openjdk-25).
# IBM's Java compiler, written in C++: every JDK's javac is itself Java, so the chain needs one
# Java compiler that is not (Guix's java-bootstrap starts here too). It compiles .java -> .class
# only; it needs a class library (classpath-0.93) and a VM (jamvm) to do anything real.
# Built by gcc-15.2.0-glibc against the glibc-bedrock-2.42 sysroot; installs at /usr/lib/jikes-1.22.
# Source: https://sourceforge.net/projects/jikes/files/Jikes/1.22/jikes-1.22.tar.bz2, mirrored to
# gs://minimal-staging-archives/. No `needs`: nothing here touches the network.
# amd64 only (see the match at the bottom).
let gcc-bedrock = import "../gcc-15.2.0-glibc/build.ncl" in # B5 seed-rooted gcc + g++ + libstdc++
# production binutils: the sealed binutils-2.46-glibc shares sonames (libsframe.so.3) with it in
# /usr/lib, and a mixed pair crashes as
let binutils = import "../binutils/build.ncl" in
let glibc-bedrock = import "../glibc-bedrock-2.42/build.ncl" in # B4 sysroot
let bash = import "../bash/build.ncl" in
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in
let grep = import "../grep/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let tar = import "../tar/build.ncl" in
let bzip2 = import "../bzip2/build.ncl" in # the source is a .tar.bz2
# pkgmgr: bootstrap_rung = "jvm"
let version = "1.22" in
let amd64_spec =
  {
    name = "jikes-1.22",
    build_deps = [
      { file = "build.sh" } | Local,
      {
        url = "gs://minimal-staging-archives/jikes-%{version}.tar.bz2",
        sha256 = "0cb02c763bc441349f6d38cacd52adf762302cce3a08e269f1f75f726e6e14e3",
        extract = false, # build.sh untars with --no-same-owner (chown-hostile sandbox)
      } | Source,
      gcc-bedrock,
      binutils,
      glibc-bedrock,
      bash,
      make,
      sed,
      grep,
      coreutils,
      tar,
      bzip2,
    ],
    build_args = {
      include version,
    },
    # the interpreter is the sysroot's ld.so
    runtime_deps = [
      glibc-bedrock,
    ],
    cmd = "./build.sh",
    outputs = {
      # OutputData + allow_executable, NOT OutputBin: links against the B4 sysroot loader at a
      # non-standard .interp path (the binutils-2.46-glibc / go-1.4 precedent), consumed by the
      # next rung via absolute path, so it must not land on /usr/bin.
      prefix = { glob = "usr/lib/jikes-1.22/**", allow_executable = true } | OutputData,
      buildinfo = { glob = "usr/share/jikes-1.22/BUILDINFO" } | OutputData,
    },
    attrs =
      {
        upstream_version = version,
        source_provenance = {
          category = 'Sourceforge,
          name = "jikes",
        },
      } | Attrs,
  } | BuildSpec
in
# ARCH SCOPE: amd64 only — the hex0-rooted amd64 ladder. On arm64 this collapses to an
# explicitly-EMPTY collection (the go-1.4 precedent): no build runs, nothing ships.
match {
  { arch = 'Amd64, .. } => amd64_spec,
  { arch = 'Arm64, .. } =>
    {
      name = "jikes-1.22",
      build_deps = [],
    } | BuildSpec,
} target
