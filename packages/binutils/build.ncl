let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# base
let bash = import "../bash/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let diffutils = import "../diffutils/build.ncl" in
let grep = import "../grep/build.ncl" in
let gawk = import "../gawk/build.ncl" in
let make = import "../make/build.ncl" in
let perl = import "../perl/build.ncl" in
let sed = import "../sed/build.ncl" in
# toolchain
let binutils = import "../binutils/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let linux_headers = import "../linux_headers/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "2.45.1" in
{
  name = "binutils",
  inputs = [
    {
      url = "gs://minimal-staging-archives/binutils-%{version}.tar.xz",
      sha256 = "5fe101e6fe9d18fdec95962d81ed670fdee5f37e3f48f0bef87bddf862513aa5",
      extract = true,
    } | Source,
    { file = "build.sh" } | Local,
    # base
    bash,
    coreutils,
    diffutils,
    gawk,
    grep,
    make,
    perl,
    sed,
    # toolchain
    binutils,
    gcc,
    linux_headers,
  ],
  runtime_deps = [
    glibc,
    zlib,
    subsetOf gcc ["libstdcpp", "libgcc"],
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    libs = { glob = "usr/lib/*.{a,so*}" } | OutputLib,

    ltconfigs = { glob = "usr/lib/*.la" } | OutputData,
    ldscripts = { glob = "usr/lib/ldscripts/*" } | OutputData,

    gprofng_libs = { glob = "usr/lib/gprofng/*.so*" } | OutputLib,
    gprofng_ltconfigs = { glob = "usr/lib/gprofng/*.la" } | OutputData,

    bfdplugins = { glob = "usr/lib/bfd-plugins/**" } | OutputLib,

    etcs = { glob = "etc/*" } | OutputData,
    includes = { glob = "usr/include/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      repology_project = "binutils",
      source_provenance = {
        category = 'GnuProject,
        name = "binutils",
      },
    } | Attrs,

  replace_on_cycle =
    {
      name = "binutils (prebuilt)",
      prebuilt = true,
      inputs = [
        match {
          { arch = 'Amd64, .. } =>
            {
              url = "gs://minimal-staging-archives/prebuilts/binutils/baea2e99362c3138a3b129ca4fceee19d0444bbb68f3c57b08d3cb89145ea103.tar.zst",
              sha256 = "63f6b776215970427b3360fb00d69b84debe607b57511c7832874049cf05a2d4",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              url = "gs://minimal-staging-archives/prebuilts/binutils/arm64-linux-gnu/binutils_2.46.0_arm64-linux-gnu_prebuilt.tar.zst",
              sha256 = "3321ec000f550aeec444b699194f996216403f72e1ab1da6e58522328bd82530",
              extract = true,
            } | Source,
        } target,
      ],
      runtime_deps = [
        zlib,
      ],
      outputs = {
        usr_bin = { glob = "usr/bin/**/*" } | OutputLib,
        usr_lib = { glob = "usr/lib/**/*" } | OutputLib,
        usr_include = { glob = "usr/include/**/*" } | OutputLib,
        usr_share = { glob = "usr/share/**/*" } | OutputLib,
      },
    } | BuildSpec,
} | BuildSpec
