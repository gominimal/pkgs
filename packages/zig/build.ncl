let { standaloneTest, subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let llvm = import "../llvm/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "0.16.0-dev.2682+02142a54d" in
{
  name = "zig",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://ziglang.org/builds/zig-%{version}.tar.xz",
      sha256 = "2884607e55761aa2a178ca50b5277ee1abb4320db6a7d023c46cf0ffe7632f8f",
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
  },

  outputs = {
    zig = { glob = "usr/bin/zig" } | OutputBin,
    lib = { glob = "usr/lib/zig/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      env_state_wiring = [
        {
          env_var = "ZIG_LOCAL_CACHE_DIR",
          prefix = "zig-cache",
        },
        {
          env_var = "ZIG_GLOBAL_CACHE_DIR",
          prefix = "zig-global-cache",
        },
      ],
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/bin/zig version",

    compile_run =
      {
        class = 'Standalone,
        test_deps = [base, glibc],
        cmds = [
          ["/bin/bash", "-c", "echo 'const std = @import(\"std\"); pub fn main() void { std.debug.print(\"ok\\n\", .{}); }' > test.zig"],
          ["/bin/zig", "run", "test.zig"],
        ],
      } | Test,
  },
} | BuildSpec
