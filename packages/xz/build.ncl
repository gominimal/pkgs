let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base-bootstrap = import "../base-bootstrap/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "5.8.1" in
{
  name = "xz",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/xz-%{version}.tar.xz",
      sha256 = "0b54f79df85912504de0b14aec7971e3f964491af1812d83447005807513cd9e"
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
              url = "gs://minimal-staging-archives/prebuilts/xz/c9082dfc1422992b88db6fb17c2ccf061ebf2e595872b470c82645a95799830e.tar.zst",
              sha256 = "1f72a85d5fa9b779932934d5cfb5319473b1f71828d5e7afa8d75e87b97c24d6",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              url = "gs://minimal-staging-archives/prebuilts/xz/arm64-linux-gnu/xz_5.8.1_arm64-linux-gnu_prebuilt.tar.zst",
              sha256 = "7adffe3bf126544f0ba575d237eba709b2de3d5e6f7667a0244feb99efcc8997",
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
      source_provenance = {
        category = 'GithubRepo,
        owner = "tukaani-project",
        repo = "xz",
      },
    } | Attrs,
} | BuildSpec
