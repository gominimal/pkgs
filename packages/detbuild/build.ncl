let { BuildSpec, Local, OutputLib, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let binutils = import "../binutils/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let linux_headers = import "../linux_headers/build.ncl" in
{
  name = "detbuild",
  # A deterministic build-time environment for other recipes to preload:
  #   LD_PRELOAD=/usr/lib/minimal/libdetbuild.so <build command>
  # pins uname(2)'s kernel release/version and process entropy
  # (getrandom/getentropy and the raw getrandom syscall) for the BUILD only.
  # See detbuild.c for what leaked and from where. Deliberately depends on
  # the toolchain's members rather than `toolchain`, so it can become one of
  # toolchain's runtime deps (and a sandbox default) without a cycle.
  build_deps = [
    { file = "build.sh" } | Local,
    { file = "detbuild.c" } | Local,
    base,
    binutils,
    gcc,
    glibc,
    linux_headers,
  ],
  runtime_deps = [
    glibc,
  ],
  cmd = "./build.sh",
  outputs = {
    lib = { glob = "usr/lib/minimal/libdetbuild.so" } | OutputLib,
  },
  tests = {
    preload =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "test \"$(LD_PRELOAD=/usr/lib/minimal/libdetbuild.so uname -r)\" = 7.0.0-minimal"],
          ["/bin/bash", "-c", "test \"$(uname -r)\" != 7.0.0-minimal"],
          ["/bin/bash", "-c", "a=$(LD_PRELOAD=/usr/lib/minimal/libdetbuild.so head -c 16 /dev/urandom | od -An -tx1); b=$(LD_PRELOAD=/usr/lib/minimal/libdetbuild.so head -c 16 /dev/urandom | od -An -tx1); test -n \"$a\""],
        ],
      } | Test,
  },
} | BuildSpec
