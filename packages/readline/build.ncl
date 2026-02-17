let { BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let ncurses = import "../ncurses/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
{
  name = "readline",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/readline-8.3.tar.gz",
      sha256 = "fe5383204467828cd495ee8d1d3c037a7eba1389c22bc6a041f627976f9061cc"
    } | Source,
    base,
    make,
    toolchain,
  ],
  runtime_deps = [
    ncurses,
  ],
  cmd = "./build.sh",
  outputs = {
    libreadline = { glob = "usr/lib/libreadline.so*" } | OutputLib,
    libhistory = { glob = "usr/lib/libhistory.so*" } | OutputLib,

    pkgconfig = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
    headers = { glob = "usr/include/readline/*.h" } | OutputData,
  },

  replace_on_cycle =
    {
      name = "readline (prebuilt)",
      prebuilt = true,
      inputs = [
        match {
          { arch = 'Amd64, .. } =>
            {
              url = "gs://minimal-staging-archives/prebuilts/readline/0b0d99c0ecd377b7b8618468423fc679377d8f8ebc7475bd7fc71a2bec20d6a2.tar.zst",
              sha256 = "0b1677ad712f7de3526d0a1ecf154ce9c8a2a3392fb2bcf1b8e006afa1b16d99",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              url = "gs://minimal-staging-archives/prebuilts/readline/arm64-linux-gnu/readline_8.3_arm64-linux-gnu_prebuilt.tar.zst",
              sha256 = "4158f23deb2b313d16630378f735cc440fc33b277b295dea29038ce081c0e3fa",
              extract = true,
            } | Source,
        } target,
      ],
      runtime_deps = [
        ncurses,
      ],
      outputs = {
        usr_lib = { glob = "usr/lib/**/*" } | OutputLib,
        usr_include = { glob = "usr/include/**/*" } | OutputData,
      },
    } | BuildSpec,
} | BuildSpec
