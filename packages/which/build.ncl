let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
# GNU which: locate a command on PATH; the OpenJDK build system calls it.
let version = "2.21" in
{
  name = "which",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/which-2.21.tar.gz",
      sha256 = "f4a245b94124b377d8b49646bf421f9155d36aa7614b6ebf83705d3ffc76eaad",
      extract = true,
      strip_prefix = "which-2.21",
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
    which = { glob = "usr/bin/which" } | OutputBin,
    mans = { glob = "usr/share/man/man1/*.1" } | OutputData,
    infos = { glob = "usr/share/info/*.info" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-3.0-or-later",
      repology_project = "which",
      source_provenance = {
        category = 'GnuProject,
        name = "which",
      },
    } | Attrs,
} | BuildSpec
