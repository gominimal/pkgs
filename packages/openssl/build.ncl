let { Attrs, BuildSpec, Local, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let perl = import "../perl/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "3.6.0" in
{
  name = "openssl",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/openssl-%{version}.tar.gz",
      sha256 = "b6a5f44b7eb69e3fa35dbf15524405b44837a481d43d81daddde3ff21fcbb8e9",
      extract = true,
      strip_prefix = "openssl-%{version}",
    } | Source,
    base,
    perl,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  outputs = {
    etc = { glob = "etc/ssl/**/*" } | OutputLib,
    usr = { glob = "usr/**/*" } | OutputLib,
  },

  attrs =
    {
      upstream_version = version,
      repology_project = "openssl",
    } | Attrs,
} | BuildSpec
