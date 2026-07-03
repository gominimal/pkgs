let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let libidn2 = import "../libidn2/build.ncl" in
let libunistring = import "../libunistring/build.ncl" in
let meson = import "../meson/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let version = "0.22.0" in
{
  name = "libpsl",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/libpsl-%{version}.tar.gz",
      sha256 = "c45c3aa17576b99873e05a9b09a44041b065bbfa390e6d474d06fbfaeb9c7722"
    } | Source,
    base,
    meson,
    ninja,
    pkgconf,
    toolchain,
  ],
  runtime_deps = [
    libidn2,
    libunistring
  ],
  cmd = "./build.sh",
  outputs = {
    # Technically this depends on /usr/bin/env, but in practice any environment that
    # will use this (i.e. a build) will have coreutils already.
    psl-make-dafsa = { glob = "usr/bin/psl-make-dafsa", allow_missing_interpreter = true } | OutputBin,
    psl = { glob = "usr/bin/psl" } | OutputBin,
    libs = { glob = "usr/lib/*.so*" } | OutputLib,

    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,

    mans = { glob = "usr/share/man/**" } | OutputData,
    includes = { glob = "usr/include/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "rockdaboot",
        repo = "libpsl",
      },
    } | Attrs,
} | BuildSpec
