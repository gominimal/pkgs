let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let meson = import "../meson/build.ncl" in

let glibc = import "../glibc/build.ncl" in

let version = "3.18.1" in
{
  name = "libfuse",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/libfuse/libfuse/fuse-%{version}.tar.gz",
      sha256 = "dd395c88f29c7540bbdd0b830260ab8092ccb241bb6e66f603643f715fb9322c",
      extract = true,
      strip_prefix = "fuse-%{version}",
    } | Source,
    base,
    toolchain,
    make,
    ninja,
    meson,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  outputs = {
    fusermount3 = { glob = "usr/bin/fusermount3" } | OutputBin,
    sbins = { glob = "usr/sbin/**" } | OutputBin,

    libfuse = { glob = "usr/lib/libfuse3*.so*" } | OutputLib,

    includes = { glob = "usr/include/fuse3/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
    mans = { glob = "usr/share/man/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      repology_project = "libfuse",
      source_provenance = {
        category = 'GithubRepo,
        owner = "libfuse",
        repo = "libfuse",
      },
    } | Attrs,
} | BuildSpec
