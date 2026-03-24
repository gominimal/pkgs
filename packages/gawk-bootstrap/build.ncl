let { BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base-bootstrap = import "../base-bootstrap/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let mpfr = import "../mpfr/build.ncl" in

let version = "5.3.2" in
{
  name = "gawk-bootstrap",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/gawk-%{version}.tar.xz",
      sha256 = "f8c3486509de705192138b00ef2c00bbbdd0e84c30d5c07d23fc73a9dc4cc9cc"
    } | Source,
    base-bootstrap,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    mpfr,
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

  attrs = {
    upstream_version = version,
  },

  replace_on_cycle =
    {
      name = "gawk-bootstrap (prebuilt)",
      prebuilt = true,
      build_deps = [
        match {
          { arch = 'Amd64, .. } =>
            {
              url = "gs://minimal-staging-archives/prebuilts/gawk-bootstrap/amd64-linux-gnu/gawk-bootstrap_5.3.2_amd64-linux-gnu_prebuilt_363e67d.tar.zst",
              sha256 = "d0d3700876dd997ed16d2697ec91a019063bdb5bc7bff40111e67ecd5448c1a7",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              url = "gs://minimal-staging-archives/prebuilts/gawk-bootstrap/arm64-linux-gnu/gawk-bootstrap_5.3.2_arm64-linux-gnu_prebuilt_363e67d.tar.zst",
              sha256 = "dc10a30c401ea0fd38886a0b94b88a38680bee7e4abc68859e1068f22a49ef5e",
              extract = true,
            } | Source,
        } target,
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
