let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.15.1" in
{
  name = "zig",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://ziglang.org/download/%{version}/zig-x86_64-linux-%{version}.tar.xz",
      sha256 = "c61c5da6edeea14ca51ecd5e4520c6f4189ef5250383db33d01848293bfafe05",
    } | Source,
    base,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    zig = { glob = "usr/bin/zig" } | OutputBin,
    lib = { glob = "usr/lib/zig/**" } | OutputLib,
    doc = { glob = "usr/share/doc/zig/**" } | OutputData,
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
