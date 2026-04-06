let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let bash = import "../bash/build.ncl" in
let version = "1.6.3" in
{
  name = "dejagnu",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/dejagnu-%{version}.tar.gz",
      sha256 = "87daefacd7958b4a69f88c6856dbd1634261963c414079d0c371f589cd66a2e3"
    } | Source,
    base,
    make,
    toolchain,
  ],
  runtime_deps = [
    bash,
  ],

  cmd = "./build.sh",
  outputs = {
    dejagnu = { glob = "usr/bin/dejagnu" } | OutputBin,
    runtest = { glob = "usr/bin/runtest" } | OutputBin,

    includes = { glob = "usr/include/**" } | OutputData,
    usr_share_dejagnu = { glob = "usr/share/dejagnu/**/*" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GnuProject,
        name = "dejagnu",
      },
    } | Attrs,
} | BuildSpec
