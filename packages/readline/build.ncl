let { BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
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
        {
          url = "gs://minimal-staging-archives/prebuilts/readline/arm64-linux-gnu/readline_8.3_arm64-linux-gnu_prebuilt.tar.zst",
          sha256 = "6ef8d8c2fd259d5d5c304bd374ca3616aeea112fa4ae1df1d2e90bd8cabe601f",
          extract = true,
        } | Source,
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
