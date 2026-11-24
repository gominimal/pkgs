let { Attrs, BuildSpec, Local, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

# gcc's shared runtime libraries as their own package (gominimal/inbox#1261).
# Depend on `subsetOf gcc-runtime [...]`, never `subsetOf gcc [...]`: a gcc
# subset fetches the whole compiler and its runtime_deps (see build.sh).
# Output names match gcc's, so moving a consumer is a rename. (libstdcpp's glob
# skips gcc's libstdc++.so.6.*-gdb.py debugger helper.)
# No upstream_version: this follows the gcc build dep and rebuilds with it.
let outputs_common = {
  libgcc = { glob = "usr/lib/libgcc_s.so*", allow_data = true } | OutputLib, # libgcc_s.so is a linker-script stub
  libstdcpp = { glob = "usr/lib/libstdc++.so*" } | OutputLib,
  libgomp = { glob = "usr/lib/libgomp.so*" } | OutputLib,
  libatomic = { glob = "usr/lib/libatomic.so*" } | OutputLib,
  libssp = { glob = "usr/lib/libssp.so*" } | OutputLib, # stlink NEEDs libssp.so.0
}
in
# gcc builds libquadmath on amd64 only.
let amd64_quadmath =
  match {
    { arch = 'Amd64, .. } => { libquadmath = { glob = "usr/lib/libquadmath.so*" } | OutputLib },
    { arch = 'Arm64, .. } => {},
  } target
in
{
  name = "gcc-runtime",
  build_deps = [
    { file = "build.sh" } | Local,
    { file = "stage.sh" } | Local,
    bash-bootstrap,
    coreutils,
    gcc,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  outputs = outputs_common & amd64_quadmath,

  attrs =
    {
      # libgcc_s, libstdc++, libgomp, libatomic, libssp: GPL-3.0-or-later
      # with the GCC Runtime Library Exception 3.1. libquadmath (amd64):
      # LGPL-2.1-or-later.
      license_spdx = "GPL-3.0-or-later WITH GCC-exception-3.1 AND LGPL-2.1-or-later",
    } | Attrs,

  # gcc-runtime is on no bootstrap cycle: gcc_runtime_guard rule 4 keeps it out
  # of gcc's build graph, and its own build deps (bash-bootstrap, coreutils,
  # gcc) are all inside that graph, so none of them can reach it. This breaker
  # is unused while that holds. It stays so that a cycle through gcc-runtime,
  # if one ever forms, resolves to the same gominimal/bootstrap gcc objects
  # gcc's own breaker uses (gcc_runtime_guard.py fails if the two breakers'
  # pins differ, so a repin must move both).
  # A prebuilt's cache entry is the WHOLE extracted object (output globs are not
  # applied to prebuilts), so consumers must take a subset, never all of
  # gcc-runtime (the guard enforces it); a subset still gets just its globs.
  # The breaker declares the same outputs as the real spec: asking a prebuilt
  # for an output it does not declare panics in minimal
  # (crates/op/src/subsets.rs).
  replace_on_cycle =
    {
      name = "gcc-runtime (prebuilt)",
      prebuilt = true,
      build_deps = [
        match {
          { arch = 'Amd64, .. } =>
            {
              # gominimal/bootstrap gen-13 object (generations/gen-13/manifest.json)
              url = "gs://minimal-bootstrap/gen-13/sha256/931b342257874bbd946a55443ba75f1930433bf4dc12d6924fec674e75f4c007/gcc-15.2.0-glibc-15.2.0-x86_64.tar.zst",
              sha256 = "931b342257874bbd946a55443ba75f1930433bf4dc12d6924fec674e75f4c007",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              # gominimal/bootstrap gen-17 object (generations/gen-17/manifest.json)
              url = "gs://minimal-bootstrap/gen-17/sha256/ad09a27cf021c341d50cf5c7a43d9cfcb45af363890c8e0b695259edc2c27d43/gcc-15.2.0-glibc-seed-15.2.0-aarch64.tar.zst",
              sha256 = "ad09a27cf021c341d50cf5c7a43d9cfcb45af363890c8e0b695259edc2c27d43",
              extract = true,
            } | Source,
        } target,
      ],
      # glibc is on the same cycle and has its own breaker; the prebuilt
      # object's libraries resolve against whichever glibc the root holds.
      runtime_deps = [],
      outputs = outputs_common & amd64_quadmath,
    } | BuildSpec,

  tests = {
    # Proves the package is self-sufficient: no gcc in this test's closure
    # (bash-bootstrap needs only glibc), so every library must resolve its own
    # DT_NEEDED against gcc-runtime + glibc alone. ld.so --list prints
    # "not found" for a missing dependency.
    loads_without_gcc =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap],
        cmds = [
          [
            "/bin/bash",
            "-c",
            "shopt -s nullglob; ld=(/usr/lib/ld-linux*.so.*); [ ${#ld[@]} -eq 1 ] || exit 3; for l in /usr/lib/libgcc_s.so.1 /usr/lib/libstdc++.so.6 /usr/lib/libgomp.so.1 /usr/lib/libatomic.so.1 /usr/lib/libssp.so.0; do [ -e \"$l\" ] || exit 4; out=$(\"${ld[0]}\" --list \"$l\") || exit 5; [[ $out == *'not found'* ]] && exit 6; done; exit 0",
          ],
        ],
      } | Test,
  },
} | BuildSpec
