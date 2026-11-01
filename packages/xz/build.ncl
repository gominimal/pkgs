let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base-bootstrap = import "../base-bootstrap/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "5.8.4" in
{
  name = "xz",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/xz-%{version}.tar.xz",
      sha256 = "4ce24038fd4221e0d13bc1a2de7a4db56e90b92b3bf75321f6c14be73f65de4b"
    } | Source,
    base-bootstrap,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  outputs = {
    # Technically bins like xzdiff depend on /bin/sh, but its not practical to depend on bash at such a low level.
    # Disable the lint for now.
    xz_bin = { glob = "usr/bin/xz" } | OutputBin,
    xzcat = { glob = "usr/bin/xzcat" } | OutputBin,
    xzcmp = { glob = "usr/bin/xzcmp", allow_missing_interpreter = true } | OutputBin,
    xzdec = { glob = "usr/bin/xzdec" } | OutputBin,
    xzdiff = { glob = "usr/bin/xzdiff", allow_missing_interpreter = true } | OutputBin,
    xzegrep = { glob = "usr/bin/xzegrep", allow_missing_interpreter = true } | OutputBin,
    xzfgrep = { glob = "usr/bin/xzfgrep", allow_missing_interpreter = true } | OutputBin,
    xzgrep = { glob = "usr/bin/xzgrep", allow_missing_interpreter = true } | OutputBin,
    xzless = { glob = "usr/bin/xzless", allow_missing_interpreter = true } | OutputBin,
    xzmore = { glob = "usr/bin/xzmore", allow_missing_interpreter = true } | OutputBin,
    lzcat = { glob = "usr/bin/lzcat" } | OutputBin,
    lzcmp = { glob = "usr/bin/lzcmp", allow_missing_interpreter = true } | OutputBin,
    lzdiff = { glob = "usr/bin/lzdiff", allow_missing_interpreter = true } | OutputBin,
    lzegrep = { glob = "usr/bin/lzegrep", allow_missing_interpreter = true } | OutputBin,
    lzfgrep = { glob = "usr/bin/lzfgrep", allow_missing_interpreter = true } | OutputBin,
    lzgrep = { glob = "usr/bin/lzgrep", allow_missing_interpreter = true } | OutputBin,
    lzless = { glob = "usr/bin/lzless", allow_missing_interpreter = true } | OutputBin,
    lzma = { glob = "usr/bin/lzma" } | OutputBin,
    lzmadec = { glob = "usr/bin/lzmadec" } | OutputBin,
    lzmainfo = { glob = "usr/bin/lzmainfo" } | OutputBin,
    lzmore = { glob = "usr/bin/lzmore", allow_missing_interpreter = true } | OutputBin,
    unlzma = { glob = "usr/bin/unlzma" } | OutputBin,
    unxz = { glob = "usr/bin/unxz" } | OutputBin,

    liblzma = { glob = "usr/lib/liblzma.so*" } | OutputLib,

    includes = { glob = "usr/include/**" } | OutputData,
  },

  replace_on_cycle =
    {
      name = "xz (prebuilt)",
      prebuilt = true,
      build_deps = [
        match {
          { arch = 'Amd64, .. } =>
            {
              # gominimal/bootstrap gen-11 object (generations/gen-11/manifest.json)
              url = "gs://minimal-bootstrap/gen-11/sha256/2da77c070a93e8ab5ffc304ed10c6ed3a3677dbe51a2e10b1053a85aae24b0b5/xz-x86_64.tar.zst",
              sha256 = "2da77c070a93e8ab5ffc304ed10c6ed3a3677dbe51a2e10b1053a85aae24b0b5",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              # gominimal/bootstrap gen-11 object (generations/gen-11/manifest.json)
              url = "gs://minimal-bootstrap/gen-11/sha256/c206e79767d84ac682ffe745464ae3fcd4de062e02be75bdaee6565b84e4afad/xz-aarch64.tar.zst",
              sha256 = "c206e79767d84ac682ffe745464ae3fcd4de062e02be75bdaee6565b84e4afad",
              extract = true,
            } | Source,
        } target,
      ],
      outputs = {
        usr_bin = { glob = "usr/bin/**/*" } | OutputLib,
        usr_lib = { glob = "usr/lib/**/*" } | OutputLib,
        usr_include = { glob = "usr/include/**/*" } | OutputLib,
      },
    } | BuildSpec,
  attrs =
    {
      upstream_version = version,
      license_spdx = "(0BSD AND GPL-2.0-only AND GPL-3.0-only AND LGPL-2.1-only)",
      source_provenance = {
        category = 'GithubRepo,
        owner = "tukaani-project",
        repo = "xz",
      },
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/usr/bin/xz --version",
  },
} | BuildSpec
