let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

# Terminfo parsing library. Upstream (mauke/unibilium) is unmaintained; the
# neovim fork is the actively maintained canonical source.
let version = "2.1.4" in
{
  name = "unibilium",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/neovim/unibilium/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "7360907bcf79ba49f6fc4a504767ff86e93ab9018477026fcc70d5ab77e1f2c1",
      extract = true,
      strip_prefix = "unibilium-%{version}",
    } | Source,
    base,
    cmake,
    ninja,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],
  cmd = "./build.sh",
  outputs = {
    libs = { glob = "usr/lib/libunibilium*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "LGPL-3.0-or-later",
      source_provenance = {
        category = 'GithubRepo,
        owner = "neovim",
        repo = "unibilium",
      },
    } | Attrs,
} | BuildSpec
