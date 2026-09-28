let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
# Info-ZIP zip 3.0: the `zip` archiver (jar files are zip archives; the JVM ladder packs its jars with it).
let version = "3.0" in
{
  name = "zip",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/zip30.tar.gz",
      sha256 = "f0e8bb1f9b7eb0b01285495a2699df3a4b766784c1765a8f1aeedf63c0806369",
      extract = true,
      strip_prefix = "zip30",
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
    zip = { glob = "usr/bin/zip" } | OutputBin,
    zipcloak = { glob = "usr/bin/zipcloak" } | OutputBin,
    zipnote = { glob = "usr/bin/zipnote" } | OutputBin,
    zipsplit = { glob = "usr/bin/zipsplit" } | OutputBin,
    mans = { glob = "usr/share/man/man1/*.1" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "Info-ZIP",
      repology_project = "zip",
      source_provenance = {
        category = 'Website,
        homepage = "https://infozip.sourceforge.net/",
        downloads_page = "https://sourceforge.net/projects/infozip/files/Zip%203.x%20%28latest%29/3.0/",
      },
    } | Attrs,
} | BuildSpec
