let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in

let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "1.3.0" in
{
  name = "libmd",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://archive.hadrons.org/software/libmd/libmd-%{version}.tar.xz",
      sha256 = "fc0f1eb6b6766470326f2c014693809190e67dba84274a6fbae9d4912d066706",
      extract = true,
      strip_prefix = "libmd-%{version}",
    } | Source,
    base,
    make,
    toolchain,
  ],
  runtime_deps = [glibc],
  cmd = "./build.sh",
  outputs = {
    libs = { glob = "usr/lib/libmd.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,
    mans = { glob = "usr/share/man/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      repology_project = "libmd",
      license_spdx = "BSD-2-Clause AND BSD-3-Clause AND ISC AND Beerware AND LicenseRef-Public-Domain",
    } | Attrs,
} | BuildSpec
