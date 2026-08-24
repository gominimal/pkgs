let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "2.11.3" in
{
  name = "utf8proc",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/juliastrings/utf8proc/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "abfed50b6d4da51345713661370290f4f4747263ee73dc90356299dfc7990c78",
      extract = true,
      strip_prefix = "utf8proc-%{version}",
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
    libs = { glob = "usr/lib/libutf8proc.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,
    cmake_data = { glob = "usr/lib/cmake/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "juliastrings",
        repo = "utf8proc",
      },
    } | Attrs,
} | BuildSpec
