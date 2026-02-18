let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let make = import "../make/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let python = import "../python/build.ncl" in
let base = import "../base/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let icu = import "../icu/build.ncl" in
let libuv = import "../libuv/build.ncl" in
let sqlite = import "../sqlite/build.ncl" in
let zlib = import "../zlib/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in

let version = "24.9.0" in
{
  name = "node",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/node-v%{version}.tar.xz",
      sha256 = "f17bc4cb01f59098c34a288c1bb109a778867c14eeb0ebbd608d0617b1193bbf",
    } | Source,
    base,
    make,
    pkgconf,
    python,
    toolchain,
  ],
  runtime_deps = [
    openssl,
    icu,
    libuv,
    zlib,
    sqlite,
    glibc,
    gcc, # TODO: Use a subset thats just libstdc, libm, libgcc_s
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    node_modules = { glob = "usr/lib/node_modules/**" } | OutputData,

    includes = { glob = "usr/include/**" } | OutputData,
    mans = { glob = "usr/share/man/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      env_state_wiring = {
        env_var = "NPM_CONFIG_CACHE",
        prefix = "npm-cache",
      },
    } | Attrs,

  tests = {
    eval =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "echo 'console.log(\"Hello Node\")' > script.js"],
          ["/bin/bash", "-c", "node script.js | grep -q '^Hello Node$'"],
          ["/bin/bash", "-c", "echo 'console.log(2 + 2)' > math.js"],
          ["/bin/bash", "-c", "node math.js | grep -q '^4$'"],
        ],
      } | Test,
    inline_eval =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "node -e 'console.log(10 * 5)' | grep -q '^50$'"],
        ],
      } | Test,
  },
} | BuildSpec
