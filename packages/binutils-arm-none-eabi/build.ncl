let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base-bootstrap = import "../base-bootstrap/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "2.47" in
{
  name = "binutils-arm-none-eabi",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://mirrors.kernel.org/gnu/binutils/binutils-%{version}.tar.xz",
      sha256 = "154ab23b60070e8f27013c22977f1129425d67d1e8acd6e13010e617811e4cff"
    } | Source,
    base-bootstrap,
    make,
    toolchain,
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
    bins = { glob = "usr/bin/arm-none-eabi-*" } | OutputBin,
    target_libs = { glob = "usr/arm-none-eabi/lib/**" } | OutputData,
    ldscripts = { glob = "usr/arm-none-eabi/lib/ldscripts/*" } | OutputData,
    target_bin = { glob = "usr/arm-none-eabi/bin/*" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "(GPL-2.0-only AND GPL-3.0-only AND LGPL-2.0-only)",
      source_provenance = {
        category = 'GnuProject,
        name = "binutils",
      },
    } | Attrs,
} | BuildSpec
