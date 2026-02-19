let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .., } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let acl = import "../acl/build.ncl" in
let attr = import "../attr/build.ncl" in
let libxcrypt = import "../libxcrypt/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "4.18.0" in
{
  name = "shadow",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/shadow-%{version}.tar.xz",
      sha256 = "add4604d3bc410344433122a819ee4154b79dd8316a56298c60417e637c07608",
    } | Source,
    base,
    make,
    toolchain,
  ],
  runtime_deps = [
    acl,
    attr,
    libxcrypt,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    sbins = { glob = "usr/sbin/*" } | OutputBin,
    libs = { glob = "usr/lib/lib*.{so*,a}" } | OutputLib,

    ltconfigs = { glob = "usr/lib/*.la" } | OutputData,

    includes = { glob = "usr/include/**" } | OutputData,
    etcs = { glob = "etc/**" } | OutputData,
    locales = { glob = "usr/share/locale/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "shadow-maint",
        repo = "shadow",
      },
    } | Attrs,
} | BuildSpec
