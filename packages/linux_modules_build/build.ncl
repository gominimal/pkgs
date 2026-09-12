let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let flex = import "../flex/build.ncl" in
let bison = import "../bison/build.ncl" in
let bc = import "../bc/build.ncl" in
let perl = import "../perl/build.ncl" in
let elfutils = import "../elfutils/build.ncl" in
let m4 = import "../m4/build.ncl" in
let openssl = import "../openssl/build.ncl" in

let version = "6.12.43" in
{
  name = "linux_modules_build",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/linux-%{version}.tar.xz",
      sha256 = "0fcbbbbcd456e87bbbfc8bf37af541fda62ccfcce76903503424fd101ef7bdee",
      extract = true,
      strip_prefix = "linux-%{version}",
    } | Source,
    base,
    toolchain,
    make,
    flex,
    bison,
    bc,
    perl,
    elfutils,
    m4,
    openssl,
  ],

  cmd = "./build.sh",
  build_args = { include version },

  outputs = {
    tree = { glob = "usr/src/linux-%{version}/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "torvalds",
        repo = "linux",
      },
    } | Attrs,
} | BuildSpec
