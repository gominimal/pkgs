let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let zlib = import "../zlib/build.ncl" in
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
    # the tarball's 2008 config.guess/config.sub predate aarch64; the modern GNU pair replaces them
    {
      url = "gs://minimal-staging-archives/build-aux/gnu-config-config.guess",
      sha256 = "e3d148130e9151735f8b9a8e69a70d06890ece51468a9762eb7ac0feddddcc2f",
      extract = false,
    } | Source,
    {
      url = "gs://minimal-staging-archives/build-aux/gnu-config-config.sub",
      sha256 = "11c54f55c3ac99e5d2c3dc2bb0bcccbf69f8223cc68f6b2438daa806cf0d16d8",
      extract = false,
    } | Source,
    base,
    make,
    toolchain,
    zlib,
  ],
  runtime_deps = [
    glibc,
    zlib,
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
