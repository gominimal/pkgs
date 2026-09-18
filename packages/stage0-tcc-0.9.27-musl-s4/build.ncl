let { BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# stage0-tcc-0.9.27-musl-s4: correctness gate for s3's tcc-musl2. tcc-musl2 was produced by a
# mes-linked compiler that can emit a wrong-but-running binary, so before it is used as CC by
# stage0-binutils-2.30 and stage0-gcc-4.0.4 it must pass:
#   fixed point: tcc-musl2 -> tcc-musl3 -> tcc-musl4 with identical flags; sha(musl3) == sha(musl4).
#   torture: each torture/*.c compiled with the fixed-point compiler runs with exit 0 and stdout
#     equal to *.expected (register/stack args, varargs, structs, long long, shifts, static-PLT
#     cross-object calls, float via musl strtod/printf).
# The sealed output is tcc-musl3's bytes under the name tcc-musl2. Nothing is written to the
# output tree unless every gate passes. A failure here is deterministic (tcc-musl2 is
# musl-linked), so the fix is a fresh s3 build, not a retry of s4.
# Link target is stage0-musl-1.1.24-cc2's single-writer sysroot, not the merged /usr.
let stage0-musl-1-1-24-cc2 = import "../stage0-musl-1.1.24-cc2/build.ncl" in # musl libc.a + crt + headers (link target)
let stage0-tcc-0-9-27-musl-s3 = import "../stage0-tcc-0.9.27-musl-s3/build.ncl" in # tcc-musl2 (candidate) + libtcc1.a
let bash = import "../bash/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let tar = import "../tar/build.ncl" in
let gzip = import "../gzip/build.ncl" in
let sed = import "../sed/build.ncl" in
let grep = import "../grep/build.ncl" in
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in
let amd64_spec =
  {
    name = "stage0-tcc-0.9.27-musl-s4",
    build_deps = [
      { file = "build.sh" } | Local,
      {
        # the same tcc source tarball s3 built from; the fixed-point recompile must use the same tcc.c.
        url = "gs://minimal-staging-archives/tccsrc-r3gotABC.tar.gz",
        sha256 = "4267860f408f2df455116bc7e7ee9cee874cc81339841d0760a2a0261803ae79",
        extract = false,
      } | Source,
      {
        # torture/*.c + *.expected (expected stdout verified against gcc). The torture/ directory
        # in this package is a readable copy of the same content.
        url = "gs://minimal-staging-archives/tcc-torture-s4.tar.gz",
        sha256 = "8567511d499c73ded9432a07d9e0047a166efd3b32bc4a8d2cc31ec37ff8c705",
        extract = false,
      } | Source,
      stage0-musl-1-1-24-cc2,
      stage0-tcc-0-9-27-musl-s3,
      bash,
      coreutils,
      tar,
      gzip,
      sed,
      grep,
      gawk-bootstrap,
    ],
    cmd = "./build.sh",
    outputs = {
      # written only after every gate passes; on failure the glob matches nothing and the build
      # is marked failed, so nothing is cached or published.
      tcc = { glob = "usr/bin/tcc-musl2", allow_missing_interpreter = true } | OutputBin,
      libtcc1 = { glob = "usr/lib/tcc/libtcc1.a" } | OutputLib, # exercised by the torture tests (__udivdi3, __va_start)
      gatepass = { glob = "usr/share/tcc-musl-s4/GATE-PASS" } | OutputData, # only written on full pass
      manifest = { glob = "usr/share/tcc-musl-s4/MANIFEST.txt" } | OutputData,
      logs = { glob = "usr/share/tcc-musl-s4/rows.log" } | OutputData,
    },
  } | BuildSpec
in
# amd64 only: this rung belongs to the hex0-rooted amd64 ladder. On arm64 the spec collapses to
# an empty collection (no build, no outputs, nothing depends on it).
match {
  { arch = 'Amd64, .. } => amd64_spec,
  { arch = 'Arm64, .. } =>
    {
      name = "stage0-tcc-0.9.27-musl-s4",
      build_deps = [],
    } | BuildSpec,
} target
