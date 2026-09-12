let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# ============================================================================================
# jikes-1.22 — the ROOT of the JVM ladder (minimermetic#89, "JVM ladder: jikes -> OpenJDK 25").
#
#   IS:     /usr/lib/jikes-1.22 — IBM's Java compiler, written in C++ (no Java anywhere in it),
#           built by the seed-rooted B5 gcc against the B4 glibc sysroot.
#   IS NOT: a JVM. jikes only compiles .java -> .class; it needs a class library (GNU Classpath,
#           the next rung) to compile anything real, and a VM (jamvm, rung 3) to run the result.
#
# WHY THIS RUNG IS THE ROOT: every JDK is self-hosted (javac is Java), so the chain needs one
# Java compiler that is NOT Java. jikes is that compiler; Guix's java-bootstrap.scm starts here
# too. The ladder proven on the lab VMs 2026-09-11/12 (bin/queue/jvm-root-probe*.sh in
# minimermetic, every rung JVn_OK):
#   jikes -> classpath-0.93 -> jamvm-1.5.1 -> ant-1.8.4 -> ecj-3.2.2 -> classpath-0.99 ->
#   classpath-devel -> jamvm-2.0.0 -> ecj-4.2.1 -> icedtea-7 -> icedtea-8 -> openjdk-9 ... -> 25
#
# Chain: hex0 -> ... -> gcc-15.2.0-glibc (B5) -> THIS.
#
# ── SOURCE PIN ───────────────────────────────────────────────────────────────────────────────
#   https://sourceforge.net/projects/jikes/files/Jikes/1.22/jikes-1.22.tar.bz2
#     -> gs://minimal-staging-archives/jikes-1.22.tar.bz2
#   sha256 0cb02c763bc441349f6d38cacd52adf762302cce3a08e269f1f75f726e6e14e3  (616655 B)
#   (verified on cg-fresh 2026-09-11, minimermetic docs/jvm-ladder/sources.tsv)
#
# amd64 only (the bedrock ladder's arch; see go-1.4's banner). No `needs`: nothing touches the network.
# ============================================================================================
let gcc-bedrock = import "../gcc-15.2.0-glibc/build.ncl" in # B5 seed-rooted gcc + g++ + libstdc++
let binutils-bedrock = import "../binutils-2.46-glibc/build.ncl" in
let glibc-bedrock = import "../glibc-bedrock-2.42/build.ncl" in # B4 sysroot
let bash = import "../bash/build.ncl" in
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in
let grep = import "../grep/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let tar = import "../tar/build.ncl" in
let bzip2 = import "../bzip2/build.ncl" in # the source is a .tar.bz2
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
      binutils-bedrock,
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
