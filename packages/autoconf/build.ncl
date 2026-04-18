let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let m4 = import "../m4/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let perl = import "../perl/build.ncl" in

let version = "2.73" in
{
  name = "autoconf",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/autoconf-%{version}.tar.xz",
      sha256 = "9fd672b1c8425fac2fa67fa0477b990987268b90ff36d5f016dae57be0d6b52e",
      extract = true,
      strip_prefix = "autoconf-%{version}",
    } | Source,
    base,
    m4,
    make,
    toolchain,
  ],
  runtime_deps = [
    perl,
  ],

  cmd = "./build.sh",
  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    autoconf_data = { glob = "usr/share/autoconf/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GnuProject,
        name = "autoconf",
      },
    } | Attrs,
} | BuildSpec
