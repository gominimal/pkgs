let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let make = import "../make/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let python = import "../python/build.ncl" in
let base = import "../base/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let c-ares = import "../c-ares/build.ncl" in
let icu = import "../icu/build.ncl" in
let libuv = import "../libuv/build.ncl" in
let nghttp2 = import "../nghttp2/build.ncl" in
let nghttp3 = import "../nghttp3/build.ncl" in
let ngtcp2 = import "../ngtcp2/build.ncl" in
let sqlite = import "../sqlite/build.ncl" in
let zlib = import "../zlib/build.ncl" in
let zstd = import "../zstd/build.ncl" in
let gtest = import "../gtest/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in

let version = "24.14.1" in
{
  name = "node-lts",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://nodejs.org/dist/v%{version}/node-v%{version}.tar.gz",
      sha256 = "8298cf1f5774093ca819f41b8dd392fd2cff058688b4d5c8805026352e2d31b3",
    } | Source,
    base,
    make,
    pkgconf,
    python,
    toolchain,
  ],
  runtime_deps = [
    # Note: lief is absent here (unlike packages/node/) because --shared-lief was not added
    # to Node.js configure until v25; the v24 LTS branch does not support it.
    coreutils, # npx/npm need /usr/bin/env
    openssl,
    c-ares,
    icu,
    libuv,
    zlib,
    sqlite,
    nghttp2,
    nghttp3,
    ngtcp2,
    zstd,
    gtest,
    glibc,
    subsetOf gcc ["libgcc", "libstdcpp"],
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    node = { glob = "usr/bin/node" } | OutputBin,
    npx = { glob = "usr/bin/npx" } | OutputBin,
    npm = { glob = "usr/bin/npm" } | OutputBin,
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
      source_provenance = {
        category = 'GithubRepo,
        owner = "nodejs",
        repo = "node",
      },
      build_cost_multiple = 5,
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
