let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
# fastjar: a C implementation of the `jar` tool; GNU Classpath 0.99 and classpath-devel build with it.
let version = "0.98" in
{
  name = "fastjar",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/fastjar-0.98.tar.gz",
      sha256 = "f156abc5de8658f22ee8f08d7a72c88f9409ebd8c7933e9466b0842afeb2f145",
      extract = true,
      strip_prefix = "fastjar-0.98",
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
    fastjar = { glob = "usr/bin/fastjar" } | OutputBin,
    grepjar = { glob = "usr/bin/grepjar" } | OutputBin,
    mans = { glob = "usr/share/man/man1/*.1" } | OutputData,
    infos = { glob = "usr/share/info/*.info" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-2.0-or-later",
      repology_project = "fastjar",
      source_provenance = {
        category = 'Website,
        homepage = "https://savannah.nongnu.org/projects/fastjar",
        downloads_page = "https://download.savannah.nongnu.org/releases/fastjar/",
      },
    } | Attrs,
} | BuildSpec
