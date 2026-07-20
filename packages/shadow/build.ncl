let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let acl = import "../acl/build.ncl" in
let attr = import "../attr/build.ncl" in
let libxcrypt = import "../libxcrypt/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "4.19.4" in
{
  name = "shadow",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/shadow-%{version}.tar.xz",
      sha256 = "ce57a313e315a0a7cb04a8f50cc20753e994e487bbe9b78a2a824ca75cb486c0",
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
      license_spdx = "BSD-3-Clause",
      source_provenance = {
        category = 'GithubRepo,
        owner = "shadow-maint",
        repo = "shadow",
      },
    } | Attrs,
} | BuildSpec
