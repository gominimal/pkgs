let { subsetOf, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let libkrunfw = import "../libkrunfw/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "1.19.0" in
{
  name = "libkrun",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/containers/libkrun/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "832e76e93f1ea7a41e5c763a9710acf42d3d54f628015c1255f115a4b7ef2a06",
      extract = true,
      strip_prefix = "libkrun-%{version}",
    } | Source,
    base,
    toolchain,
    make,
    rust,
    pkgconf,
  ],

  # libkrunfw is dlopen()ed at runtime (libkrunfw.so.5), not linked at build.
  runtime_deps = [
    glibc,
    libkrunfw,
    subsetOf gcc ["libgcc"],
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  # cargo fetches crates from crates.io during the build.
  needs = {
    dns = {},
    internet = {},
  },

  outputs = {
    libs = { glob = "usr/lib/libkrun.so*" } | OutputLib,
    headers = { glob = "usr/include/libkrun*.h" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/libkrun.pc" } | OutputData,
  },

  attrs = {
    upstream_version = version,
    license_spdx = "Apache-2.0",
    source_provenance = {
      category = 'GithubRepo,
      owner = "containers",
      repo = "libkrun",
    },
  },
} | BuildSpec
