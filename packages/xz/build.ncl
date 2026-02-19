let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .., } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let glibc = import "../glibc/build.ncl" in
{
  name = "xz",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/xz-5.8.1.tar.xz",
      sha256 = "0b54f79df85912504de0b14aec7971e3f964491af1812d83447005807513cd9e"
    } | Source,
    base,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  outputs = {
    xz_bin = { glob = "usr/bin/xz" } | OutputBin,
    xzcat = { glob = "usr/bin/xzcat" } | OutputBin,
    xzcmp = { glob = "usr/bin/xzcmp" } | OutputBin,
    xzdec = { glob = "usr/bin/xzdec" } | OutputBin,
    xzdiff = { glob = "usr/bin/xzdiff" } | OutputBin,
    xzegrep = { glob = "usr/bin/xzegrep" } | OutputBin,
    xzfgrep = { glob = "usr/bin/xzfgrep" } | OutputBin,
    xzgrep = { glob = "usr/bin/xzgrep" } | OutputBin,
    xzless = { glob = "usr/bin/xzless" } | OutputBin,
    xzmore = { glob = "usr/bin/xzmore" } | OutputBin,
    lzcat = { glob = "usr/bin/lzcat" } | OutputBin,
    lzcmp = { glob = "usr/bin/lzcmp" } | OutputBin,
    lzdiff = { glob = "usr/bin/lzdiff" } | OutputBin,
    lzegrep = { glob = "usr/bin/lzegrep" } | OutputBin,
    lzfgrep = { glob = "usr/bin/lzfgrep" } | OutputBin,
    lzgrep = { glob = "usr/bin/lzgrep" } | OutputBin,
    lzless = { glob = "usr/bin/lzless" } | OutputBin,
    lzma = { glob = "usr/bin/lzma" } | OutputBin,
    lzmadec = { glob = "usr/bin/lzmadec" } | OutputBin,
    lzmainfo = { glob = "usr/bin/lzmainfo" } | OutputBin,
    lzmore = { glob = "usr/bin/lzmore" } | OutputBin,
    unlzma = { glob = "usr/bin/unlzma" } | OutputBin,
    unxz = { glob = "usr/bin/unxz" } | OutputBin,

    liblzma = { glob = "usr/lib/liblzma.so*" } | OutputLib,

    includes = { glob = "usr/include/**" } | OutputData,
  },

  replace_on_cycle =
    {
      name = "xz (prebuilt)",
      prebuilt = true,
      inputs = [
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
              sha256 = "8b5c6a5f4ffb3f07e22c0a28dc934ccb2424901250b5807d475b03ecc0f943fc",
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
