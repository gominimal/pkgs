let { BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in

# TODO: When packaging i see errors like: /usr/bin/bison: m4 subprocess failed: No such file or directory
# Maybe m4 needs to be a runtime_dep here?
let base = import "../base/build.ncl" in
let flex = import "../flex/build.ncl" in
let m4 = import "../m4/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
{
  name = "bison",
  inputs = [
    {
      url = "gs://minimal-staging-archives/bison-3.8.2.tar.xz",
      sha256 = "9bba0214ccf7f1079c5d59210045227bcf619519840ebfa80cd3849cff5a5bf2"
    } | Source,
    { file = "build.sh" } | Local,
    base,
    make,
    flex,
    m4,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  outputs = {
    bison = { glob = "usr/bin/bison" } | OutputBin,
    yacc = { glob = "usr/bin/yacc" } | OutputBin,

    liby = { glob = "usr/lib/liby.a" } | OutputLib,

    bison_share = { glob = "usr/share/bison/**/*" } | OutputData,
    mans = { glob = "usr/share/man/**" } | OutputData,
    locales = { glob = "usr/share/locale/**" } | OutputData,
    aclocals = { glob = "usr/share/aclocal/*" } | OutputData,
  },

  replace_on_cycle =
    {
      name = "bison (prebuilt)",
      prebuilt = true,
      inputs = [
        {
          url = "gs://minimal-staging-archives/prebuilts/bison/arm64-linux-gnu/bison_3.8.2_arm64-linux-gnu_prebuilt.tar.zst",
          sha256 = "5729df4ebddaf509e0fc6e394b614d17100adc0b53b06c3411fcb610a034cc14",
          extract = true,
        } | Source,
      ],
      outputs = {
        usr = { glob = "usr/**/*" } | OutputLib,
      },
    } | BuildSpec,
} | BuildSpec
