let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let meson = import "../meson/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in

let freetype = import "../freetype/build.ncl" in
let glib = import "../glib/build.ncl" in
let glibc = import "../glibc/build.ncl" in

# 15.0.0 is the first release with the GHSA-r62p-jr5f-3mjm fix (subsetter
# out-of-bounds read via unsanitized substitute FeatureParams; affected
# >= 5.3.0, <= 14.6.0). Fix commits 4a60bf8333 + a1d34fedce (harfbuzz#6413)
# are ancestors of 15.0.0 and of no 14.x tag. build.sh fails the build if the
# fix regresses (ghsa-r62p-check.c, upstream's own regression vector).
let version = "15.0.0" in
{
  name = "harfbuzz",
  build_deps = [
    { file = "build.sh" } | Local,
    { file = "ghsa-r62p-check.c" } | Local,
    {
      url = "gs://minimal-staging-archives/harfbuzz-%{version}.tar.xz",
      sha256 = "968536e9abd782f07f7954044c0c4020199fcdd39b41d221ec42d2a3be4a44df",
      extract = true,
      strip_prefix = "harfbuzz-%{version}",
    } | Source,
    base,
    meson,
    ninja,
    pkgconf,
    toolchain,
  ],
  runtime_deps = [
    freetype,
    glib,
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/libharfbuzz*.so*" } | OutputLib,
    includes = { glob = "usr/include/harfbuzz/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT-Modern-Variant",
      source_provenance = {
        category = 'GithubRepo,
        owner = "harfbuzz",
        repo = "harfbuzz",
      },
    } | Attrs,
} | BuildSpec
