let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "79.1" in
{
  name = "icu",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/unicode-org/icu/releases/download/release-%{version}/icu4c-%{version}-sources.tgz",
      sha256 = "06fa63ecb521048f8082f12ad988f6b678d90cbd88aafce24cbc94902b191d99",
    } | Source,
    base,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc", "libstdcpp"],
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    # icu-config needs a shell
    bins = { glob = "usr/bin/*", allow_missing_interpreter = true } | OutputBin,
    sbins = { glob = "usr/sbin/*" } | OutputBin,
    libs = { glob = "usr/lib/*.{a,so*}" } | OutputLib,

    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,
    includes = { glob = "usr/include/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "Unicode-3.0",
      repology_project = "icu",
      source_provenance = {
        category = 'GithubRepo,
        owner = "unicode-org",
        repo = "icu",
      },
    } | Attrs,
} | BuildSpec
