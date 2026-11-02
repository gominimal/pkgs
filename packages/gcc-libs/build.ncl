let { Attrs, BuildSpec, Local, OutputLib, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# gcc-libs: gcc's target runtime libraries (libgcc_s, libstdc++, libatomic, libgomp, libquadmath,
# and the `libs` set of archives/crt objects) re-exported as their own package, with NO runtime
# dependency on gcc.
#
# Why it exists: in minimal a slice does not limit the runtime closure. `subsetOf gcc ["libgcc"]`
# pulls in gcc's WHOLE runtime_deps (minimal crates/graph/src/transitives.rs: a Subset edge recurses
# with the full spec). So anything added to gcc's runtime_deps reaches every package that only
# wants libgcc_s/libstdc++, including base host tools (coreutils -> gmp, bash -> ncurses, ...) and,
# when the amd64 ladder is on, the stage0 rungs (gominimal/pkgs#805: a modern `as` in a rung
# sandbox broke binutils-2.30's ld). Consumers take `subsetOf gcc-libs [...]` instead, so gcc can
# carry what a compiler needs at runtime (binutils, linux_headers, glibc) without leaking it.
#
# gcc is a BUILD dep here (minimal does not take a subset as a build input), and build deps do
# not propagate to consumers' runtime closures. The output globs are gcc's own, verbatim.
let gcc = import "../gcc/build.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gmp = import "../gmp/build.ncl" in
let mpc = import "../mpc/build.ncl" in
let mpfr = import "../mpfr/build.ncl" in
let zlib = import "../zlib/build.ncl" in
let zstd = import "../zstd/build.ncl" in
let all_outputs =
  {
    libs = { glob = "usr/lib/**/*.{a,o,so*}", allow_data = true } | OutputLib, # a few .so files are linker scripts/stubs
    libatomic = { glob = "usr/lib/libatomic.so*" } | OutputLib,
    libgcc = { glob = "usr/lib/libgcc_s.so*", allow_data = true } | OutputLib, # libgcc_s.so is a linker script
    libgomp = { glob = "usr/lib/libgomp.so*" } | OutputLib,
    libstdcpp = { glob = "usr/lib/libstdc++*.so*", allow_data = true } | OutputLib, # libstdc++.so.6.0.34-gdb.py
    ..
  }
    | match {
      { arch = 'Amd64, .. } =>
        {
          libquadmath = { glob = "usr/lib/libquadmath*.so*" } | OutputLib,
          ..
        },
      { arch = 'Arm64, .. } => { .. },
    } target
in
{
  name = "gcc-libs",
  build_deps = [
    { file = "build.sh" } | Local,
    bash-bootstrap,
    coreutils,
    gcc,
  ],
  # glibc, plus gcc's runtime_deps as they were before gcc gained the compiler's (binutils,
  # linux_headers). libgcc_s/libstdc++ need only glibc, but every `subsetOf gcc` consumer had
  # gmp/mpc/mpfr/zlib/zstd (and zstd's xz/lz4) in its runtime closure through that edge, and some
  # link them without declaring them (gcc-arm-none-eabi's cc1 -> libmpc, rsync -> libzstd/liblz4).
  # Keeping them makes the switch to gcc-libs closure-neutral for every consumer: it moves
  # binutils/linux_headers off the libgcc path and changes nothing else. Trim a library from
  # here only after the consumers that DT_NEED it declare it themselves.
  runtime_deps = [
    glibc,
    gmp,
    mpc,
    mpfr,
    zlib,
    zstd,
  ],
  # build.sh refuses to run unless the gcc in the sandbox is this version.
  build_args = {
    version = gcc.attrs.upstream_version,
  },

  cmd = "./build.sh",
  outputs = all_outputs,

  attrs =
    {
      upstream_version = gcc.attrs.upstream_version,
      license_spdx = "GPL-3.0-or-later WITH GCC-exception-3.1",
      repology_project = "gcc",
      source_provenance = {
        category = 'GnuProject,
        name = "gcc",
      },
    } | Attrs,

  # gcc's own bootstrap prebuilt (the same pinned tarball gcc's replace_on_cycle extracts), so a
  # re-pin of gcc's root (e.g. a new bootstrap generation) flows through with no second pin.
  replace_on_cycle =
    {
      name = "gcc-libs (prebuilt)",
      prebuilt = true,
      build_deps = gcc.replace_on_cycle.build_deps,
      runtime_deps = [],
      outputs = all_outputs,
    } | BuildSpec,
} | BuildSpec
