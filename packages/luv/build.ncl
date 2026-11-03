let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let libuv = import "../libuv/build.ncl" in
let luajit = import "../luajit/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.53.0-1" in
# Header-only Lua compatibility shims vendored by luv as a git submodule,
# which GitHub archive tarballs don't include — fetched separately.
let compat53_version = "0.13" in
{
  name = "luv",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/luvit/luv/archive/refs/tags/%{version}.tar.gz",
      sha256 = "e7d7c872637560e9e9ac0cdcaad1b06c4058152fb0eb9d039f38612b183d01a7",
      extract = true,
      strip_prefix = "luv-%{version}",
    } | Source,
    {
      url = "https://github.com/lunarmodules/lua-compat-5.3/archive/refs/tags/v%{compat53_version}.tar.gz",
      sha256 = "f5dc30e7b1fda856ee4d392be457642c1f0c259264a9b9bfbcb680302ce88fc2",
      extract = true,
    } | Source,
    base,
    cmake,
    ninja,
    pkgconf,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    libuv,
    luajit,
  ],
  cmd = "./build.sh",
  build_args = {
    include compat53_version,
  },
  outputs = {
    libs = { glob = "usr/lib/libluv.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "luvit",
        repo = "luv",
      },
    } | Attrs,
} | BuildSpec
