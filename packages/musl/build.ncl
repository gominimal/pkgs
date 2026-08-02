let { BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in

let version = "1.2.6" in

let base = import "../base/build.ncl" in
let binutils = import "../binutils/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

{
  name = "musl",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://git.musl-libc.org/cgit/musl/snapshot/musl-%{version}.tar.gz",
      sha256 = "e9db8b70b0cba3db43b27e84ccd8a0c0958b40029a1c36c9f13817b93787b4d6",
      extract = true,
      strip_prefix = "musl-%{version}",
    } | Source,
    base,
    toolchain,
    make,
  ],

  runtime_deps = [],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    musl_bins = { glob = "usr/local/musl/bin/*" } | OutputBin,
    libs = { glob = "usr/local/musl/lib/*" } | OutputLib,
    headers = { glob = "usr/local/musl/include/**" } | OutputData,
  },

  attrs = {
    upstream_version = version,
  },

  tests = {
    compile_and_run =
      {
        class = 'Standalone,
        test_deps = [base, toolchain, binutils],
        cmds = [
          ["/bin/bash", "-c", "echo '#include <stdio.h>\nint main() { printf(\"Hello from musl!\\n\"); return 0; }' > test.c"],
          ["/bin/bash", "-c", "musl-gcc test.c -o test"],
          ["/bin/bash", "-c", "./test | grep 'Hello from musl!'"],
        ],
      } | Test,
    compile_static =
      {
        class = 'Standalone,
        test_deps = [base, toolchain, binutils],
        cmds = [
          ["/bin/bash", "-c", "echo '#include <stdio.h>\nint main() { printf(\"Hello from musl!\\n\"); return 0; }' > test.c"],
          ["/bin/bash", "-c", "musl-gcc -static test.c -o test_static"],
          ["/bin/bash", "-c", "./test_static | grep 'Hello from musl!'"],
          ["/bin/bash", "-c", "ldd test_static 2>&1 | grep 'not a dynamic executable'"],
        ],
      } | Test,
  },
} | BuildSpec
