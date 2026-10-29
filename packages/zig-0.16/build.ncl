let { standaloneTest, subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let llvm = import "../llvm/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

# zig 0.16, prefixed under /usr/lib/zig-0.16, for consumers that pin it while
# `zig` moves to 0.17 (gominimal/pkgs#1148, inbox#1170): herdr's vendored
# libghostty-vt requires exactly 0.16.0 and has not re-vendored the 0.17
# ghostty yet. It is today's zig recipe, still on the default llvm (21), and
# installs nothing under /usr/bin, so it can share a closure with zig 0.17.
# The `-X.Y` name keeps pkgmgr on 0.16.x. Drop it once nothing needs 0.16.
let version = "0.16.0" in
let prefix = "/usr/lib/zig-0.16" in
{
  name = "zig-0.16",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://ziglang.org/download/%{version}/zig-%{version}.tar.xz",
      sha256 = "43186959edc87d5c7a1be7b7d2a25efffd22ce5807c7af99067f86f99641bfdf",
    } | Source,
    base,
    cmake,
    llvm,
    ninja,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc", "libstdcpp"],
    subsetOf llvm ["libllvm", "libclang", "liblld"],
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
    include prefix,
  },

  outputs = {
    zig = { glob = "usr/lib/zig-0.16/bin/zig" } | OutputBin,
    lib = { glob = "usr/lib/zig-0.16/lib/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "ziglang",
        repo = "zig",
      },
      license_spdx = "MIT",
      build_cost_multiple = 3,
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/usr/lib/zig-0.16/bin/zig version",

    compile_run =
      {
        class = 'Standalone,
        test_deps = [base, glibc],
        cmds = [
          ["/bin/bash", "-c", "echo 'const std = @import(\"std\"); pub fn main() void { std.debug.print(\"ok\\n\", .{}); }' > test.zig"],
          ["/usr/lib/zig-0.16/bin/zig", "run", "test.zig"],
        ],
      } | Test,
  },
} | BuildSpec
