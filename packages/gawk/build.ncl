let { BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let mpfr = import "../mpfr/build.ncl" in
let readline = import "../readline/build.ncl" in
{
  name = "gawk",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/gawk-5.3.2.tar.xz",
      sha256 = "f8c3486509de705192138b00ef2c00bbbdd0e84c30d5c07d23fc73a9dc4cc9cc"
    } | Source,
    base,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    mpfr,
    readline,
  ],

  cmd = "./build.sh",
  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    libs = { glob = "usr/lib/gawk/*.so" } | OutputLib,
    libexec = { glob = "usr/libexec/awk/*" } | OutputLib,

    includes = { glob = "usr/include/**" } | OutputData,

    awk_data = { glob = "usr/share/awk/*" } | OutputData,
    mans = { glob = "usr/share/man/**" } | OutputData,
    locales = { glob = "usr/share/locale/**" } | OutputData,
  },

  replace_on_cycle =
    {
      name = "gawk (prebuilt)",
      prebuilt = true,
      inputs = [
        {
          url = "gs://minimal-staging-archives/prebuilts/gawk/2c668aca10691d29a89f767fc19208a30e037c65ab01dcfc10c338de3dcfb478.tar.zst",
          sha256 = "7c1b61fc5b0351ca48cc2ddb894ff84597295cb72c8a478ae5238b5ccd66cac8",
          extract = true,
        } | Source,
      ],
      outputs = {
        usr_bin = { glob = "usr/bin/**/*" } | OutputBin,
        usr_include = { glob = "usr/include/**/*" } | OutputLib,
        usr_lib = { glob = "usr/lib/**/*" } | OutputLib,
        usr_libexec = { glob = "usr/libexec/**/*" } | OutputLib,
        usr_share = { glob = "usr/share/**/*" } | OutputLib,
      },
    } | BuildSpec,
} | BuildSpec
