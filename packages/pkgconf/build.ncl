let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .., } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "2.5.1" in
{
  name = "pkgconf",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/pkgconf-%{version}.tar.xz",
      sha256 = "cd05c9589b9f86ecf044c10a2269822bc9eb001eced2582cfffd658b0a50c243",
      extract = true,
      strip_prefix = "pkgconf-%{version}",
    } | Source,
    base,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    libs = { glob = "usr/lib/libpkgconf.so*" } | OutputLib,

    includes = { glob = "usr/include/pkgconf/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
    ltconfigs = { glob = "usr/lib/*.la" } | OutputData,
    aclocals = { glob = "usr/share/aclocal/*" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "pkgconf",
        repo = "pkgconf",
      },
    } | Attrs,
} | BuildSpec
