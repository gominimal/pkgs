let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
# giflib: the GIF codec library (libgif.so.7) and its header, as OpenJDK's --with-giflib=system wants them.
let version = "5.2.2" in
{
  name = "giflib",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/giflib-%{version}.tar.gz",
      sha256 = "be7ffbd057cadebe2aa144542fd90c6838c6a083b5e8a9048b8ee3b66b29d5fb",
      extract = true,
      strip_prefix = "giflib-%{version}",
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
    libs = { glob = "usr/lib/libgif.so*" } | OutputLib,
    includes = { glob = "usr/include/gif_lib.h" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      repology_project = "giflib",
      source_provenance = {
        category = 'Sourceforge,
        name = "giflib",
      },
    } | Attrs,
} | BuildSpec
