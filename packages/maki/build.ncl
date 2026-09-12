let { subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
# isahc (static-ssl) vendors and builds OpenSSL from source (perl Configure + make)
let make = import "../make/build.ncl" in
let perl = import "../perl/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "0.4.12" in
{
  name = "maki",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/tontinton/maki/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "024604df4bf2c0acaffebaf572d9dc085746780eac7a734036d4750b225894ba",
      extract = true,
      strip_prefix = "maki-%{version}",
    } | Source,
    base,
    make,
    perl,
    rust,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc"],
  ],

  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  cmd = "./build.sh",
  build_args = { include version },

  outputs = {
    maki = { glob = "usr/bin/maki" } | OutputBin,
  },

  tests = {
    version_check =
      {
        class = 'Standalone,
        test_deps = [],
        cmds = [["maki", "--version"]],
      } | Test,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "tontinton",
        repo = "maki",
      },
    } | Attrs,
} | BuildSpec
